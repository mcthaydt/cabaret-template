@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_RoomFadeSystem

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_VCAM_SELECTORS := preload("res://scripts/state/selectors/u_vcam_selectors.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")
const RS_ROOM_FADE_SETTINGS_SCRIPT := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")
const U_ROOM_FADE_MATERIAL_APPLIER := preload("res://scripts/utils/lighting/u_room_fade_material_applier.gd")
const U_ENTITY_SELECTORS := preload("res://scripts/state/selectors/u_entity_selectors.gd")
const DEFAULT_ROOM_FADE_SETTINGS := preload("res://resources/display/vcam/cfg_default_room_fade.tres")

const ROOM_FADE_GROUP_TYPE := StringName("RoomFadeGroup")
const MIN_NORMAL_LENGTH_SQUARED := 0.000001
const THIN_AXIS_SIZE_EPSILON := 0.0001
const DEBUG_DOT_MARGIN := 0.12
const DEBUG_MAX_TARGET_LOGS_PER_COMPONENT := 8
const OCCLUSION_CORRIDOR_MARGIN := 2.0
const OCCLUSION_CORRIDOR_MIN_RADIUS := 0.8
const OCCLUSION_CORRIDOR_SEGMENT_EPSILON := 0.000001
const ROOF_NORMAL_DOT_MIN := 0.9
const ROOF_HEIGHT_MARGIN := 0.5

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_STATE_STORE = null
@export var debug_room_fade_logging: bool = false
@export var debug_room_fade_log_interval_frames: int = 60
@export var debug_room_fade_group_filter: StringName = StringName("")
@export var debug_room_fade_only_faded_targets: bool = true
@export var debug_room_fade_emit_ray_relation: bool = true
@export var debug_room_fade_log_target_reasons: bool = false
@export var debug_room_fade_log_target_inventory: bool = false

var material_applier: Variant = null
var duplicate_target_warning_handler: Callable = Callable()

var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_STATE_STORE = null
var _material_applier: Variant = null
var _tracked_targets: Dictionary = {}  # int -> Node3D (MeshInstance3D or CSGShape3D)
var _target_alpha_by_id: Dictionary = {}  # int -> float
var _cached_normals: Dictionary = {}  # int -> Vector3
var _cached_centroids: Dictionary = {}  # int (component instance id) -> Vector3
var _debug_tick_counter: int = 0
var _filtered_targets_cache: Dictionary = {}  # int (component id) -> Array
var _invalidate_tick_counter: int = 0
const INVALIDATE_INTERVAL := 30
const MOBILE_TICK_INTERVAL: int = 4

var _perf_is_supported_calls: int = 0
var _is_mobile: bool = false
var _mobile_tick_counter: int = 0

func _init() -> void:
	execution_priority = 110
	_is_mobile = OS.has_feature("mobile")

func on_configured() -> void:
	_camera_manager = _resolve_camera_manager()

func process_tick(delta: float) -> void:
	var should_log_debug: bool = _should_log_debug_tick()
	var components: Array = _get_room_fade_components()

	if components.is_empty():
		if should_log_debug:
			_debug_log_skip("no_components", {})
		_restore_stale_targets({})
		return

	var mode_info: Dictionary = _get_active_mode_info()
	if not bool(mode_info.get("is_orbit", false)):
		if should_log_debug:
			_debug_log_skip("non_orbit_mode", mode_info)
		_restore_components_to_opaque(components)
		return

	var main_camera: Camera3D = _resolve_active_camera()
	if main_camera == null or not is_instance_valid(main_camera):
		if should_log_debug:
			_debug_log_skip("no_active_camera", mode_info)
		_restore_stale_targets({})
		return

	var applier: Variant = _resolve_material_applier()
	if applier == null:
		if should_log_debug:
			_debug_log_skip("no_material_applier", mode_info)
		return

	if _is_mobile:
		_mobile_tick_counter += 1
		if (_mobile_tick_counter % MOBILE_TICK_INTERVAL) != 0:
			return

	var camera_forward: Vector3 = -main_camera.global_transform.basis.z
	var camera_position: Vector3 = main_camera.global_transform.origin
	var active_targets: Dictionary = {}
	var resolved_delta: float = maxf(delta, 0.0)
	_cached_centroids.clear()
	var player_data: Dictionary = _resolve_player_position_data()
	var has_player_position: bool = player_data.has("position")
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3

	var tick_data: Dictionary = _prepare_tick_data(components, player_data)
	components = tick_data.get("filtered_components", []) as Array
	var owned_targets_by_component: Dictionary = tick_data.get("owned_targets_by_component", {})

	_invalidate_tick_counter += 1
	if _invalidate_tick_counter % INVALIDATE_INTERVAL == 0:
		applier.invalidate_externally_removed()

	if should_log_debug:
		_debug_log_tick_header(mode_info, main_camera, camera_forward, components.size(), resolved_delta)

	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var should_log_component_debug: bool = _should_log_component_debug(should_log_debug, component)
		if should_log_component_debug:
			_debug_log_normal_diagnosis(component)
		var component_id: int = component.get_instance_id()

		var owned_targets_variant: Variant = owned_targets_by_component.get(component_id, [])
		var targets: Array = []
		if owned_targets_variant is Array:
			targets = owned_targets_variant as Array
		if targets.is_empty():
			continue
		if should_log_component_debug:
			_debug_log_component_target_inventory(component, targets)

		_cache_component_centroid(component, targets)
		applier.apply_fade_material(targets)

		var settings: Dictionary = _resolve_settings(component)
		var threshold: float = clampf(float(settings.get("fade_dot_threshold", 0.3)), 0.0, 1.0)
		var min_alpha: float = clampf(float(settings.get("min_alpha", 0.05)), 0.0, 1.0)
		var fade_speed: float = maxf(float(settings.get("fade_speed", 4.0)), 0.0)
		var component_alpha_sum: float = 0.0
		var component_alpha_count: int = 0
		var faded_target_count: int = 0

		if _is_mobile:
			# Mobile: two-pass dot-product evaluation so roof targets can inherit active room fade.
			var mobile_target_eval_infos: Array[Dictionary] = []
			var mobile_has_non_roof_fade: bool = false

			for target_variant in targets:
				if not (target_variant is Node3D) or not is_instance_valid(target_variant):
					continue
				var target: Node3D = target_variant as Node3D
				var target_id: int = target.get_instance_id()
				var target_normal: Vector3
				if _cached_normals.has(target_id):
					target_normal = _cached_normals[target_id] as Vector3
				else:
					var target_normal_data: Dictionary = _resolve_target_world_normal_info(component, target, targets.size())
					target_normal = target_normal_data.get("normal", Vector3.FORWARD) as Vector3
					_cached_normals[target_id] = target_normal

				var target_alpha: float = _resolve_target_alpha(camera_forward, target_normal, settings)
				var is_roof_candidate: bool = _is_roof_candidate_target(
					target,
					target_normal,
					has_player_position,
					player_position
				)
				if target_alpha < 1.0 and not is_roof_candidate:
					mobile_has_non_roof_fade = true

				mobile_target_eval_infos.append({
					"target": target,
					"target_id": target_id,
					"target_alpha": target_alpha,
					"is_roof_candidate": is_roof_candidate,
				})

			for target_info_variant in mobile_target_eval_infos:
				if not (target_info_variant is Dictionary):
					continue
				var target_info: Dictionary = target_info_variant as Dictionary
				var target: Node3D = target_info.get("target", null) as Node3D
				if target == null or not is_instance_valid(target):
					continue
				var target_id: int = int(target_info.get("target_id", -1))
				if target_id < 0:
					continue
				var target_alpha: float = float(target_info.get("target_alpha", 1.0))
				if mobile_has_non_roof_fade and bool(target_info.get("is_roof_candidate", false)):
					target_alpha = minf(target_alpha, min_alpha)

				var current_alpha: float = _resolve_current_target_alpha(target_id, component)
				var next_alpha: float = current_alpha
				if fade_speed > 0.0:
					next_alpha = move_toward(next_alpha, target_alpha, fade_speed * resolved_delta)
				next_alpha = clampf(next_alpha, min_alpha, 1.0)
				if target_alpha < 1.0:
					faded_target_count += 1

				_target_alpha_by_id[target_id] = next_alpha
				applier.update_single_fade_alpha(target, next_alpha)

				active_targets[target_id] = target
				component_alpha_sum += next_alpha
				component_alpha_count += 1
		else:
			# Desktop: two-pass evaluation with corridor + bucket continuity
			var debug_target_logs: Array[String] = []
			var debug_reason_logs: Array[String] = []
			var faded_normal_bucket_counts: Dictionary = {}
			var target_eval_infos: Array[Dictionary] = []
			var bucket_has_corridor_hit: Dictionary = {}
			var component_has_non_roof_fade: bool = false

			for target_variant in targets:
				if not (target_variant is Node3D) or not is_instance_valid(target_variant):
					continue
				var target: Node3D = target_variant as Node3D
				var target_id: int = target.get_instance_id()
				var target_normal: Vector3
				var target_normal_source: String
				if _cached_normals.has(target_id):
					target_normal = _cached_normals[target_id] as Vector3
					target_normal_source = "cached"
				else:
					var target_normal_data: Dictionary = _resolve_target_world_normal_info(component, target, targets.size())
					target_normal = target_normal_data.get("normal", Vector3.FORWARD) as Vector3
					target_normal_source = str(target_normal_data.get("source", "unknown"))
					_cached_normals[target_id] = target_normal

				var dot_value: float = camera_forward.dot(target_normal)
				var bucket_key: String = _resolve_normal_bucket_key(target_normal)
				var target_alpha_before_corridor: float = _resolve_target_alpha(camera_forward, target_normal, settings)
				var corridor_pass: bool = true
				if target_alpha_before_corridor < 1.0 and has_player_position:
					corridor_pass = _passes_camera_player_occlusion_corridor(target, camera_position, player_position)
					if corridor_pass:
						bucket_has_corridor_hit[bucket_key] = true
				var is_roof_candidate: bool = _is_roof_candidate_target(
					target,
					target_normal,
					has_player_position,
					player_position
				)

				target_eval_infos.append({
					"target": target,
					"target_id": target_id,
					"target_normal": target_normal,
					"target_normal_source": target_normal_source,
					"dot_value": dot_value,
					"bucket_key": bucket_key,
					"target_alpha_before_corridor": target_alpha_before_corridor,
					"corridor_pass": corridor_pass,
					"is_roof_candidate": is_roof_candidate,
				})

			for target_info_variant in target_eval_infos:
				if not (target_info_variant is Dictionary):
					continue
				var target_info: Dictionary = target_info_variant as Dictionary
				var is_roof_candidate: bool = bool(target_info.get("is_roof_candidate", false))
				if is_roof_candidate:
					continue
				var target_alpha_eval: float = _resolve_effective_target_alpha_for_corridor(
					float(target_info.get("target_alpha_before_corridor", 1.0)),
					bool(target_info.get("corridor_pass", true)),
					has_player_position,
					str(target_info.get("bucket_key", "")),
					bucket_has_corridor_hit
				)
				if target_alpha_eval < 1.0:
					component_has_non_roof_fade = true
					break

			for target_info_variant in target_eval_infos:
				if not (target_info_variant is Dictionary):
					continue
				var target_info: Dictionary = target_info_variant as Dictionary
				var target: Node3D = target_info.get("target", null) as Node3D
				if target == null or not is_instance_valid(target):
					continue
				var target_id: int = int(target_info.get("target_id", -1))
				if target_id < 0:
					continue
				var target_normal: Vector3 = target_info.get("target_normal", Vector3.FORWARD) as Vector3
				var target_normal_source: String = str(target_info.get("target_normal_source", "unknown"))
				var dot_value: float = float(target_info.get("dot_value", 0.0))
				var bucket_key: String = str(target_info.get("bucket_key", ""))
				var target_alpha_before_corridor: float = float(target_info.get("target_alpha_before_corridor", 1.0))
				var target_alpha: float = target_alpha_before_corridor
				var corridor_pass: bool = bool(target_info.get("corridor_pass", true))
				var bucket_continuity_hit: bool = bool(bucket_has_corridor_hit.get(bucket_key, false))
				target_alpha = _resolve_effective_target_alpha_for_corridor(
					target_alpha,
					corridor_pass,
					has_player_position,
					bucket_key,
					bucket_has_corridor_hit
				)
				var target_alpha_after_corridor: float = target_alpha
				var is_roof_candidate: bool = bool(target_info.get("is_roof_candidate", false))
				if component_has_non_roof_fade and bool(target_info.get("is_roof_candidate", false)):
					target_alpha = minf(target_alpha, min_alpha)
				if should_log_component_debug and debug_room_fade_log_target_reasons:
					debug_reason_logs.append(_format_target_reason_line(
						target,
						dot_value,
						threshold,
						target_alpha_before_corridor,
						target_alpha_after_corridor,
						target_alpha,
						corridor_pass,
						bucket_continuity_hit,
						is_roof_candidate,
						component_has_non_roof_fade,
						has_player_position
					))

				var current_alpha: float = _resolve_current_target_alpha(target_id, component)
				var next_alpha: float = current_alpha
				if fade_speed > 0.0:
					next_alpha = move_toward(next_alpha, target_alpha, fade_speed * resolved_delta)
				next_alpha = clampf(next_alpha, min_alpha, 1.0)
				if target_alpha < 1.0:
					faded_target_count += 1
					faded_normal_bucket_counts[bucket_key] = int(faded_normal_bucket_counts.get(bucket_key, 0)) + 1

				_target_alpha_by_id[target_id] = next_alpha
				applier.update_single_fade_alpha(target, next_alpha)

				active_targets[target_id] = target
				component_alpha_sum += next_alpha
				component_alpha_count += 1
				if should_log_component_debug and _should_log_target_decision(dot_value, threshold, target_alpha):
					if debug_target_logs.size() < DEBUG_MAX_TARGET_LOGS_PER_COMPONENT:
						debug_target_logs.append(_format_target_debug_line(
							target,
							target_normal_source,
							target_normal,
							dot_value,
							threshold,
							target_alpha,
							current_alpha,
							next_alpha
						))
						var target_diag_lines: Array[String] = _build_target_diagnostic_lines(
							target,
							target_normal,
							target_normal_source,
							dot_value,
							threshold,
							target_alpha,
							camera_position,
							player_position,
							has_player_position
						)
						for diag_line in target_diag_lines:
							debug_target_logs.append(diag_line)

			if component_alpha_count > 0 and should_log_component_debug:
				var desktop_average_alpha: float = component_alpha_sum / float(component_alpha_count)
				var merged_target_logs: Array[String] = []
				merged_target_logs.append_array(debug_reason_logs)
				merged_target_logs.append_array(debug_target_logs)
				_debug_log_component_summary(
					component,
					targets,
					faded_target_count,
					desktop_average_alpha,
					threshold,
					min_alpha,
					fade_speed,
					merged_target_logs
				)
				_debug_log_faded_normal_bucket_summary(component, faded_normal_bucket_counts)

		if component_alpha_count > 0:
			var component_average_alpha: float = component_alpha_sum / float(component_alpha_count)
			component.set("current_alpha", component_average_alpha)

	_restore_stale_targets(active_targets)

func _exit_tree() -> void:
	_restore_stale_targets({})
	_target_alpha_by_id.clear()
	_cached_normals.clear()
	_cached_centroids.clear()
	_filtered_targets_cache.clear()

func _resolve_camera_manager() -> I_CAMERA_MANAGER:
	if camera_manager != null:
		return camera_manager
	if _camera_manager != null and is_instance_valid(_camera_manager):
		return _camera_manager

	var service: Variant = U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager"))
	if service is I_CAMERA_MANAGER:
		_camera_manager = service as I_CAMERA_MANAGER
		return _camera_manager
	return null

func _resolve_state_store() -> I_STATE_STORE:
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store
	if state_store != null and is_instance_valid(state_store):
		_state_store = state_store
		return _state_store
	_state_store = U_STATE_UTILS.try_get_store(self)
	return _state_store

func _resolve_active_camera() -> Camera3D:
	var manager: I_CAMERA_MANAGER = _resolve_camera_manager()
	if manager != null:
		var manager_camera: Camera3D = manager.get_main_camera()
		if manager_camera != null and is_instance_valid(manager_camera):
			return manager_camera

	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var viewport_camera: Camera3D = viewport.get_camera_3d()
	if viewport_camera == null or not is_instance_valid(viewport_camera):
		return null
	return viewport_camera

func _resolve_material_applier() -> Variant:
	if material_applier != null:
		return material_applier
	if _material_applier != null:
		return _material_applier
	_material_applier = U_ROOM_FADE_MATERIAL_APPLIER.new()
	return _material_applier

func _get_room_fade_components() -> Array:
	var components: Array = get_components(ROOM_FADE_GROUP_TYPE)
	return components

func _resolve_settings(component: Object) -> Dictionary:
	var settings_resource: Variant = DEFAULT_ROOM_FADE_SETTINGS
	var component_settings: Variant = component.get("settings")
	if component_settings != null and component_settings is Resource:
		var resource: Resource = component_settings as Resource
		if resource.get_script() == RS_ROOM_FADE_SETTINGS_SCRIPT:
			settings_resource = resource

	if settings_resource != null and settings_resource.has_method("get_resolved_values"):
		var resolved_variant: Variant = settings_resource.call("get_resolved_values")
		if resolved_variant is Dictionary:
			return resolved_variant as Dictionary

	return {
		"fade_dot_threshold": 0.3,
		"fade_speed": 4.0,
		"min_alpha": 0.05,
	}

func _collect_mesh_targets(component: Object) -> Array:
	if component == null:
		return []
	if not component.has_method("collect_mesh_targets"):
		return []

	var component_id: int = component.get_instance_id()
	var is_cache_valid: bool = component.has_method("is_target_cache_valid") and bool(component.call("is_target_cache_valid"))
	if is_cache_valid and _filtered_targets_cache.has(component_id):
		return _filtered_targets_cache[component_id] as Array

	var targets_variant: Variant = component.call("collect_mesh_targets")
	if not (targets_variant is Array):
		return []

	var targets: Array = []
	for target_variant in targets_variant as Array:
		_perf_is_supported_calls += 1
		if _is_supported_target(target_variant):
			targets.append(target_variant)
	_filtered_targets_cache[component_id] = targets
	return targets

func _prepare_tick_data(components: Array, player_data: Dictionary) -> Dictionary:
	# Single pass: collect targets once per component, filter by active room, and assign ownership.
	var has_player: bool = player_data.has("position")
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3
	var do_room_filter: bool = has_player and components.size() > 1

	# Phase 1: collect targets + compute AABBs for room filtering.
	var targets_by_component_id: Dictionary = {}  # int -> Array
	var matching_components: Array = []
	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var targets: Array = _collect_mesh_targets(component)
		if targets.is_empty():
			continue
		var component_id: int = component.get_instance_id()
		targets_by_component_id[component_id] = targets

		if do_room_filter:
			var room_aabb: AABB = _resolve_aabb_from_validated_targets(targets)
			var expanded: AABB = room_aabb.grow(2.0)
			expanded.position.y = room_aabb.position.y - 0.5
			expanded.size.y = room_aabb.size.y + 1.0
			if expanded.has_point(player_position):
				matching_components.append(component_variant)
		else:
			matching_components.append(component_variant)

	if do_room_filter and matching_components.is_empty():
		matching_components = components

	# Phase 2: assign ownership using pre-collected targets.
	var owned_targets_by_component: Dictionary = {}  # int -> Array[Node3D]
	var owner_component_by_target_id: Dictionary = {}  # int -> Object
	var warning_pairs: Dictionary = {}

	for component_variant in matching_components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var component_id: int = component.get_instance_id()
		var targets_variant: Variant = targets_by_component_id.get(component_id, null)
		if targets_variant == null or not (targets_variant is Array):
			continue
		var targets: Array = targets_variant as Array

		var owned_targets: Array = []
		var seen_targets_for_component: Dictionary = {}
		for target_variant in targets:
			if not (target_variant is Node3D):
				continue
			var target: Node3D = target_variant as Node3D
			if not is_instance_valid(target):
				continue
			var target_id: int = target.get_instance_id()
			if seen_targets_for_component.has(target_id):
				continue
			seen_targets_for_component[target_id] = true

			if not owner_component_by_target_id.has(target_id):
				owner_component_by_target_id[target_id] = component
				owned_targets.append(target)
				continue

			var owner_variant: Variant = owner_component_by_target_id.get(target_id, null)
			var owner_component := owner_variant as Object
			if owner_component == null or not is_instance_valid(owner_component):
				owner_component_by_target_id[target_id] = component
				owned_targets.append(target)
				continue
			if owner_component == component:
				continue

			_warn_duplicate_target_ownership_once_per_tick(
				component, owner_component, target, warning_pairs
			)

		if not owned_targets.is_empty():
			owned_targets_by_component[component_id] = owned_targets

	return {
		"filtered_components": matching_components,
		"owned_targets_by_component": owned_targets_by_component,
	}

func _warn_duplicate_target_ownership_once_per_tick(
	component: Object,
	owner_component: Object,
	target: Node3D,
	warning_pairs: Dictionary
) -> void:
	if component == null or owner_component == null or target == null:
		return
	var pair_key: String = "%d:%d" % [target.get_instance_id(), component.get_instance_id()]
	if warning_pairs.has(pair_key):
		return
	warning_pairs[pair_key] = true

	var message := (
		"S_RoomFadeSystem: duplicate room-fade target ownership skipped for target=%s owner=%s skipped=%s"
		% [
			_describe_node(target),
			_describe_object(owner_component),
			_describe_object(component),
		]
	)
	_emit_duplicate_target_warning(message)

func _emit_duplicate_target_warning(message: String) -> void:
	if duplicate_target_warning_handler.is_valid():
		duplicate_target_warning_handler.call(message)
		return
	push_warning(message)

func _resolve_world_normal(component: Object) -> Vector3:
	if component == null:
		return Vector3.FORWARD
	if component.has_method("get_fade_normal_world"):
		var normal_variant: Variant = component.call("get_fade_normal_world")
		if normal_variant is Vector3:
			return normal_variant as Vector3
	return Vector3.FORWARD

func _resolve_target_alpha(camera_forward: Vector3, wall_normal: Vector3, settings: Dictionary) -> float:
	# abs(dot) so walls fade when camera faces them from either side (inside or outside the room).
	var dot_value: float = camera_forward.dot(wall_normal)
	var threshold: float = clampf(float(settings.get("fade_dot_threshold", 0.3)), 0.0, 1.0)
	var min_alpha: float = clampf(float(settings.get("min_alpha", 0.05)), 0.0, 1.0)
	if absf(dot_value) > threshold:
		return min_alpha
	return 1.0

func _resolve_effective_target_alpha_for_corridor(
	target_alpha_before_corridor: float,
	corridor_pass: bool,
	has_player_position: bool,
	bucket_key: String,
	bucket_has_corridor_hit: Dictionary
) -> float:
	var resolved_alpha: float = target_alpha_before_corridor
	if resolved_alpha < 1.0 and has_player_position and not corridor_pass:
		var bucket_continuity_hit: bool = bool(bucket_has_corridor_hit.get(bucket_key, false))
		if not bucket_continuity_hit:
			resolved_alpha = 1.0
	return resolved_alpha

func _is_roof_candidate_target(
	target: Node3D,
	target_normal: Vector3,
	has_player_position: bool,
	player_position: Vector3
) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if absf(target_normal.y) < ROOF_NORMAL_DOT_MIN:
		return false
	if not has_player_position:
		return false
	return target.global_position.y > (player_position.y + ROOF_HEIGHT_MARGIN)

func _passes_camera_player_occlusion_corridor(
	target: Node3D,
	camera_position: Vector3,
	player_position: Vector3
) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var camera_planar := Vector2(camera_position.x, camera_position.z)
	var player_planar := Vector2(player_position.x, player_position.z)
	var segment: Vector2 = player_planar - camera_planar
	var segment_length_sq: float = segment.length_squared()
	if segment_length_sq <= OCCLUSION_CORRIDOR_SEGMENT_EPSILON:
		return true

	# Use the nearest point on the target's XZ footprint to the corridor line,
	# not the target center. This prevents wide walls from failing the corridor
	# check when the camera-player line is near one end of the wall.
	var target_planar: Vector2 = _resolve_target_nearest_corridor_point(
		target, camera_planar, segment, segment_length_sq
	)

	var to_target: Vector2 = target_planar - camera_planar
	var segment_t: float = to_target.dot(segment) / segment_length_sq
	if segment_t < 0.0 or segment_t > 1.0:
		return false

	var closest_point: Vector2 = camera_planar + segment * segment_t
	var distance_to_segment: float = target_planar.distance_to(closest_point)
	return distance_to_segment <= maxf(OCCLUSION_CORRIDOR_MARGIN, OCCLUSION_CORRIDOR_MIN_RADIUS)

func _resolve_target_nearest_corridor_point(
	target: Node3D,
	seg_a: Vector2,
	segment: Vector2,
	segment_length_sq: float
) -> Vector2:
	var center := Vector2(target.global_position.x, target.global_position.z)
	var half_extents: Vector2 = _resolve_target_planar_half_extents(target)
	if half_extents == Vector2.ZERO:
		return center

	# Find the point on the corridor line closest to the target center.
	var to_center: Vector2 = center - seg_a
	var t: float = clampf(to_center.dot(segment) / segment_length_sq, 0.0, 1.0)
	var line_point: Vector2 = seg_a + segment * t

	# Clamp that line point to the target's world-space XZ footprint (AABB).
	var min_bound: Vector2 = center - half_extents
	var max_bound: Vector2 = center + half_extents
	return Vector2(
		clampf(line_point.x, min_bound.x, max_bound.x),
		clampf(line_point.y, min_bound.y, max_bound.y)
	)

func _resolve_target_planar_half_extents(target: Node3D) -> Vector2:
	if target is CSGBox3D:
		var csg: CSGBox3D = target as CSGBox3D
		var half: Vector3 = csg.size.abs() * 0.5
		var bx: Basis = csg.global_basis
		var world_half_x: float = half.x * absf(bx.x.x) + half.z * absf(bx.z.x)
		var world_half_z: float = half.x * absf(bx.x.z) + half.z * absf(bx.z.z)
		return Vector2(world_half_x, world_half_z)
	elif target is MeshInstance3D:
		var mesh: MeshInstance3D = target as MeshInstance3D
		if mesh.mesh != null:
			var half: Vector3 = mesh.mesh.get_aabb().size.abs() * 0.5
			var bx: Basis = mesh.global_basis
			var world_half_x: float = half.x * absf(bx.x.x) + half.z * absf(bx.z.x)
			var world_half_z: float = half.x * absf(bx.x.z) + half.z * absf(bx.z.z)
			return Vector2(world_half_x, world_half_z)
	return Vector2.ZERO

func _resolve_target_occlusion_corridor_radius(target: Node3D) -> float:
	var planar_extent: float = 0.0
	if target is CSGBox3D:
		var csg_target: CSGBox3D = target as CSGBox3D
		planar_extent = _resolve_planar_extent_from_half_size(csg_target.global_basis, csg_target.size.abs() * 0.5)
	elif target is MeshInstance3D:
		var mesh_target: MeshInstance3D = target as MeshInstance3D
		if mesh_target.mesh != null:
			var half_size: Vector3 = mesh_target.mesh.get_aabb().size.abs() * 0.5
			planar_extent = _resolve_planar_extent_from_half_size(mesh_target.global_basis, half_size)

	var resolved_radius: float = planar_extent + OCCLUSION_CORRIDOR_MARGIN
	return maxf(resolved_radius, OCCLUSION_CORRIDOR_MIN_RADIUS)

func _resolve_planar_extent_from_half_size(basis: Basis, half_size: Vector3) -> float:
	var x_axis_planar_len: float = Vector2(basis.x.x, basis.x.z).length()
	var z_axis_planar_len: float = Vector2(basis.z.x, basis.z.z).length()
	return (half_size.x * x_axis_planar_len) + (half_size.z * z_axis_planar_len)

func _resolve_target_world_normal(component: Object, target: Node3D, target_count: int) -> Vector3:
	var normal_data: Dictionary = _resolve_target_world_normal_info(component, target, target_count)
	return normal_data.get("normal", Vector3.FORWARD) as Vector3

func _resolve_target_world_normal_info(component: Object, target: Node3D, target_count: int) -> Dictionary:
	var component_normal: Vector3 = _resolve_world_normal(component)
	if target == null or not is_instance_valid(target):
		return {
			"normal": component_normal,
			"source": "component_invalid_target",
		}
	if target_count <= 1:
		return {
			"normal": component_normal,
			"source": "component_single_target",
		}

	var component_origin: Vector3 = _resolve_component_origin(component, target)
	var inward_raw: Vector3 = component_origin - target.global_position

	var csg_axis_normal_data: Dictionary = _resolve_csg_box_thin_axis_normal_info(component, target)
	if not csg_axis_normal_data.is_empty():
		return csg_axis_normal_data

	var inward_planar: Vector3 = inward_raw
	inward_planar.y = 0.0
	if inward_planar.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return {
			"normal": component_normal,
			"source": "component_degenerate_planar",
		}
	return {
		"normal": inward_planar.normalized(),
		"source": "inward_planar_origin",
	}

func _resolve_csg_box_thin_axis_normal_info(component: Object, target: Node3D) -> Dictionary:
	if not (target is CSGBox3D):
		return {}
	var csg_box: CSGBox3D = target as CSGBox3D
	if csg_box == null or not is_instance_valid(csg_box):
		return {}

	var axis_candidates: Array = _resolve_csg_box_thin_axis_world_candidates(csg_box)
	if axis_candidates.is_empty():
		return {}

	var component_origin: Vector3 = _resolve_component_origin(component, target)
	var inward_direction_3d: Vector3 = component_origin - target.global_position
	var inward_direction_planar: Vector3 = inward_direction_3d
	inward_direction_planar.y = 0.0
	var inward_direction: Vector3 = inward_direction_planar
	if inward_direction.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		inward_direction = inward_direction_3d
	if inward_direction.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return {}
	inward_direction = inward_direction.normalized()

	var first_axis_variant: Variant = axis_candidates[0]
	if not (first_axis_variant is Vector3):
		return {}
	var best_axis: Vector3 = first_axis_variant as Vector3
	var best_axis_alignment: float = absf(best_axis.dot(inward_direction))

	for axis_variant in axis_candidates:
		if not (axis_variant is Vector3):
			continue
		var axis: Vector3 = axis_variant as Vector3
		var alignment: float = absf(axis.dot(inward_direction))
		if alignment > best_axis_alignment:
			best_axis = axis
			best_axis_alignment = alignment

	if best_axis.dot(inward_direction) < 0.0:
		best_axis = -best_axis
	if best_axis.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return {}
	return {
		"normal": best_axis.normalized(),
		"source": "csg_thin_axis_inward",
	}

func _resolve_csg_box_thin_axis_world_candidates(csg_box: CSGBox3D) -> Array:
	if csg_box == null or not is_instance_valid(csg_box):
		return []
	var size: Vector3 = csg_box.size.abs()
	var smallest_axis_size: float = minf(size.x, minf(size.y, size.z))
	var axes: Array = []
	if absf(size.x - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		axes.append(csg_box.global_basis.x.normalized())
	if absf(size.y - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		axes.append(csg_box.global_basis.y.normalized())
	if absf(size.z - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		axes.append(csg_box.global_basis.z.normalized())
	return axes

func _cache_component_centroid(component: Object, targets: Array) -> void:
	var component_id: int = component.get_instance_id()
	if _cached_centroids.has(component_id):
		return
	var sum := Vector3.ZERO
	var count: int = 0
	for target_variant in targets:
		if _is_supported_target(target_variant):
			sum += (target_variant as Node3D).global_position
			count += 1
	if count > 0:
		_cached_centroids[component_id] = sum / float(count)

func _resolve_component_origin(component: Object, fallback_target: Node3D) -> Vector3:
	if component != null:
		var component_id: int = component.get_instance_id()
		if _cached_centroids.has(component_id):
			return _cached_centroids[component_id] as Vector3

	if component is Node:
		var component_node := component as Node
		if component_node != null:
			var parent_node := component_node.get_parent() as Node3D
			if parent_node != null and is_instance_valid(parent_node):
				return parent_node.global_position
			var component_node_3d := component_node as Node3D
			if component_node_3d != null and is_instance_valid(component_node_3d):
				return component_node_3d.global_position

	if fallback_target != null and is_instance_valid(fallback_target):
		return fallback_target.global_position
	return Vector3.ZERO

func _resolve_current_target_alpha(target_id: int, component: Object) -> float:
	if _target_alpha_by_id.has(target_id):
		return float(_target_alpha_by_id.get(target_id, 1.0))
	if component != null:
		return float(component.get("current_alpha"))
	return 1.0

func _get_active_mode_info() -> Dictionary:
	var store: I_STATE_STORE = _resolve_state_store()
	if store == null:
		return {
			"has_store": false,
			"active_mode": "",
			"is_orbit": false,
		}

	var state: Dictionary = store.get_state()
	var active_mode: String = U_VCAM_SELECTORS.get_active_mode(state).to_lower()
	return {
		"has_store": true,
		"active_mode": active_mode,
		"is_orbit": active_mode == "orbit",
	}

func _restore_components_to_opaque(components: Array) -> void:
	var restore_targets: Array = []
	var seen_targets: Dictionary = {}

	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		component.set("current_alpha", 1.0)
		var targets: Array = _collect_mesh_targets(component)
		for target_variant in targets:
			if not (target_variant is Node3D) or not is_instance_valid(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()
			if seen_targets.has(target_id):
				continue
			seen_targets[target_id] = true
			_target_alpha_by_id.erase(target_id)
			restore_targets.append(target)

	for target_variant in _tracked_targets.values():
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var tracked_target: Node3D = target_variant as Node3D
		var tracked_id: int = tracked_target.get_instance_id()
		if seen_targets.has(tracked_id):
			continue
		seen_targets[tracked_id] = true
		_target_alpha_by_id.erase(tracked_id)
		restore_targets.append(tracked_target)



	var applier: Variant = _resolve_material_applier()
	if applier != null and not restore_targets.is_empty():
		applier.restore_original_materials(restore_targets)
	_tracked_targets.clear()
	_target_alpha_by_id.clear()
	_cached_normals.clear()

func _restore_stale_targets(active_targets: Dictionary) -> void:
	var applier: Variant = _resolve_material_applier()
	if applier == null:
		_tracked_targets = active_targets.duplicate()
		return

	var stale_targets: Array = []
	for target_id_variant in _tracked_targets.keys():
		var target_id: int = int(target_id_variant)
		if active_targets.has(target_id):
			continue
		var target_variant: Variant = _tracked_targets.get(target_id, null)
		if target_variant is Node3D and is_instance_valid(target_variant):
			stale_targets.append(target_variant)
		_target_alpha_by_id.erase(target_id)
		_cached_normals.erase(target_id)

	if not stale_targets.is_empty():
		applier.restore_original_materials(stale_targets)

	_tracked_targets = active_targets.duplicate()

func _is_supported_target(target_variant: Variant) -> bool:
	if target_variant is MeshInstance3D:
		var mesh_target: MeshInstance3D = target_variant as MeshInstance3D
		return mesh_target != null and is_instance_valid(mesh_target)
	if target_variant is CSGShape3D:
		var csg_target: CSGShape3D = target_variant as CSGShape3D
		return csg_target != null and is_instance_valid(csg_target)
	return false

func _should_log_debug_tick() -> bool:
	if not debug_room_fade_logging:
		return false
	_debug_tick_counter += 1
	var interval: int = maxi(debug_room_fade_log_interval_frames, 1)
	return _debug_tick_counter % interval == 0

func _should_log_target_decision(dot_value: float, threshold: float, target_alpha: float) -> bool:
	if debug_room_fade_only_faded_targets:
		return target_alpha < 1.0
	if target_alpha < 1.0:
		return true
	return absf(dot_value - threshold) <= DEBUG_DOT_MARGIN

func _should_log_component_debug(should_log_debug: bool, component: Object) -> bool:
	if not should_log_debug:
		return false
	if component == null or not is_instance_valid(component):
		return false
	if debug_room_fade_group_filter == StringName(""):
		return true
	return _resolve_component_group_tag(component) == debug_room_fade_group_filter

func _resolve_component_group_tag(component: Object) -> StringName:
	if component == null:
		return StringName("")
	var tag_variant: Variant = component.get("group_tag")
	if tag_variant is StringName:
		return tag_variant as StringName
	return StringName("")

func _debug_log_skip(reason: String, mode_info: Dictionary) -> void:
	print(
		"[RoomFadeDebug] tick=%d skip=%s active_mode=%s tracked_targets=%d" % [
			_debug_tick_counter,
			reason,
			str(mode_info.get("active_mode", "")),
			_tracked_targets.size(),
		]
	)

func _debug_log_tick_header(
	mode_info: Dictionary,
	main_camera: Camera3D,
	camera_forward: Vector3,
	component_count: int,
	delta: float
) -> void:
	print(
		"[RoomFadeDebug] tick=%d mode=%s components=%d tracked_targets=%d delta=%.3f camera=%s forward=%s" % [
			_debug_tick_counter,
			str(mode_info.get("active_mode", "")),
			component_count,
			_tracked_targets.size(),
			delta,
			_describe_node(main_camera),
			_format_vector3(camera_forward),
		]
	)

func _debug_log_component_summary(
	component: Object,
	targets: Array,
	faded_target_count: int,
	component_average_alpha: float,
	threshold: float,
	min_alpha: float,
	fade_speed: float,
	target_logs: Array[String]
) -> void:
	var fallback_target: Node3D = null
	if not targets.is_empty():
		var first_target_variant: Variant = targets[0]
		if _is_supported_target(first_target_variant):
			fallback_target = first_target_variant as Node3D
	var component_origin: Vector3 = _resolve_component_origin(component, fallback_target)

	print(
		"[RoomFadeDebug] component=%s targets=%d faded_targets=%d avg_alpha=%.3f threshold=%.3f min_alpha=%.3f fade_speed=%.3f origin=%s" % [
			_describe_object(component),
			targets.size(),
			faded_target_count,
			component_average_alpha,
			threshold,
			min_alpha,
			fade_speed,
			_format_vector3(component_origin),
		]
	)
	for log_line in target_logs:
		print(log_line)

func _debug_log_faded_normal_bucket_summary(component: Object, bucket_counts: Dictionary) -> void:
	if bucket_counts.is_empty():
		return
	var buckets: Array[String] = []
	var axis_seen: Dictionary = {}
	for key_variant in bucket_counts.keys():
		var bucket_key: String = str(key_variant)
		var count: int = int(bucket_counts.get(bucket_key, 0))
		buckets.append("%s:%d" % [bucket_key, count])
		axis_seen[_normal_bucket_axis(bucket_key)] = true
	var has_perpendicular: bool = axis_seen.size() > 1
	if not has_perpendicular:
		return
	buckets.sort()
	print(
		"[RoomFadeDiag] component=%s faded_normal_buckets=%s perpendicular_axes=%s" % [
			_describe_object(component),
			",".join(buckets),
			str(has_perpendicular),
		]
	)

func _debug_log_component_target_inventory(component: Object, targets: Array) -> void:
	if not debug_room_fade_log_target_inventory:
		return
	var target_summaries: Array[String] = []
	for target_variant in targets:
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var target: Node3D = target_variant as Node3D
		var target_size_label: String = "size=<n/a>"
		if target is CSGBox3D:
			target_size_label = "size=%s" % _format_vector3((target as CSGBox3D).size.abs())
		elif target is MeshInstance3D:
			var mesh_instance: MeshInstance3D = target as MeshInstance3D
			if mesh_instance.mesh != null:
				target_size_label = "size=%s" % _format_vector3(mesh_instance.mesh.get_aabb().size.abs())
		target_summaries.append("%s %s" % [_describe_node(target), target_size_label])
	target_summaries.sort()
	print(
		"[RoomFadeDiag] component=%s target_inventory_count=%d targets=%s" % [
			_describe_object(component),
			target_summaries.size(),
			" | ".join(target_summaries),
		]
	)

func _format_target_debug_line(
	target: Node3D,
	target_normal_source: String,
	target_normal: Vector3,
	dot_value: float,
	threshold: float,
	target_alpha: float,
	current_alpha: float,
	next_alpha: float
) -> String:
	return "[RoomFadeDebug]   target=%s source=%s pos=%s normal=%s dot=%.3f threshold=%.3f target_alpha=%.3f current_alpha=%.3f next_alpha=%.3f" % [
		_describe_node(target),
		target_normal_source,
		_format_vector3(target.global_position),
		_format_vector3(target_normal),
		dot_value,
		threshold,
		target_alpha,
		current_alpha,
		next_alpha,
	]

func _format_target_reason_line(
	target: Node3D,
	dot_value: float,
	threshold: float,
	target_alpha_before_corridor: float,
	target_alpha_after_corridor: float,
	target_alpha_final: float,
	corridor_pass: bool,
	bucket_continuity_hit: bool,
	is_roof_candidate: bool,
	component_has_non_roof_fade: bool,
	has_player_position: bool
) -> String:
	var reason: String = "faded"
	if target_alpha_final >= 1.0:
		reason = "opaque_other"
		if absf(dot_value) <= threshold:
			reason = "dot_below_threshold"
		elif target_alpha_before_corridor < 1.0 and has_player_position and not corridor_pass and not bucket_continuity_hit:
			reason = "corridor_filtered"
		elif is_roof_candidate and not component_has_non_roof_fade:
			reason = "roof_waiting_for_wall_fade"
	elif target_alpha_before_corridor < 1.0 and has_player_position and not corridor_pass and bucket_continuity_hit:
		reason = "bucket_continuity_override"
	elif is_roof_candidate and component_has_non_roof_fade and target_alpha_after_corridor > target_alpha_final:
		reason = "roof_inherited_room_fade"
	return "[RoomFadeReason] target=%s reason=%s dot=%.3f threshold=%.3f alpha_pre_corridor=%.3f alpha_post_corridor=%.3f alpha_final=%.3f corridor_pass=%s bucket_continuity=%s roof_candidate=%s" % [
		_describe_node(target),
		reason,
		dot_value,
		threshold,
		target_alpha_before_corridor,
		target_alpha_after_corridor,
		target_alpha_final,
		str(corridor_pass),
		str(bucket_continuity_hit),
		str(is_roof_candidate),
	]

func _build_target_diagnostic_lines(
	target: Node3D,
	target_normal: Vector3,
	target_normal_source: String,
	dot_value: float,
	threshold: float,
	target_alpha: float,
	camera_position: Vector3,
	player_position: Vector3,
	has_player_position: bool
) -> Array[String]:
	var lines: Array[String] = []
	if target == null or not is_instance_valid(target):
		return lines
	if target_alpha >= 1.0:
		return lines
	var target_pos: Vector3 = target.global_position

	var dist_camera_to_target: float = camera_position.distance_to(target_pos)
	var dist_camera_to_player: float = -1.0
	var along_player_ray: float = -1.0
	var is_between_camera_and_player: bool = false
	var distance_to_camera_player_ray: float = -1.0
	if has_player_position:
		dist_camera_to_player = camera_position.distance_to(player_position)
		if dist_camera_to_player > 0.0001:
			var ray_dir: Vector3 = (player_position - camera_position) / dist_camera_to_player
			var to_target: Vector3 = target_pos - camera_position
			along_player_ray = to_target.dot(ray_dir)
			is_between_camera_and_player = along_player_ray >= 0.0 and along_player_ray <= dist_camera_to_player
			var closest_point: Vector3 = camera_position + ray_dir * along_player_ray
			distance_to_camera_player_ray = target_pos.distance_to(closest_point)

	lines.append(
		"[RoomFadeDiag] target=%s dot=%.3f threshold=%.3f target_alpha=%.3f source=%s normal=%s camera_pos=%s player_pos=%s target_pos=%s" % [
			_describe_node(target),
			dot_value,
			threshold,
			target_alpha,
			target_normal_source,
			_format_vector3(target_normal),
			_format_vector3(camera_position),
			_format_vector3(player_position) if has_player_position else "<unavailable>",
			_format_vector3(target_pos),
		]
	)
	if debug_room_fade_emit_ray_relation:
		lines.append(
			"[RoomFadeDiag]   relation dist_camera_to_target=%.3f dist_camera_to_player=%.3f along_player_ray=%.3f is_between_camera_and_player=%s distance_to_camera_player_ray=%.3f" % [
				dist_camera_to_target,
				dist_camera_to_player,
				along_player_ray,
				str(is_between_camera_and_player),
				distance_to_camera_player_ray,
			]
		)

	if target is CSGBox3D:
		var csg_target: CSGBox3D = target as CSGBox3D
		var thin_axis_label: String = _resolve_csg_thin_axis_label(csg_target, target_normal)
		lines.append(
			"[RoomFadeDiag]   thin_geometry type=CSGBox3D size=%s thin_axis=%s source=%s" % [
				_format_vector3(csg_target.size.abs()),
				thin_axis_label,
				target_normal_source,
			]
		)
	return lines

func _resolve_normal_bucket_key(normal: Vector3) -> String:
	var ax: float = absf(normal.x)
	var ay: float = absf(normal.y)
	var az: float = absf(normal.z)
	if ax >= ay and ax >= az:
		return "+X" if normal.x >= 0.0 else "-X"
	if ay >= ax and ay >= az:
		return "+Y" if normal.y >= 0.0 else "-Y"
	return "+Z" if normal.z >= 0.0 else "-Z"

func _normal_bucket_axis(bucket_key: String) -> String:
	if bucket_key.ends_with("X"):
		return "X"
	if bucket_key.ends_with("Y"):
		return "Y"
	return "Z"

func _resolve_csg_thin_axis_label(csg_box: CSGBox3D, target_normal: Vector3) -> String:
	if csg_box == null or not is_instance_valid(csg_box):
		return "none"
	var size: Vector3 = csg_box.size.abs()
	var smallest_axis_size: float = minf(size.x, minf(size.y, size.z))
	var candidates: Array[String] = []
	if absf(size.x - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		candidates.append("X")
	if absf(size.y - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		candidates.append("Y")
	if absf(size.z - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		candidates.append("Z")
	if candidates.is_empty():
		return "none"
	if candidates.size() == 1:
		return candidates[0]

	var best_axis: String = candidates[0]
	var best_alignment: float = -1.0
	for candidate in candidates:
		var axis_vec: Vector3 = Vector3.ZERO
		if candidate == "X":
			axis_vec = csg_box.global_basis.x.normalized()
		elif candidate == "Y":
			axis_vec = csg_box.global_basis.y.normalized()
		else:
			axis_vec = csg_box.global_basis.z.normalized()
		var alignment: float = absf(axis_vec.dot(target_normal))
		if alignment > best_alignment:
			best_alignment = alignment
			best_axis = candidate
	return "%s(multi)" % best_axis

func _describe_object(obj: Variant) -> String:
	if obj is Node:
		return _describe_node(obj as Node)
	return str(obj)

func _describe_node(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "<invalid>"
	return str(node.get_path())

func _format_vector3(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]

func _filter_components_by_active_room(components: Array) -> Array:
	if components.size() <= 1:
		return components

	var player_data: Dictionary = _resolve_player_position_data()
	if player_data.is_empty():
		return components
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3

	var matching: Array = []
	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var targets: Array = _collect_mesh_targets(component)
		if targets.is_empty():
			continue
		var room_aabb: AABB = _resolve_room_aabb_from_targets(targets)
		var expanded: AABB = room_aabb.grow(2.0)
		expanded.position.y = room_aabb.position.y - 0.5
		expanded.size.y = room_aabb.size.y + 1.0
		if expanded.has_point(player_position):
			matching.append(component_variant)

	if matching.is_empty():
		return components
	return matching

func _resolve_room_aabb_from_targets(targets: Array) -> AABB:
	return _resolve_aabb_from_validated_targets(targets)

func _resolve_aabb_from_validated_targets(targets: Array) -> AABB:
	# Targets are pre-filtered by _collect_mesh_targets — skip redundant type checks.
	var first_valid: Node3D = null
	for target_variant in targets:
		if target_variant is Node3D and is_instance_valid(target_variant):
			first_valid = target_variant as Node3D
			break
	if first_valid == null:
		return AABB()

	var result: AABB = AABB(first_valid.global_position, Vector3.ZERO)
	for target_variant in targets:
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var target: Node3D = target_variant as Node3D
		result = result.expand(target.global_position)
	return result

func _resolve_player_position_data() -> Dictionary:
	var store: I_STATE_STORE = _resolve_state_store()
	if store == null:
		return {}
	var state: Dictionary = store.get_state()
	var player_id: String = U_ENTITY_SELECTORS.get_player_entity_id(state)
	if player_id.is_empty():
		return {}
	var entity: Dictionary = U_ENTITY_SELECTORS.get_entity(state, player_id)
	if entity.is_empty():
		return {}
	var position_variant: Variant = entity.get("position", null)
	if position_variant is Vector3:
		return {"position": position_variant as Vector3}
	return {}

func _debug_log_normal_diagnosis(component: Object) -> void:
	# Hypothesis A: fade_normal export doesn't account for room rotation
	var raw_fade_normal: Vector3 = Vector3.FORWARD
	if component.has_method("get") and true:
		raw_fade_normal = component.get("fade_normal") as Vector3
	var world_normal_from_component: Vector3 = Vector3.FORWARD
	if component.has_method("get_fade_normal_world"):
		world_normal_from_component = component.call("get_fade_normal_world") as Vector3

	var parent_basis_euler: Vector3 = Vector3.ZERO
	var parent_global_pos: Vector3 = Vector3.ZERO
	if component is Node:
		var parent_node := (component as Node).get_parent() as Node3D
		if parent_node != null and is_instance_valid(parent_node):
			parent_basis_euler = parent_node.global_basis.get_euler()
			parent_global_pos = parent_node.global_position

	print("[RoomFadeDiag] component=%s" % _describe_object(component))
	print("[RoomFadeDiag]   raw_fade_normal=%s  world_normal=%s" % [
		_format_vector3(raw_fade_normal),
		_format_vector3(world_normal_from_component),
	])
	print("[RoomFadeDiag]   parent_rotation_deg=%s  parent_pos=%s" % [
		_format_vector3(Vector3(
			rad_to_deg(parent_basis_euler.x),
			rad_to_deg(parent_basis_euler.y),
			rad_to_deg(parent_basis_euler.z),
		)),
		_format_vector3(parent_global_pos),
	])

	# Hypothesis B: multi-target inward-planar origin is wrong
	var targets: Array = _collect_mesh_targets(component)
	if targets.size() > 1:
		var fallback_target: Node3D = null
		if _is_supported_target(targets[0]):
			fallback_target = targets[0] as Node3D
		var comp_origin: Vector3 = _resolve_component_origin(component, fallback_target)
		print("[RoomFadeDiag]   target_count=%d  component_origin=%s" % [
			targets.size(),
			_format_vector3(comp_origin),
		])
		var sample_count: int = mini(targets.size(), 4)
		for i in range(sample_count):
			if not _is_supported_target(targets[i]):
				continue
			var t: Node3D = targets[i] as Node3D
			var inward_raw: Vector3 = comp_origin - t.global_position
			var inward_planar: Vector3 = inward_raw
			inward_planar.y = 0.0
			var resolved_info: Dictionary = _resolve_target_world_normal_info(component, t, targets.size())
			print("[RoomFadeDiag]   target[%d]=%s  pos=%s  inward_raw=%s  inward_planar=%s  resolved_normal=%s  source=%s" % [
				i,
				_describe_node(t),
				_format_vector3(t.global_position),
				_format_vector3(inward_raw),
				_format_vector3(inward_planar),
				_format_vector3(resolved_info.get("normal", Vector3.ZERO) as Vector3),
				str(resolved_info.get("source", "unknown")),
			])
