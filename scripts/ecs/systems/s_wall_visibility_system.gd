@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_WallVisibilitySystem

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_VCAM_SELECTORS := preload("res://scripts/state/selectors/u_vcam_selectors.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")
const RS_ROOM_FADE_SETTINGS_SCRIPT := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")
const U_WALL_VISIBILITY_MATERIAL_APPLIER := preload("res://scripts/utils/lighting/u_wall_visibility_material_applier.gd")
const U_ENTITY_SELECTORS := preload("res://scripts/state/selectors/u_entity_selectors.gd")
const DEFAULT_ROOM_FADE_SETTINGS := preload("res://resources/display/vcam/cfg_default_room_fade.tres")

const ROOM_FADE_GROUP_TYPE := StringName("RoomFadeGroup")
const MIN_NORMAL_LENGTH_SQUARED := 0.000001
const DEFAULT_CLIP_HEIGHT_OFFSET := 1.5
const INVALIDATE_INTERVAL := 30

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_STATE_STORE = null
@export var debug_logging: bool = false

var material_applier: Variant = null

var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_STATE_STORE = null
var _material_applier: Variant = null
var _tracked_targets: Dictionary = {}
var _target_fade_by_id: Dictionary = {}
var _invalidate_tick_counter: int = 0


func _init() -> void:
	execution_priority = 110


func on_configured() -> void:
	_camera_manager = _resolve_camera_manager()


func process_tick(delta: float) -> void:
	var components: Array = get_components(ROOM_FADE_GROUP_TYPE)

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
	var resolved_delta: float = maxf(delta, 0.0)
	var player_data: Dictionary = _resolve_player_position_data()
	var has_player: bool = player_data.has("position")
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3

	_invalidate_tick_counter += 1
	if _invalidate_tick_counter % INVALIDATE_INTERVAL == 0:
		applier.invalidate_externally_removed()

	var active_targets: Dictionary = {}

	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object

		var targets: Array = _collect_mesh_targets(component)
		if targets.is_empty():
			continue

		applier.apply_visibility_material(targets)

		var clip_height_offset: float = DEFAULT_CLIP_HEIGHT_OFFSET
		if component.has_method("get") and true:
			var offset_variant: Variant = component.get("clip_height_offset")
			if offset_variant is float or offset_variant is int:
				clip_height_offset = float(offset_variant)

		var clip_y: float = 100.0
		if has_player:
			clip_y = player_position.y + clip_height_offset

		var settings: Dictionary = _resolve_settings(component)
		var threshold: float = clampf(float(settings.get("fade_dot_threshold", 0.3)), 0.0, 1.0)
		var fade_speed: float = maxf(float(settings.get("fade_speed", 4.0)), 0.0)
		var component_fade_sum: float = 0.0
		var component_fade_count: int = 0

		for target_variant in targets:
			if not (target_variant is Node3D) or not is_instance_valid(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()

			var target_fade: float = _resolve_directional_fade(
				camera_forward, component, target, targets.size(), threshold
			)

			var current_fade: float = float(_target_fade_by_id.get(target_id, 0.0))
			var next_fade: float = current_fade
			if fade_speed > 0.0:
				next_fade = move_toward(next_fade, target_fade, fade_speed * resolved_delta)
			next_fade = clampf(next_fade, 0.0, 1.0)

			_target_fade_by_id[target_id] = next_fade
			applier.update_uniforms(target, clip_y, next_fade)
			active_targets[target_id] = target

			component_fade_sum += next_fade
			component_fade_count += 1

		if component_fade_count > 0:
			var avg_fade: float = component_fade_sum / float(component_fade_count)
			component.set("current_alpha", 1.0 - avg_fade)

	_restore_stale_targets(active_targets)


func _exit_tree() -> void:
	_restore_stale_targets({})
	_target_fade_by_id.clear()


func _resolve_directional_fade(
	camera_forward: Vector3,
	component: Object,
	target: Node3D,
	target_count: int,
	threshold: float
) -> float:
	var wall_normal: Vector3 = _resolve_target_world_normal(component, target, target_count)
	var dot_value: float = camera_forward.dot(wall_normal)
	if absf(dot_value) > threshold:
		return 1.0
	return 0.0


func _resolve_target_world_normal(component: Object, target: Node3D, target_count: int) -> Vector3:
	var component_normal: Vector3 = _resolve_world_normal(component)
	if target == null or not is_instance_valid(target):
		return component_normal
	if target_count <= 1:
		return component_normal

	var component_origin: Vector3 = _resolve_component_origin(component, target)
	var inward_raw: Vector3 = component_origin - target.global_position
	var inward_planar: Vector3 = inward_raw
	inward_planar.y = 0.0
	if inward_planar.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return component_normal
	return inward_planar.normalized()


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
	_material_applier = U_WALL_VISIBILITY_MATERIAL_APPLIER.new()
	return _material_applier


func _get_active_mode_info() -> Dictionary:
	var store: I_STATE_STORE = _resolve_state_store()
	if store == null:
		return {"has_store": false, "active_mode": "", "is_orbit": false}
	var state: Dictionary = store.get_state()
	var active_mode: String = U_VCAM_SELECTORS.get_active_mode(state).to_lower()
	return {"has_store": true, "active_mode": active_mode, "is_orbit": active_mode == "orbit"}


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
	return {"fade_dot_threshold": 0.3, "fade_speed": 4.0, "min_alpha": 0.05}


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


func _is_supported_target(target_variant: Variant) -> bool:
	if target_variant is MeshInstance3D:
		var mesh_target: MeshInstance3D = target_variant as MeshInstance3D
		return mesh_target != null and is_instance_valid(mesh_target)
	if target_variant is CSGShape3D:
		var csg_target: CSGShape3D = target_variant as CSGShape3D
		return csg_target != null and is_instance_valid(csg_target)
	return false


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
		_target_fade_by_id.erase(target_id)
	if not stale_targets.is_empty():
		applier.restore_original_materials(stale_targets)
	_tracked_targets = active_targets.duplicate()


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
		restore_targets.append(tracked_target)

	var applier: Variant = _resolve_material_applier()
	if applier != null and not restore_targets.is_empty():
		applier.restore_original_materials(restore_targets)
	_tracked_targets.clear()
	_target_fade_by_id.clear()
