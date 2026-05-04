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
const DEBUG_MAX_FILTER_LOGS := 12
const GROUP_ADJACENCY_GROW: float = 1.5

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_STATE_STORE = null
@export var debug_room_fade_logging: bool = true
@export var debug_room_fade_log_interval_frames: int = 1

var material_applier: Variant = null

var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_STATE_STORE = null
var _material_applier: Variant = null
var _tracked_targets: Dictionary = {}  # int -> Node3D (MeshInstance3D or CSGShape3D)
var _target_alpha_by_id: Dictionary = {}  # int -> float
var _cached_normals: Dictionary = {}  # int -> Vector3
var _cached_centroids: Dictionary = {}  # int (component instance id) -> Vector3
var _debug_tick_counter: int = 0
var _group_adjacency_map: Dictionary = {}  # StringName -> Array[StringName]
var _group_adjacency_computed: bool = false
var _group_alpha_by_tag: Dictionary = {}  # StringName -> float

func _init() -> void:
	execution_priority = 110

func on_configured() -> void:
	_camera_manager = _resolve_camera_manager()

func process_tick(delta: float) -> void:
	var should_log_debug: bool = _should_log_debug_tick()
	var components: Array = _get_room_fade_components()
	var initial_component_count: int = components.size()

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

	var camera_forward: Vector3 = -main_camera.global_transform.basis.z
	if camera_forward.length_squared() > MIN_NORMAL_LENGTH_SQUARED:
		camera_forward = camera_forward.normalized()
	var active_targets: Dictionary = {}
	var resolved_delta: float = maxf(delta, 0.0)
	_cached_centroids.clear()
	_group_alpha_by_tag.clear()

	components = _filter_components_by_active_room(components, should_log_debug)

	if not _group_adjacency_computed:
		_compute_group_adjacency(components)

	if should_log_debug:
		_debug_log_tick_header(
			mode_info,
			main_camera,
			camera_forward,
			initial_component_count,
			components.size(),
			resolved_delta
		)

	# Track component data for adjacency second pass
	var processed_components: Array = []

	for component_variant in components:
		if should_log_debug and component_variant != null and is_instance_valid(component_variant) and component_variant is Object:
			_debug_log_normal_diagnosis(component_variant as Object)
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object

		var targets: Array = _collect_mesh_targets(component)
		if targets.is_empty():
			continue

		_cache_component_centroid(component, targets)
		applier.invalidate_externally_removed()
		applier.apply_fade_material(targets)

		var settings: Dictionary = _resolve_settings(component)
		var threshold: float = clampf(float(settings.get("fade_dot_threshold", 0.3)), 0.0, 1.0)
		var min_alpha: float = clampf(float(settings.get("min_alpha", 0.0)), 0.0, 1.0)
		var fade_speed: float = maxf(float(settings.get("fade_speed", 4.0)), 0.0)
		var component_world_normal: Vector3 = _resolve_world_normal(component)
		var component_dot_value: float = 0.0
		if component_world_normal.length_squared() > MIN_NORMAL_LENGTH_SQUARED:
			component_dot_value = camera_forward.dot(component_world_normal)
		var component_target_alpha: float = _resolve_target_alpha(component_dot_value, settings)
		var component_is_fading: bool = component_target_alpha < 1.0
		var component_alpha_sum: float = 0.0
		var component_alpha_count: int = 0
		var faded_target_count: int = 0
		var debug_target_logs: Array[String] = []

		for target_variant in targets:
			if not _is_supported_target(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()
			var target_normal: Vector3 = component_world_normal
			var target_normal_source: String = "component_group_normal"
			if _cached_normals.has(target_id):
				target_normal = _cached_normals[target_id] as Vector3
				target_normal_source = "cached"
			else:
				_cached_normals[target_id] = component_world_normal
			var dot_value: float = component_dot_value
			var target_alpha: float = component_target_alpha
			var current_alpha: float = _resolve_current_target_alpha(target_id, component)
			var next_alpha: float = current_alpha
			if fade_speed > 0.0:
				next_alpha = move_toward(next_alpha, target_alpha, fade_speed * resolved_delta)
			next_alpha = clampf(next_alpha, min_alpha, 1.0)
			if component_is_fading:
				faded_target_count += 1

			_target_alpha_by_id[target_id] = next_alpha
			applier.update_fade_alpha([target], next_alpha)

			active_targets[target_id] = target
			component_alpha_sum += next_alpha
			component_alpha_count += 1
			if should_log_debug and _should_log_target_decision(dot_value, threshold, target_alpha):
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

		if component_alpha_count > 0:
			var component_average_alpha: float = component_alpha_sum / float(component_alpha_count)
			component.set("current_alpha", component_average_alpha)
			var group_tag: StringName = component.get("group_tag") as StringName
			if group_tag != StringName(""):
				_group_alpha_by_tag[group_tag] = component_average_alpha
			processed_components.append({
				"component": component,
				"targets": targets,
				"group_tag": group_tag,
			})
			if should_log_debug:
				_debug_log_component_summary(
					component,
					targets,
					faded_target_count,
					component_average_alpha,
					threshold,
					min_alpha,
					fade_speed,
					debug_target_logs
				)

	# Adjacency floor pass: boost targets of groups adjacent to higher-alpha groups
	for proc_data in processed_components:
		var group_tag: StringName = proc_data.get("group_tag") as StringName
		if group_tag == StringName(""):
			continue
		var adjacent_tags: Array = _group_adjacency_map.get(group_tag, []) as Array
		if adjacent_tags.is_empty():
			continue
		var adj_floor: float = 0.0
		for adj_tag_variant in adjacent_tags:
			var adj_tag: StringName = adj_tag_variant as StringName
			adj_floor = maxf(adj_floor, float(_group_alpha_by_tag.get(adj_tag, 0.0)))
		if adj_floor <= 0.0:
			continue
		var component: Object = proc_data.get("component") as Object
		var current_avg: float = float(component.get("current_alpha"))
		if current_avg >= adj_floor:
			continue
		var targets: Array = proc_data.get("targets") as Array
		var boosted_sum: float = 0.0
		var boosted_count: int = 0
		var boosted_target_count: int = 0
		for target_variant in targets:
			if not _is_supported_target(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()
			var current_target_alpha: float = float(_target_alpha_by_id.get(target_id, current_avg))
			if current_target_alpha < adj_floor:
				_target_alpha_by_id[target_id] = adj_floor
				applier.update_fade_alpha([target], adj_floor)
				boosted_sum += adj_floor
				boosted_target_count += 1
			else:
				boosted_sum += current_target_alpha
			boosted_count += 1
		if boosted_count > 0:
			var boosted_average_alpha: float = boosted_sum / float(boosted_count)
			component.set("current_alpha", boosted_average_alpha)
			if should_log_debug and boosted_target_count > 0:
				_debug_log_adjacency_floor_applied(
					group_tag,
					adjacent_tags,
					current_avg,
					adj_floor,
					boosted_target_count,
					boosted_count,
					boosted_average_alpha
				)

	_restore_stale_targets(active_targets)

func get_group_adjacency_map() -> Dictionary:
	return _group_adjacency_map.duplicate(true)

func invalidate_group_adjacency() -> void:
	_group_adjacency_computed = false
	_group_adjacency_map.clear()

func _exit_tree() -> void:
	_restore_stale_targets({})
	_target_alpha_by_id.clear()
	_cached_normals.clear()
	_cached_centroids.clear()
	_group_adjacency_map.clear()
	_group_adjacency_computed = false
	_group_alpha_by_tag.clear()

func _compute_group_adjacency(components: Array) -> void:
	_group_adjacency_map.clear()
	var should_log_debug: bool = debug_room_fade_logging
	var valid_components: Array = []
	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var group_tag: StringName = component.get("group_tag") as StringName
		if group_tag == StringName(""):
			continue
		valid_components.append(component)

	for i in range(valid_components.size()):
		var comp_a: Object = valid_components[i] as Object
		var tag_a: StringName = comp_a.get("group_tag") as StringName
		var targets_a: Array = _collect_mesh_targets(comp_a)
		var aabb_a: AABB = _resolve_room_aabb_from_targets(targets_a)
		var grown_a: AABB = aabb_a.grow(GROUP_ADJACENCY_GROW)

		for j in range(i + 1, valid_components.size()):
			var comp_b: Object = valid_components[j] as Object
			var tag_b: StringName = comp_b.get("group_tag") as StringName
			var targets_b: Array = _collect_mesh_targets(comp_b)
			var aabb_b: AABB = _resolve_room_aabb_from_targets(targets_b)
			var grown_b: AABB = aabb_b.grow(GROUP_ADJACENCY_GROW)
			var center_distance: float = aabb_a.get_center().distance_to(aabb_b.get_center())
			var intersects: bool = grown_a.intersects(grown_b)
			if should_log_debug:
				print(
					"[RoomFadeDiag] adjacency_candidate a=%s b=%s center_distance=%.2f intersects=%s aabb_a=%s aabb_b=%s" % [
						str(tag_a),
						str(tag_b),
						center_distance,
						str(intersects),
						_format_aabb(aabb_a),
						_format_aabb(aabb_b),
					]
				)

			if intersects:
				if not _group_adjacency_map.has(tag_a):
					_group_adjacency_map[tag_a] = []
				if not _group_adjacency_map.has(tag_b):
					_group_adjacency_map[tag_b] = []
				(_group_adjacency_map[tag_a] as Array).append(tag_b)
				(_group_adjacency_map[tag_b] as Array).append(tag_a)

	_group_adjacency_computed = true
	if should_log_debug:
		_debug_log_adjacency_map_snapshot()

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
		"min_alpha": 0.0,
	}

func _collect_mesh_targets(component: Object) -> Array:
	if component == null:
		return []
	if not component.has_method("collect_mesh_targets"):
		return []
	var targets_variant: Variant = component.call("collect_mesh_targets")
	if not (targets_variant is Array):
		return []

	var targets: Array = []
	for target_variant in targets_variant as Array:
		if _is_supported_target(target_variant):
			targets.append(target_variant)
	return targets

func _resolve_world_normal(component: Object) -> Vector3:
	if component == null:
		return Vector3.FORWARD
	if component.has_method("get_fade_normal_world"):
		var normal_variant: Variant = component.call("get_fade_normal_world")
		if normal_variant is Vector3:
			return normal_variant as Vector3
	return Vector3.FORWARD

func _resolve_target_alpha(dot_value: float, settings: Dictionary) -> float:
	var threshold: float = clampf(float(settings.get("fade_dot_threshold", 0.3)), 0.0, 1.0)
	var min_alpha: float = clampf(float(settings.get("min_alpha", 0.0)), 0.0, 1.0)
	if dot_value > threshold:
		return min_alpha
	return 1.0

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
	var inward_direction: Vector3 = component_origin - target.global_position
	inward_direction.y = 0.0
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
			if not _is_supported_target(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()
			if seen_targets.has(target_id):
				continue
			seen_targets[target_id] = true
			_target_alpha_by_id.erase(target_id)
			restore_targets.append(target)

	for target_variant in _tracked_targets.values():
		if not _is_supported_target(target_variant):
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
		if _is_supported_target(target_variant):
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
	if target_alpha < 1.0:
		return true
	return absf(dot_value - threshold) <= DEBUG_DOT_MARGIN

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
	total_component_count: int,
	filtered_component_count: int,
	delta: float
) -> void:
	print(
		"[RoomFadeDebug] tick=%d mode=%s components=%d filtered=%d tracked_targets=%d delta=%.3f camera=%s forward=%s" % [
			_debug_tick_counter,
			str(mode_info.get("active_mode", "")),
			total_component_count,
			filtered_component_count,
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
	if faded_target_count > 0 and min_alpha > 0.0:
		print(
			"[RoomFadeDiag]   min_alpha_floor_active component=%s min_alpha=%.3f (cannot fully disappear while this is > 0.0)" % [
				_describe_object(component),
				min_alpha,
			]
		)
	for log_line in target_logs:
		print(log_line)

func _debug_log_adjacency_floor_applied(
	group_tag: StringName,
	adjacent_tags: Array,
	previous_alpha: float,
	adjacency_floor: float,
	boosted_target_count: int,
	target_count: int,
	boosted_average_alpha: float
) -> void:
	print(
		"[RoomFadeDiag] adjacency_floor_applied group=%s adjacent=%s prev_avg=%.3f floor=%.3f boosted_targets=%d/%d new_avg=%.3f" % [
			str(group_tag),
			str(adjacent_tags),
			previous_alpha,
			adjacency_floor,
			boosted_target_count,
			target_count,
			boosted_average_alpha,
		]
	)

func _debug_log_adjacency_map_snapshot() -> void:
	if _group_adjacency_map.is_empty():
		print("[RoomFadeDiag] adjacency_map empty")
		return
	var groups: Array = _group_adjacency_map.keys()
	groups.sort()
	for group_variant in groups:
		var group_tag: StringName = group_variant as StringName
		var adjacent: Array = _group_adjacency_map.get(group_tag, []) as Array
		print("[RoomFadeDiag] adjacency_map group=%s adjacent=%s" % [
			str(group_tag),
			str(adjacent),
		])

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

func _format_aabb(aabb: AABB) -> String:
	return "pos=%s size=%s" % [
		_format_vector3(aabb.position),
		_format_vector3(aabb.size),
	]

func _filter_components_by_active_room(components: Array, should_log_debug: bool = false) -> Array:
	if components.size() <= 1:
		return components

	var player_data: Dictionary = _resolve_player_position_data()
	if player_data.is_empty():
		if should_log_debug:
			print("[RoomFadeDiag] active_room_filter skipped=no_player_position")
		return components
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3

	var matching: Array = []
	var logged_components: int = 0
	if should_log_debug:
		print(
			"[RoomFadeDiag] active_room_filter player_pos=%s components=%d" % [
				_format_vector3(player_position),
				components.size(),
			]
		)
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
		var is_matching_room: bool = expanded.has_point(player_position)
		if should_log_debug and logged_components < DEBUG_MAX_FILTER_LOGS:
			print(
				"[RoomFadeDiag]   room_candidate=%s room_aabb=%s expanded_aabb=%s contains_player=%s target_count=%d" % [
					_describe_object(component),
					_format_aabb(room_aabb),
					_format_aabb(expanded),
					str(is_matching_room),
					targets.size(),
				]
			)
			logged_components += 1
		if is_matching_room:
			matching.append(component_variant)

	if should_log_debug:
		print("[RoomFadeDiag] active_room_filter matched=%d/%d" % [matching.size(), components.size()])

	if matching.is_empty():
		return components
	return matching

func _resolve_room_aabb_from_targets(targets: Array) -> AABB:
	var first_valid: Node3D = null
	for target_variant in targets:
		if _is_supported_target(target_variant):
			first_valid = target_variant as Node3D
			break
	if first_valid == null:
		return AABB()

	var result: AABB = AABB(first_valid.global_position, Vector3.ZERO)
	for target_variant in targets:
		if not _is_supported_target(target_variant):
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
