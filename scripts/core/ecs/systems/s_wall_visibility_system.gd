@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_WallVisibilitySystem

const U_VCAM_SELECTORS := preload("res://scripts/core/state/selectors/u_vcam_selectors.gd")
const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")
const I_StateStore := preload("res://scripts/core/interfaces/i_state_store.gd")
const RS_ROOM_FADE_SETTINGS_SCRIPT := preload("res://scripts/core/resources/display/vcam/rs_room_fade_settings.gd")
const U_WALL_VISIBILITY_MATERIAL_APPLIER := preload("res://scripts/core/utils/lighting/u_wall_visibility_material_applier.gd")
const U_ENTITY_SELECTORS := preload("res://scripts/core/state/selectors/u_entity_selectors.gd")
const U_PERF_PROBE := preload("res://scripts/core/utils/debug/u_perf_probe.gd")
const U_PERF_FADE_BYPASS := preload("res://scripts/core/utils/debug/u_perf_fade_bypass.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/core/utils/display/u_mobile_platform_detector.gd")
const RS_WALL_VISIBILITY_CONFIG_SCRIPT := preload("res://scripts/core/resources/ecs/rs_wall_visibility_config.gd")
const DEFAULT_WALL_VISIBILITY_CONFIG := preload("res://resources/core/base_settings/gameplay/cfg_wall_visibility_config_default.tres")

const ROOM_FADE_GROUP_TYPE := StringName("RoomFadeGroup")
const MIN_NORMAL_LENGTH_SQUARED := 0.000001
const THIN_AXIS_SIZE_EPSILON := 0.0001
const OCCLUSION_CORRIDOR_MIN_RADIUS := 0.8
const OCCLUSION_CORRIDOR_SEGMENT_EPSILON := 0.000001
const MOBILE_HIDE_FADE_THRESHOLD := 0.01

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_StateStore = null
@export var wall_visibility_config: Resource = null
@export var mobile_tick_interval: int = 4
@export var desktop_tick_interval: int = 1
@export var min_fade: float = 0.0
@export var mobile_hide_walls_instead_of_fade: bool = false

var material_applier: Variant = null
var duplicate_target_warning_handler: Callable = Callable()

var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_StateStore = null
var _material_applier: Variant = null
var _tracked_targets: Dictionary = {}
var _target_fade_by_id: Dictionary = {}
var _invalidate_tick_counter: int = 0
var _is_mobile: bool = false
var _tick_counter: int = 0
var _perf_probe: U_PerfProbe = null
var _shader_probe: U_PerfProbe = null
var _cached_normals: Dictionary = {}
var _cached_half_extents: Dictionary = {}
var _cached_aabbs: Dictionary = {}
var _cached_transform_hashes: Dictionary = {}
var _filtered_targets_by_component: Dictionary = {}
var _filtered_targets_valid: Dictionary = {}
var _seen_this_frame: Dictionary = {}
var _original_visibility_by_id: Dictionary = {}

# Pooled parallel arrays for Pass 1 (avoids per-target Dictionary allocation)
var _pooled_targets: Array = []
var _pooled_target_ids: Array[int] = []
var _pooled_normals: Array = []
var _pooled_fades_before_corridor: Array[float] = []
var _pooled_corridor_passes: Array[bool] = []
var _pooled_is_roof: Array[bool] = []

# Target type handler registry: maps target classes to AABB/half-extent resolvers.
# Order matters: most specific types first (CSGBox3D before CSGShape3D).
# Uses is_class() for matching — returns true for the class itself and all subclasses.
var _target_type_handlers: Array[Dictionary] = []


func _init() -> void:
	execution_priority = 110
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	if DisplayServer.get_name() == "headless":
		_is_mobile = false
	U_PERF_FADE_BYPASS.reset()
	if _is_mobile:
		desktop_tick_interval = 1
	_perf_probe = U_PerfProbe.create("WallVis", _is_mobile)
	_shader_probe = U_PerfProbe.create("WallVisShader", _is_mobile)
	_init_target_type_handlers()


func on_configured() -> void:
	_camera_manager = _resolve_camera_manager()


func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.CAMERA


func process_tick(delta: float) -> void:
	var components: Array = get_components(ROOM_FADE_GROUP_TYPE)
	if components.is_empty():
		_cleanup_stale_targets({})
		return

	if _is_mobile and U_PERF_FADE_BYPASS.is_enabled():
		_restore_components_to_opaque(components)
		return

	# Tick throttling: skip frames on both mobile and desktop
	_tick_counter += 1
	var wall_config: Dictionary = _resolve_wall_visibility_config_values()
	var tick_interval: int = _resolve_tick_interval(wall_config)
	if tick_interval > 1 and (_tick_counter % tick_interval) != 0:
		return

	_perf_probe.start()
	var tick_data := _resolve_tick_data(delta, tick_interval, wall_config)
	if not bool(tick_data.get("is_orbit", false)):
		_restore_components_to_opaque(components)
		return
	if not bool(tick_data.get("camera_valid", false)):
		_cleanup_stale_targets({})
		return
	if tick_data.get("applier") == null:
		return

	_invalidate_applier_if_needed(tick_data)
	var prepared := _prepare_tick_data(components, tick_data.get("player_data", {}), wall_config)
	_seen_this_frame.clear()

	for component_variant in prepared.get("filtered_components", []):
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var component_id: int = component.get_instance_id()
		var targets_variant: Variant = prepared.get("owned_targets_by_component", {}).get(component_id, [])
		var targets: Array = targets_variant as Array if targets_variant is Array else []
		if targets.is_empty():
			continue
		_process_component_fade(component, targets, tick_data)

	_cleanup_stale_targets(_seen_this_frame)
	_perf_probe.stop()


func _resolve_tick_interval(wall_config: Dictionary) -> int:
	var resolved_mobile_tick_interval: int = maxi(
		1,
		mobile_tick_interval if mobile_tick_interval > 0 else int(
			wall_config.get("mobile_tick_interval", 4)
		)
	)
	return resolved_mobile_tick_interval if _is_mobile else desktop_tick_interval


func _invalidate_applier_if_needed(tick_data: Dictionary) -> void:
	_invalidate_tick_counter += 1
	var wall_config: Dictionary = tick_data.get("wall_config", {}) as Dictionary
	var invalidate_interval: int = max(1, int(wall_config.get("invalidate_interval", 30)))
	if _invalidate_tick_counter % invalidate_interval == 0:
		(tick_data.get("applier") as RefCounted).invalidate_externally_removed()


# --- Tick context resolution ---

func _resolve_tick_data(
	delta: float,
	tick_interval: int,
	wall_config: Dictionary = {}
) -> Dictionary:
	var state: Dictionary = get_frame_state_snapshot()
	var mode_info: Dictionary = _get_active_mode_info_from_state(state)
	var main_camera: Camera3D = _resolve_active_camera()
	var applier: Variant = _resolve_material_applier()
	var player_data: Dictionary = _resolve_player_position_data_from_state(state)
	var has_player: bool = player_data.has("position")
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3
	var camera_forward: Vector3 = Vector3.FORWARD
	var camera_position: Vector3 = Vector3.ZERO
	if main_camera != null and is_instance_valid(main_camera):
		camera_forward = -main_camera.global_transform.basis.z
		camera_position = main_camera.global_transform.origin
	var resolved_delta: float = maxf(delta, 0.0) * float(tick_interval)
	return {
		"state": state,
		"mode_info": mode_info,
		"is_orbit": bool(mode_info.get("is_orbit", false)),
		"main_camera": main_camera,
		"camera_valid": main_camera != null and is_instance_valid(main_camera),
		"applier": applier,
		"camera_forward": camera_forward,
		"camera_position": camera_position,
		"resolved_delta": resolved_delta,
		"player_data": player_data,
		"has_player": has_player,
		"player_position": player_position,
		"use_mobile_hide": _is_mobile_hide_mode(),
		"wall_config": wall_config,
	}


# --- Per-component fade processing ---

func _process_component_fade(component: Object, targets: Array, tick_data: Dictionary) -> void:
	var applier: Variant = tick_data.get("applier")
	var use_mobile_hide: bool = bool(tick_data.get("use_mobile_hide", false))
	var camera_forward: Vector3 = tick_data.get("camera_forward", Vector3.FORWARD) as Vector3
	var camera_position: Vector3 = tick_data.get("camera_position", Vector3.ZERO) as Vector3
	var resolved_delta: float = float(tick_data.get("resolved_delta", 0.0))
	var has_player: bool = bool(tick_data.get("has_player", false))
	var player_position: Vector3 = tick_data.get("player_position", Vector3.ZERO) as Vector3
	var wall_config: Dictionary = tick_data.get("wall_config", {}) as Dictionary

	_apply_wall_materials(applier, targets, use_mobile_hide)

	var clip_height_offset: float = float(wall_config.get("clip_height_offset", 1.5))
	if component.has_method("get"):
		var offset_variant: Variant = component.get("clip_height_offset")
		if offset_variant is float or offset_variant is int:
			clip_height_offset = float(offset_variant)

	var clip_y: float = 100.0
	if has_player:
		clip_y = player_position.y + clip_height_offset

	var settings: Dictionary = _resolve_settings(component)
	var threshold: float = clampf(
		float(settings.get("fade_dot_threshold", wall_config.get("fade_dot_threshold", 0.3))),
		0.0,
		1.0
	)
	var fade_speed: float = maxf(
		float(settings.get("fade_speed", wall_config.get("fade_speed", 4.0))),
		0.0
	)
	var min_alpha: float = clampf(
		float(settings.get("min_alpha", wall_config.get("min_alpha", 0.05))),
		0.0,
		1.0
	)
	var max_fade: float = clampf(1.0 - maxf(min_fade, min_alpha), 0.0, 1.0)
	var _current_alpha: Variant = component.get("current_alpha") if component.get("current_alpha") != null else 1.0
	var initial_component_fade: float = clampf(1.0 - float(_current_alpha), 0.0, max_fade)
	var component_fade_sum: float = 0.0
	var component_fade_count: int = 0

	# Pass 1: compute raw fade values using pooled parallel arrays
	_pooled_targets.clear()
	_pooled_target_ids.clear()
	_pooled_normals.clear()
	_pooled_fades_before_corridor.clear()
	_pooled_corridor_passes.clear()
	_pooled_is_roof.clear()

	var bucket_has_corridor_hit: Dictionary = {}
	var component_has_non_roof_fade: bool = false

	for target_variant in targets:
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var target: Node3D = target_variant as Node3D
		var target_id: int = target.get_instance_id()

		var target_normal: Vector3
		var current_transform_hash: int = _compute_transform_hash(target)
		if _cached_normals.has(target_id) and _cached_transform_hashes.get(target_id, -1) == current_transform_hash:
			target_normal = _cached_normals[target_id] as Vector3
		else:
			target_normal = _resolve_target_world_normal(component, target, targets.size())
			_cached_normals[target_id] = target_normal
			_cached_transform_hashes[target_id] = current_transform_hash

		var target_fade_before_corridor: float = _resolve_directional_fade(
			camera_forward, target_normal, threshold
		)
		var corridor_pass: bool = true
		if has_player:
			corridor_pass = _passes_camera_player_occlusion_corridor(
				target, camera_position, player_position, wall_config
			)
			if corridor_pass:
				var bucket_key: String = _resolve_normal_bucket_key(target_normal)
				bucket_has_corridor_hit[bucket_key] = true

		var is_roof: bool = _is_roof_candidate_target(
			target, target_normal, has_player, player_position, wall_config
		)

		_pooled_targets.append(target)
		_pooled_target_ids.append(target_id)
		_pooled_normals.append(target_normal)
		_pooled_fades_before_corridor.append(target_fade_before_corridor)
		_pooled_corridor_passes.append(corridor_pass)
		_pooled_is_roof.append(is_roof)

		if target_fade_before_corridor > 0.0 and not is_roof:
			component_has_non_roof_fade = true

	# Pass 2: resolve effective fade per target (corridor + bucket + roof).
	var pool_size: int = _pooled_targets.size()
	for i in range(pool_size):
		var target: Node3D = _pooled_targets[i] as Node3D
		if target == null or not is_instance_valid(target):
			continue
		var target_id: int = _pooled_target_ids[i]

		var target_fade: float = _pooled_fades_before_corridor[i]
		var corridor_pass: bool = _pooled_corridor_passes[i]
		var is_roof: bool = _pooled_is_roof[i]
		var target_normal: Vector3 = _pooled_normals[i] as Vector3
		var bucket_key: String = _resolve_normal_bucket_key(target_normal)

		target_fade = _resolve_effective_target_fade_for_corridor(
			target_fade, corridor_pass, has_player, bucket_key, bucket_has_corridor_hit
		)

		if is_roof and component_has_non_roof_fade:
			target_fade = maxf(target_fade, min_fade)

		target_fade = minf(target_fade, max_fade)

		var current_fade: float = initial_component_fade
		if _target_fade_by_id.has(target_id):
			current_fade = float(_target_fade_by_id.get(target_id, initial_component_fade))
		var next_fade: float = current_fade
		if fade_speed > 0.0:
			next_fade = move_toward(next_fade, target_fade, fade_speed * resolved_delta)
		next_fade = clampf(next_fade, 0.0, max_fade)

		_target_fade_by_id[target_id] = next_fade
		if use_mobile_hide:
			_apply_mobile_visibility_state(target, target_id, next_fade)
		else:
			applier.update_uniforms(target, clip_y, next_fade)
			_shader_probe.stop()
		_seen_this_frame[target_id] = target

		component_fade_sum += next_fade
		component_fade_count += 1

	if component_fade_count > 0:
		var avg_fade: float = component_fade_sum / float(component_fade_count)
		component.set("current_alpha", 1.0 - avg_fade)


# --- Wall material application ---

func _apply_wall_materials(applier: Variant, targets: Array, use_mobile_hide: bool) -> void:
	if targets.is_empty():
		return
	if use_mobile_hide:
		if applier != null and applier.has_method("restore_original_materials"):
			applier.restore_original_materials(targets)
	else:
		_shader_probe.start()
		if applier != null:
			applier.apply_visibility_material(targets)


# --- Roof detection ---

func _exit_tree() -> void:
	_cleanup_stale_targets({})
	_target_fade_by_id.clear()
	_cached_normals.clear()
	_cached_half_extents.clear()
	_cached_aabbs.clear()
	_cached_transform_hashes.clear()
	_filtered_targets_by_component.clear()
	_filtered_targets_valid.clear()
	_seen_this_frame.clear()
	_original_visibility_by_id.clear()
	_pooled_targets.clear()
	_pooled_target_ids.clear()
	_pooled_normals.clear()
	_pooled_fades_before_corridor.clear()
	_pooled_corridor_passes.clear()
	_pooled_is_roof.clear()


# --- Room filtering and target ownership ---

func _prepare_tick_data(
	components: Array,
	player_data: Dictionary,
	wall_config: Dictionary = {}
) -> Dictionary:
	var has_player: bool = player_data.has("position")
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3

	# Collect targets for each component
	var targets_by_component_id: Dictionary = {}
	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var targets: Array = _collect_mesh_targets(component)
		if targets.is_empty():
			continue
		targets_by_component_id[component.get_instance_id()] = targets

	# Filter rooms by AABB
	var matching_components: Array = _filter_rooms_by_aabb(
		components, targets_by_component_id, player_position, has_player, wall_config
	)

	# Deduplicate target ownership
	var owned_targets_by_component: Dictionary = _deduplicate_targets(
		matching_components, targets_by_component_id
	)

	return {
		"filtered_components": matching_components,
		"owned_targets_by_component": owned_targets_by_component,
	}


func _filter_rooms_by_aabb(
	components: Array,
	targets_by_component_id: Dictionary,
	player_position: Vector3,
	has_player: bool,
	wall_config: Dictionary = {}
) -> Array:
	if not has_player or components.size() <= 1:
		return components
	var matching: Array = []
	for component_variant in components:
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
		var room_aabb: AABB = _resolve_aabb_from_validated_targets(targets)
		var room_margin: float = maxf(float(wall_config.get("room_aabb_margin", 2.0)), 0.0)
		var roof_margin: float = maxf(float(wall_config.get("roof_height_margin", 0.5)), 0.0)
		var expanded: AABB = room_aabb.grow(room_margin)
		expanded.position.y = room_aabb.position.y - roof_margin
		expanded.size.y = room_aabb.size.y + (roof_margin * 2.0)
		if expanded.has_point(player_position):
			matching.append(component_variant)
	if matching.is_empty():
		return components
	return matching


func _deduplicate_targets(
	matching_components: Array,
	targets_by_component_id: Dictionary
) -> Dictionary:
	var owned_targets_by_component: Dictionary = {}
	var owner_component_by_target_id: Dictionary = {}
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

	return owned_targets_by_component


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
		"S_WallVisibilitySystem: duplicate target ownership skipped for target=%s owner=%s skipped=%s"
		% [_describe_node(target), _describe_object(owner_component), _describe_object(component)]
	)
	_emit_duplicate_target_warning(message)


func _emit_duplicate_target_warning(message: String) -> void:
	if duplicate_target_warning_handler.is_valid():
		duplicate_target_warning_handler.call(message)
		return
	push_warning(message)


func _resolve_aabb_from_validated_targets(targets: Array) -> AABB:
	var aabb: AABB = AABB()
	var initialized: bool = false
	for target_variant in targets:
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var target: Node3D = target_variant as Node3D
		var target_aabb: AABB = _resolve_target_aabb(target)
		if target_aabb.size == Vector3.ZERO:
			continue
		if not initialized:
			aabb = target_aabb
			initialized = true
		else:
			aabb = aabb.merge(target_aabb)
	if not initialized:
		aabb = AABB(Vector3.ZERO, Vector3.ONE)
	return aabb


func _resolve_target_aabb(target: Node3D) -> AABB:
	var target_id: int = target.get_instance_id()
	var transform_hash: int = _compute_transform_hash(target)
	if _cached_aabbs.has(target_id) and _cached_transform_hashes.get(target_id, -1) == transform_hash:
		return _cached_aabbs[target_id] as AABB
	var result: AABB = _resolve_target_aabb_uncached(target)
	_cached_aabbs[target_id] = result
	return result


# --- Target type registry ---

func _init_target_type_handlers() -> void:
	# Most specific types first: CSGBox3D before CSGShape3D
	_register_target_type_handler(&"CSGBox3D", _resolve_csg_box_aabb, _resolve_csg_box_planar_half_extents)
	_register_target_type_handler(&"MeshInstance3D", _resolve_mesh_aabb, _resolve_mesh_planar_half_extents)
	_register_target_type_handler(&"CSGShape3D", _resolve_csg_shape_aabb, func(_t: Node3D) -> Variant: return Vector2.ZERO)


func _register_target_type_handler(
	type_name: StringName,
	aabb_resolver: Callable,
	half_extents_resolver: Callable
) -> void:
	_target_type_handlers.append({
		"type_name": type_name,
		"aabb": aabb_resolver,
		"half_extents": half_extents_resolver,
	})


func _resolve_target_aabb_uncached(target: Node3D) -> AABB:
	var target_class: String = target.get_class()
	# First pass: exact class match (most specific)
	for handler in _target_type_handlers:
		if String(handler["type_name"]) == target_class:
			var result: Variant = (handler["aabb"] as Callable).call(target)
			if result is AABB:
				return result as AABB
	# Second pass: inheritance fallback (e.g., CSGShape3D matches any CSG* subtype)
	for handler in _target_type_handlers:
		if String(handler["type_name"]) != target_class and target.is_class(String(handler["type_name"])):
			var result: Variant = (handler["aabb"] as Callable).call(target)
			if result is AABB:
				return result as AABB
	return AABB(target.global_position - Vector3.ONE * 0.5, Vector3.ONE)


func _resolve_csg_box_aabb(target: Node3D) -> Variant:
	var csg: CSGBox3D = target as CSGBox3D
	if csg == null:
		return null
	var half: Vector3 = csg.size.abs() * 0.5
	return AABB(csg.global_position - half, csg.size.abs())


func _resolve_mesh_aabb(target: Node3D) -> Variant:
	var mesh_instance: MeshInstance3D = target as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var mesh_aabb: AABB = mesh_instance.mesh.get_aabb()
		return mesh_instance.global_transform * mesh_aabb
	return null


func _resolve_csg_shape_aabb(target: Node3D) -> Variant:
	return AABB(target.global_position - Vector3.ONE * 0.5, Vector3.ONE)


func _resolve_target_planar_half_extents_uncached(target: Node3D) -> Vector2:
	var target_class: String = target.get_class()
	# First pass: exact class match
	for handler in _target_type_handlers:
		if String(handler["type_name"]) == target_class:
			var result: Variant = (handler["half_extents"] as Callable).call(target)
			if result is Vector2:
				return result as Vector2
	# Second pass: inheritance fallback
	for handler in _target_type_handlers:
		if String(handler["type_name"]) != target_class and target.is_class(String(handler["type_name"])):
			var result: Variant = (handler["half_extents"] as Callable).call(target)
			if result is Vector2:
				return result as Vector2
	return Vector2.ZERO


func _resolve_csg_box_planar_half_extents(target: Node3D) -> Variant:
	var csg: CSGBox3D = target as CSGBox3D
	if csg == null:
		return null
	var half: Vector3 = csg.size.abs() * 0.5
	var bx: Basis = csg.global_basis
	var world_half_x: float = half.x * absf(bx.x.x) + half.z * absf(bx.z.x)
	var world_half_z: float = half.x * absf(bx.x.z) + half.z * absf(bx.z.z)
	return Vector2(world_half_x, world_half_z)


func _resolve_mesh_planar_half_extents(target: Node3D) -> Variant:
	var mesh: MeshInstance3D = target as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		var half: Vector3 = mesh.mesh.get_aabb().size.abs() * 0.5
		var bx: Basis = mesh.global_basis
		var world_half_x: float = half.x * absf(bx.x.x) + half.z * absf(bx.z.x)
		var world_half_z: float = half.x * absf(bx.x.z) + half.z * absf(bx.z.z)
		return Vector2(world_half_x, world_half_z)
	return null


# --- Directional fade ---

func _resolve_directional_fade(
	camera_forward: Vector3,
	wall_normal: Vector3,
	threshold: float
) -> float:
	var dot_value: float = camera_forward.dot(wall_normal)
	if dot_value > threshold:
		return 1.0
	return 0.0


# --- Corridor ---

func _passes_camera_player_occlusion_corridor(
	target: Node3D,
	camera_position: Vector3,
	player_position: Vector3,
	wall_config: Dictionary = {}
) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var camera_planar := Vector2(camera_position.x, camera_position.z)
	var player_planar := Vector2(player_position.x, player_position.z)
	var segment: Vector2 = player_planar - camera_planar
	var segment_length_sq: float = segment.length_squared()
	if segment_length_sq <= OCCLUSION_CORRIDOR_SEGMENT_EPSILON:
		return true

	var target_planar: Vector2 = _resolve_target_nearest_corridor_point(
		target, camera_planar, segment, segment_length_sq
	)

	var to_target: Vector2 = target_planar - camera_planar
	var segment_t: float = to_target.dot(segment) / segment_length_sq
	if segment_t < 0.0 or segment_t > 1.0:
		return false

	var closest_point: Vector2 = camera_planar + segment * segment_t
	var distance_to_segment: float = target_planar.distance_to(closest_point)
	var corridor_margin: float = maxf(
		float(wall_config.get("corridor_occlusion_margin", 2.0)),
		OCCLUSION_CORRIDOR_MIN_RADIUS
	)
	return distance_to_segment <= corridor_margin


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

	var to_center: Vector2 = center - seg_a
	var t: float = clampf(to_center.dot(segment) / segment_length_sq, 0.0, 1.0)
	var line_point: Vector2 = seg_a + segment * t

	var min_bound: Vector2 = center - half_extents
	var max_bound: Vector2 = center + half_extents
	return Vector2(
		clampf(line_point.x, min_bound.x, max_bound.x),
		clampf(line_point.y, min_bound.y, max_bound.y)
	)


func _resolve_target_planar_half_extents(target: Node3D) -> Vector2:
	var target_id: int = target.get_instance_id()
	var transform_hash: int = _compute_transform_hash(target)
	if _cached_half_extents.has(target_id) and _cached_transform_hashes.get(target_id, -1) == transform_hash:
		return _cached_half_extents[target_id] as Vector2
	var result: Vector2 = _resolve_target_planar_half_extents_uncached(target)
	_cached_half_extents[target_id] = result
	return result


# --- Bucket continuity ---

func _resolve_effective_target_fade_for_corridor(
	target_fade_before_corridor: float,
	corridor_pass: bool,
	has_player_position: bool,
	bucket_key: String,
	bucket_has_corridor_hit: Dictionary
) -> float:
	var resolved_fade: float = target_fade_before_corridor
	if has_player_position:
		if corridor_pass:
			# Corridor grants fading: wall is between camera and player regardless of facing.
			resolved_fade = maxf(resolved_fade, 1.0)
		elif resolved_fade > 0.0:
			# Corridor revokes fading unless bucket continuity preserves it.
			var bucket_continuity_hit: bool = bool(bucket_has_corridor_hit.get(bucket_key, false))
			if not bucket_continuity_hit:
				resolved_fade = 0.0
	return resolved_fade


func _resolve_normal_bucket_key(normal: Vector3) -> String:
	var abs_normal := Vector3(absf(normal.x), absf(normal.y), absf(normal.z))
	if abs_normal.x >= abs_normal.y and abs_normal.x >= abs_normal.z:
		return "+x" if normal.x > 0.0 else "-x"
	if abs_normal.y >= abs_normal.x and abs_normal.y >= abs_normal.z:
		return "+y" if normal.y > 0.0 else "-y"
	return "+z" if normal.z > 0.0 else "-z"


# --- Roof handling ---

func _is_roof_candidate_target(
	target: Node3D,
	target_normal: Vector3,
	has_player_position: bool,
	player_position: Vector3,
	wall_config: Dictionary = {}
) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var roof_normal_dot_min: float = clampf(
		float(wall_config.get("roof_normal_dot_min", 0.9)),
		0.0,
		1.0
	)
	if absf(target_normal.y) < roof_normal_dot_min:
		return false
	if not has_player_position:
		return false
	var roof_height_margin: float = maxf(float(wall_config.get("roof_height_margin", 0.5)), 0.0)
	return target.global_position.y > (player_position.y + roof_height_margin)


# --- Normal resolution ---

func _resolve_target_world_normal(component: Object, target: Node3D, target_count: int) -> Vector3:
	var component_normal: Vector3 = _resolve_world_normal(component)
	if target == null or not is_instance_valid(target):
		return component_normal
	if target_count <= 1:
		return component_normal

	var csg_axis_normal: Vector3 = _resolve_csg_box_thin_axis_normal(component, target)
	if csg_axis_normal != Vector3.ZERO:
		return csg_axis_normal

	var component_origin: Vector3 = _resolve_component_origin(component, target)
	var inward_raw: Vector3 = component_origin - target.global_position
	var inward_planar: Vector3 = inward_raw
	inward_planar.y = 0.0
	if inward_planar.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return component_normal
	return inward_planar.normalized()


## Intentional exception: uses `is CSGBox3D` directly rather than the target-type registry.
## Adding a per-type normal resolver to the registry for a single type would be over-engineering.
## If a second CSG subtype needs a specialized normal resolver, promote to registry at that point.

func _resolve_csg_box_thin_axis_normal(component: Object, target: Node3D) -> Vector3:
	if not (target is CSGBox3D):
		return Vector3.ZERO
	var csg_box: CSGBox3D = target as CSGBox3D
	if csg_box == null or not is_instance_valid(csg_box):
		return Vector3.ZERO

	var axis_candidates: Array = _resolve_csg_box_thin_axis_world_candidates(csg_box)
	if axis_candidates.is_empty():
		return Vector3.ZERO

	var component_origin: Vector3 = _resolve_component_origin(component, target)
	var inward_direction_3d: Vector3 = component_origin - target.global_position
	var inward_direction_planar: Vector3 = inward_direction_3d
	inward_direction_planar.y = 0.0
	var inward_direction: Vector3 = inward_direction_planar
	if inward_direction.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		inward_direction = inward_direction_3d
	if inward_direction.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return Vector3.ZERO
	inward_direction = inward_direction.normalized()

	var first_axis_variant: Variant = axis_candidates[0]
	if not (first_axis_variant is Vector3):
		return Vector3.ZERO
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
		return Vector3.ZERO
	return best_axis.normalized()


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


func _resolve_world_normal(component: Object) -> Vector3:
	if component == null:
		return Vector3.FORWARD
	if component.has_method("get_fade_normal_world"):
		var normal_variant: Variant = component.call("get_fade_normal_world")
		if normal_variant is Vector3:
			return normal_variant as Vector3
	return Vector3.FORWARD


func _resolve_component_origin(component: Object, fallback_target: Node3D) -> Vector3:
	if component is Node3D:
		return (component as Node3D).global_position
	if component is Node:
		var parent := (component as Node).get_parent() as Node3D
		if parent != null and is_instance_valid(parent):
			return parent.global_position
	if fallback_target != null:
		return fallback_target.global_position
	return Vector3.ZERO


# --- Dependency resolution ---

func _resolve_camera_manager() -> I_CAMERA_MANAGER:
	_camera_manager = U_DependencyResolution.resolve(&"camera_manager", _camera_manager, camera_manager) as I_CAMERA_MANAGER
	return _camera_manager


func _resolve_state_store() -> I_StateStore:
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self) as I_StateStore
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
	_material_applier = U_WALL_VISIBILITY_MATERIAL_APPLIER.new()
	return _material_applier


func _get_active_mode_info() -> Dictionary:
	var state: Dictionary = get_frame_state_snapshot()
	return _get_active_mode_info_from_state(state)


func _get_active_mode_info_from_state(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {"has_store": false, "active_mode": "", "is_orbit": false}
	var active_mode: String = U_VCAM_SELECTORS.get_active_mode(state).to_lower()
	return {"has_store": true, "active_mode": active_mode, "is_orbit": active_mode == "orbit"}


func _resolve_player_position_data() -> Dictionary:
	var state: Dictionary = get_frame_state_snapshot()
	return _resolve_player_position_data_from_state(state)


func _resolve_player_position_data_from_state(state: Dictionary) -> Dictionary:
	if state.is_empty():
		var store: I_StateStore = _resolve_state_store()
		if store == null:
			return {}
		state = store.get_state()
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


func _resolve_wall_visibility_config_values() -> Dictionary:
	var default_values := {
		"fade_dot_threshold": 0.3,
		"fade_speed": 4.0,
		"min_alpha": 0.05,
		"clip_height_offset": 1.5,
		"room_aabb_margin": 2.0,
		"corridor_occlusion_margin": 2.0,
		"invalidate_interval": 30,
		"mobile_tick_interval": 4,
		"roof_normal_dot_min": 0.9,
		"roof_height_margin": 0.5,
	}
	var config_variant: Variant = wall_visibility_config
	if config_variant == null:
		config_variant = DEFAULT_WALL_VISIBILITY_CONFIG
	if config_variant == null or not (config_variant is Resource):
		return default_values

	var config_resource: Resource = config_variant as Resource
	if config_resource.get_script() != RS_WALL_VISIBILITY_CONFIG_SCRIPT:
		return default_values

	return {
		"fade_dot_threshold": clampf(float(config_resource.get("fade_dot_threshold")), 0.0, 1.0),
		"fade_speed": maxf(float(config_resource.get("fade_speed")), 0.0),
		"min_alpha": clampf(float(config_resource.get("min_alpha")), 0.0, 1.0),
		"clip_height_offset": float(config_resource.get("clip_height_offset")),
		"room_aabb_margin": maxf(float(config_resource.get("room_aabb_margin")), 0.0),
		"corridor_occlusion_margin": maxf(float(config_resource.get("corridor_occlusion_margin")), 0.0),
		"invalidate_interval": maxi(int(config_resource.get("invalidate_interval")), 1),
		"mobile_tick_interval": maxi(int(config_resource.get("mobile_tick_interval")), 1),
		"roof_normal_dot_min": clampf(float(config_resource.get("roof_normal_dot_min")), 0.0, 1.0),
		"roof_height_margin": maxf(float(config_resource.get("roof_height_margin")), 0.0),
	}


func _resolve_settings(component: Object) -> Dictionary:
	var component_settings: Variant = component.get("settings")
	if component_settings != null and component_settings is Resource:
		var resource: Resource = component_settings as Resource
		if resource.get_script() == RS_ROOM_FADE_SETTINGS_SCRIPT:
			if resource.has_method("get_resolved_values"):
				var resolved_variant: Variant = resource.call("get_resolved_values")
				if resolved_variant is Dictionary:
					return resolved_variant as Dictionary
	return {}


func _collect_mesh_targets(component: Object) -> Array:
	if component == null:
		return []
	var component_id: int = component.get_instance_id()
	var cache_is_valid: bool = component.has_method("is_target_cache_valid") and component.call("is_target_cache_valid")
	if cache_is_valid and _filtered_targets_valid.get(component_id, false):
		if _filtered_targets_by_component.has(component_id):
			return _filtered_targets_by_component[component_id] as Array
	if not component.has_method("collect_mesh_targets"):
		return []
	var targets_variant: Variant = component.call("collect_mesh_targets")
	if not (targets_variant is Array):
		return []
	var targets: Array = []
	for target_variant in targets_variant as Array:
		if _is_supported_target(target_variant):
			targets.append(target_variant)
	_filtered_targets_by_component[component_id] = targets
	_filtered_targets_valid[component_id] = true
	return targets


func _is_supported_target(target_variant: Variant) -> bool:
	if not (target_variant is Node3D) or not is_instance_valid(target_variant):
		return false
	var target: Node3D = target_variant as Node3D
	var target_class: String = target.get_class()
	# Pass 1: exact class match
	for handler in _target_type_handlers:
		if String(handler["type_name"]) == target_class:
			return true
	# Pass 2: inheritance fallback
	for handler in _target_type_handlers:
		if target.is_class(String(handler["type_name"])):
			return true
	return false


# --- Restore / cleanup ---

func _cleanup_stale_targets(active_targets: Dictionary) -> void:
	var applier: Variant = _resolve_material_applier()
	var stale_targets: Array = []
	var stale_ids: Array = []
	for target_id_variant in _tracked_targets.keys():
		var target_id: int = int(target_id_variant)
		if active_targets.has(target_id):
			continue
		var target_variant: Variant = _tracked_targets.get(target_id, null)
		if target_variant is Node3D and is_instance_valid(target_variant):
			stale_targets.append(target_variant)
		stale_ids.append(target_id)

	if not stale_targets.is_empty():
		if applier != null:
			applier.restore_original_materials(stale_targets)
		for target_variant in stale_targets:
			if not (target_variant is Node3D) or not is_instance_valid(target_variant):
				continue
			var stale_target: Node3D = target_variant as Node3D
			_restore_target_visibility(stale_target, stale_target.get_instance_id())
		for stale_id in stale_ids:
			_target_fade_by_id.erase(stale_id)
			_cached_normals.erase(stale_id)
			_cached_half_extents.erase(stale_id)
			_cached_aabbs.erase(stale_id)
			_cached_transform_hashes.erase(stale_id)
			_original_visibility_by_id.erase(stale_id)

	# Update tracking in-place: add new, remove stale
	for target_id_variant in active_targets.keys():
		var target_id: int = int(target_id_variant)
		if not _tracked_targets.has(target_id):
			_tracked_targets[target_id] = active_targets[target_id]
	for stale_id in stale_ids:
		_tracked_targets.erase(stale_id)


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
			_target_fade_by_id.erase(target_id)
			_restore_target_visibility(target, target_id)
			restore_targets.append(target)

	for target_variant in _tracked_targets.values():
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var tracked_target: Node3D = target_variant as Node3D
		var tracked_id: int = tracked_target.get_instance_id()
		if seen_targets.has(tracked_id):
			continue
		seen_targets[tracked_id] = true
		_target_fade_by_id.erase(tracked_id)
		_cached_normals.erase(tracked_id)
		_cached_half_extents.erase(tracked_id)
		_cached_aabbs.erase(tracked_id)
		_cached_transform_hashes.erase(tracked_id)
		_restore_target_visibility(tracked_target, tracked_id)
		restore_targets.append(tracked_target)

	var applier: Variant = _resolve_material_applier()
	if applier != null and not restore_targets.is_empty():
		applier.restore_original_materials(restore_targets)
	_tracked_targets.clear()
	_target_fade_by_id.clear()
	_cached_normals.clear()
	_cached_half_extents.clear()
	_cached_aabbs.clear()
	_cached_transform_hashes.clear()
	_filtered_targets_by_component.clear()
	_filtered_targets_valid.clear()
	_original_visibility_by_id.clear()


func _is_mobile_hide_mode() -> bool:
	return _is_mobile and mobile_hide_walls_instead_of_fade


func _apply_mobile_visibility_state(target: Node3D, target_id: int, fade_amount: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not _original_visibility_by_id.has(target_id):
		_original_visibility_by_id[target_id] = target.visible
	var should_hide: bool = fade_amount > MOBILE_HIDE_FADE_THRESHOLD
	if should_hide:
		target.visible = false
		return
	_restore_target_visibility(target, target_id)


func _restore_target_visibility(target: Node3D, target_id: int) -> void:
	if target == null or not is_instance_valid(target):
		_original_visibility_by_id.erase(target_id)
		return
	if _original_visibility_by_id.has(target_id):
		target.visible = bool(_original_visibility_by_id.get(target_id, true))
		_original_visibility_by_id.erase(target_id)


# --- Utility ---

func _describe_node(node: Node) -> String:
	if node == null:
		return "<null>"
	if not is_instance_valid(node):
		return "<freed>"
	return "%s:%s" % [node.name, node.get_class()]


func _describe_object(obj: Object) -> String:
	if obj == null:
		return "<null>"
	if not is_instance_valid(obj):
		return "<freed>"
	return "%s:%s" % [obj.name, obj.get_class()]


func _compute_transform_hash(target: Node3D) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	return hash(target.global_transform)
