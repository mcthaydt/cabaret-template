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
const DEFAULT_ROOM_FADE_SETTINGS := preload("res://resources/display/vcam/cfg_default_room_fade.tres")

const ROOM_FADE_GROUP_TYPE := StringName("RoomFadeGroup")
const MIN_NORMAL_LENGTH_SQUARED := 0.000001

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_STATE_STORE = null

var material_applier: Variant = null

var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_STATE_STORE = null
var _material_applier: Variant = null
var _tracked_targets: Dictionary = {}  # int -> Node3D (MeshInstance3D or CSGShape3D)
var _target_alpha_by_id: Dictionary = {}  # int -> float

func _init() -> void:
	execution_priority = 110

func on_configured() -> void:
	_camera_manager = _resolve_camera_manager()

func process_tick(delta: float) -> void:
	var components: Array = _get_room_fade_components()
	if components.is_empty():
		_restore_stale_targets({})
		return

	var mode_info: Dictionary = _get_active_mode_info()
	if not bool(mode_info.get("is_orbit", false)):
		_restore_components_to_opaque(components)
		return

	var main_camera: Camera3D = _resolve_active_camera()
	if main_camera == null or not is_instance_valid(main_camera):
		_restore_stale_targets({})
		return

	var applier: Variant = _resolve_material_applier()
	if applier == null:
		return

	var camera_forward: Vector3 = -main_camera.global_transform.basis.z
	var active_targets: Dictionary = {}
	var resolved_delta: float = maxf(delta, 0.0)

	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object

		var targets: Array = _collect_mesh_targets(component)
		if targets.is_empty():
			continue

		applier.apply_fade_material(targets)

		var settings: Dictionary = _resolve_settings(component)
		var min_alpha: float = clampf(float(settings.get("min_alpha", 0.05)), 0.0, 1.0)
		var fade_speed: float = maxf(float(settings.get("fade_speed", 4.0)), 0.0)
		var component_alpha_sum: float = 0.0
		var component_alpha_count: int = 0

		for target_variant in targets:
			if not _is_supported_target(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()
			var target_normal: Vector3 = _resolve_target_world_normal(component, target, targets.size())
			var dot_value: float = camera_forward.dot(target_normal)
			var target_alpha: float = _resolve_target_alpha(camera_forward, target_normal, settings)
			var current_alpha: float = _resolve_current_target_alpha(target_id, component)
			var next_alpha: float = current_alpha
			if fade_speed > 0.0:
				next_alpha = move_toward(next_alpha, target_alpha, fade_speed * resolved_delta)
			next_alpha = clampf(next_alpha, min_alpha, 1.0)

			_target_alpha_by_id[target_id] = next_alpha
			applier.update_fade_alpha([target], next_alpha)
			active_targets[target_id] = target
			component_alpha_sum += next_alpha
			component_alpha_count += 1

		if component_alpha_count > 0:
			component.set("current_alpha", component_alpha_sum / float(component_alpha_count))

	_restore_stale_targets(active_targets)

func _exit_tree() -> void:
	_restore_stale_targets({})
	_target_alpha_by_id.clear()

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

func _resolve_target_alpha(camera_forward: Vector3, wall_normal: Vector3, settings: Dictionary) -> float:
	var dot_value: float = camera_forward.dot(wall_normal)
	var threshold: float = clampf(float(settings.get("fade_dot_threshold", 0.3)), 0.0, 1.0)
	var min_alpha: float = clampf(float(settings.get("min_alpha", 0.05)), 0.0, 1.0)
	if dot_value > threshold:
		return min_alpha
	return 1.0

func _resolve_target_world_normal(component: Object, target: Node3D, target_count: int) -> Vector3:
	var component_normal: Vector3 = _resolve_world_normal(component)
	if target == null or not is_instance_valid(target):
		return component_normal
	if target_count <= 1:
		return component_normal

	var component_origin: Vector3 = _resolve_component_origin(component, target)
	var inward_planar: Vector3 = component_origin - target.global_position
	inward_planar.y = 0.0
	if inward_planar.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return component_normal
	return inward_planar.normalized()

func _resolve_component_origin(component: Object, fallback_target: Node3D) -> Vector3:
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
