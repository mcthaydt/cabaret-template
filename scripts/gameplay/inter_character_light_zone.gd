extends "res://scripts/gameplay/base_volume_controller.gd"
class_name Inter_CharacterLightZone

const RS_CHARACTER_LIGHT_ZONE_CONFIG := preload("res://scripts/resources/lighting/rs_character_light_zone_config.gd")
const RS_TRIGGER_SETTINGS := preload("res://scripts/resources/ecs/rs_scene_trigger_settings.gd")
const U_INTERACTION_CONFIG_RESOLVER := preload("res://scripts/gameplay/helpers/u_interaction_config_resolver.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const I_CHARACTER_LIGHTING_MANAGER := preload("res://scripts/interfaces/i_character_lighting_manager.gd")

const LIGHTING_SERVICE := StringName("character_lighting_manager")
const SCENE_SERVICE := StringName("scene_manager")
const SCENE_SLICE := StringName("scene")
const MIN_DIMENSION := 0.01

var _config: Resource = null
var _cached_store: I_StateStore = null
var _cached_scene_manager: I_SceneManager = null
var _cached_lighting_manager: I_CHARACTER_LIGHTING_MANAGER = null

@export var config: Resource:
	get:
		return _config
	set(value):
		if value != null and not U_INTERACTION_CONFIG_RESOLVER.script_matches(value, RS_CHARACTER_LIGHT_ZONE_CONFIG):
			return
		_config = value
		_apply_config_to_volume_settings()

func _ready() -> void:
	_apply_config_to_volume_settings()
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	call_deferred("_register_with_lighting_manager")

func _exit_tree() -> void:
	_unregister_from_lighting_manager()
	_cached_store = null
	_cached_scene_manager = null
	_cached_lighting_manager = null
	super._exit_tree()

func get_zone_id() -> StringName:
	var typed := _get_typed_config()
	if typed == null:
		return StringName("")
	return typed.zone_id

func get_zone_priority() -> int:
	var typed := _get_typed_config()
	if typed == null:
		return 0
	return typed.priority

func get_zone_profile() -> Resource:
	var typed := _get_typed_config()
	if typed == null:
		return null
	return typed.profile

func get_zone_profile_snapshot() -> Dictionary:
	var typed := _get_typed_config()
	if typed == null or typed.profile == null:
		return {}
	if not typed.profile.has_method("get_resolved_values"):
		return {}
	var profile_variant: Variant = typed.profile.call("get_resolved_values")
	if not (profile_variant is Dictionary):
		return {}
	var profile := profile_variant as Dictionary
	return profile.duplicate(true)

func get_zone_metadata() -> Dictionary:
	var resolved_zone_id := get_zone_id()
	if resolved_zone_id.is_empty():
		resolved_zone_id = StringName(String(name).to_lower())
	var stable_key := _build_stable_key(resolved_zone_id)

	return {
		"zone_id": resolved_zone_id,
		"node_name": StringName(name),
		"stable_key": stable_key,
		"priority": get_zone_priority(),
		"blend_weight": _get_blend_weight(),
		"profile": get_zone_profile_snapshot().duplicate(true),
	}

func get_influence_weight(_world_position: Vector3) -> float:
	if not is_enabled():
		return 0.0
	if _is_transition_blocked():
		return 0.0
	var typed := _get_typed_config()
	if typed == null:
		return 0.0
	var local_point := to_local(_world_position) - typed.local_offset
	var shape_weight := _calculate_shape_weight(typed, local_point)
	return shape_weight * _get_blend_weight()

func _get_typed_config() -> RS_CharacterLightZoneConfig:
	if _config == null:
		return null
	if not U_INTERACTION_CONFIG_RESOLVER.script_matches(_config, RS_CHARACTER_LIGHT_ZONE_CONFIG):
		return null
	return _config as RS_CharacterLightZoneConfig

func _apply_config_to_volume_settings() -> void:
	var typed := _get_typed_config()
	if typed == null:
		return

	var runtime_settings := RS_TRIGGER_SETTINGS.new()
	runtime_settings.resource_local_to_scene = true
	runtime_settings.shape_type = int(typed.shape_type)
	runtime_settings.box_size = _clamp_box_size(typed.box_size)
	runtime_settings.cyl_radius = maxf(typed.cylinder_radius, MIN_DIMENSION)
	runtime_settings.cyl_height = maxf(typed.cylinder_height, MIN_DIMENSION)
	runtime_settings.local_offset = typed.local_offset
	runtime_settings.enable_on_ready = true
	runtime_settings.ignore_initial_overlap = false
	runtime_settings.toggle_visuals_on_enable = false
	settings = runtime_settings

func _clamp_box_size(value: Vector3) -> Vector3:
	return Vector3(
		maxf(value.x, MIN_DIMENSION),
		maxf(value.y, MIN_DIMENSION),
		maxf(value.z, MIN_DIMENSION)
	)

func _calculate_shape_weight(config_resource: RS_CharacterLightZoneConfig, local_point: Vector3) -> float:
	match config_resource.shape_type:
		RS_CharacterLightZoneConfig.ShapeType.CYLINDER:
			return _calculate_cylinder_weight(config_resource, local_point)
		RS_CharacterLightZoneConfig.ShapeType.BOX:
			return _calculate_box_weight(config_resource, local_point)
		_:
			return 0.0

func _calculate_box_weight(config_resource: RS_CharacterLightZoneConfig, local_point: Vector3) -> float:
	var clamped_size := _clamp_box_size(config_resource.box_size)
	var half_extents := clamped_size * 0.5
	var x_ratio := absf(local_point.x) / half_extents.x
	var y_ratio := absf(local_point.y) / half_extents.y
	var z_ratio := absf(local_point.z) / half_extents.z
	if x_ratio > 1.0 or y_ratio > 1.0 or z_ratio > 1.0:
		return 0.0
	var edge_proximity := maxf(x_ratio, maxf(y_ratio, z_ratio))
	return _apply_falloff(edge_proximity, config_resource.falloff)

func _calculate_cylinder_weight(config_resource: RS_CharacterLightZoneConfig, local_point: Vector3) -> float:
	var radius := maxf(config_resource.cylinder_radius, MIN_DIMENSION)
	var half_height := maxf(config_resource.cylinder_height * 0.5, MIN_DIMENSION)
	var radial_ratio := Vector2(local_point.x, local_point.z).length() / radius
	var vertical_ratio := absf(local_point.y) / half_height
	if radial_ratio > 1.0 or vertical_ratio > 1.0:
		return 0.0
	var edge_proximity := maxf(radial_ratio, vertical_ratio)
	return _apply_falloff(edge_proximity, config_resource.falloff)

func _apply_falloff(edge_proximity: float, falloff: float) -> float:
	var clamped_falloff := clampf(falloff, 0.0, 1.0)
	if clamped_falloff <= 0.0:
		return 1.0

	var core_limit := 1.0 - clamped_falloff
	if edge_proximity <= core_limit:
		return 1.0

	var fade_ratio := (edge_proximity - core_limit) / clamped_falloff
	return clampf(1.0 - fade_ratio, 0.0, 1.0)

func _get_blend_weight() -> float:
	var typed := _get_typed_config()
	if typed == null:
		return 0.0
	return clampf(typed.blend_weight, 0.0, 1.0)

func _build_stable_key(zone_id: StringName) -> String:
	if is_inside_tree():
		return "%s::%s" % [String(get_path()), String(zone_id)]
	return "%s::%s" % [String(name), String(zone_id)]

func _is_transition_blocked() -> bool:
	var store := _get_store()
	if store != null:
		var scene_slice: Dictionary = store.get_slice(SCENE_SLICE)
		if bool(scene_slice.get("is_transitioning", false)):
			return true
		var scene_stack_variant: Variant = scene_slice.get("scene_stack", [])
		if scene_stack_variant is Array:
			var scene_stack := scene_stack_variant as Array
			if not scene_stack.is_empty():
				return true

	var scene_manager := _get_scene_manager()
	if scene_manager != null and scene_manager.is_transitioning():
		return true
	return false

func _get_store() -> I_StateStore:
	if _cached_store != null and is_instance_valid(_cached_store):
		return _cached_store
	_cached_store = U_STATE_UTILS.try_get_store(self)
	return _cached_store

func _get_scene_manager() -> I_SceneManager:
	if _cached_scene_manager != null and is_instance_valid(_cached_scene_manager):
		return _cached_scene_manager
	_cached_scene_manager = U_SERVICE_LOCATOR.try_get_service(SCENE_SERVICE) as I_SceneManager
	return _cached_scene_manager

func _register_with_lighting_manager() -> void:
	var manager := _get_lighting_manager()
	if manager == null:
		return
	manager.register_zone(self)

func _unregister_from_lighting_manager() -> void:
	var manager := _get_lighting_manager()
	if manager == null:
		return
	manager.unregister_zone(self)

func _get_lighting_manager() -> I_CHARACTER_LIGHTING_MANAGER:
	if _cached_lighting_manager != null and is_instance_valid(_cached_lighting_manager):
		return _cached_lighting_manager
	_cached_lighting_manager = U_SERVICE_LOCATOR.try_get_service(LIGHTING_SERVICE) as I_CHARACTER_LIGHTING_MANAGER
	return _cached_lighting_manager
