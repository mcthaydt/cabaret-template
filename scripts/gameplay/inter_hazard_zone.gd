extends "res://scripts/gameplay/base_volume_controller.gd"
class_name Inter_HazardZone

const RS_HAZARD_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_hazard_interaction_config.gd")
const U_INTERACTION_CONFIG_RESOLVER := preload("res://scripts/gameplay/helpers/u_interaction_config_resolver.gd")

@export var component_name: StringName = StringName("C_DamageZoneComponent")

var component_factory: Callable

var _config: Resource = null
@export var config: Resource:
	get:
		return _config
	set(value):
		if value != null and not U_INTERACTION_CONFIG_RESOLVER.script_matches(value, RS_HAZARD_INTERACTION_CONFIG):
			return
		_config = value
		_apply_config_resource()
		_apply_component_config()

var _component: C_DamageZoneComponent = null

func _ready() -> void:
	_apply_config_resource()
	super._ready()
	trigger_area_ready.connect(_on_controller_area_ready)
	var area := get_trigger_area()
	if area != null:
		_on_controller_area_ready(area)

func _on_controller_area_ready(area: Area3D) -> void:
	if area == null:
		return
	_ensure_component(area)
	_apply_component_config()

func _ensure_component(area: Area3D) -> void:
	if _component != null and is_instance_valid(_component):
		return

	var instance := _instantiate_component()
	if instance == null:
		push_error("Inter_HazardZone: Unable to instantiate C_DamageZoneComponent.")
		return

	instance.name = _resolve_component_name()
	var provisional_path := _build_provisional_area_path(area)
	if not provisional_path.is_empty():
		instance.area_path = provisional_path

	add_child(instance)
	_component = instance
	_update_component_area_path()

func _instantiate_component() -> C_DamageZoneComponent:
	if component_factory != null and component_factory.is_valid():
		var created: Variant = component_factory.call()
		if created is C_DamageZoneComponent:
			return created as C_DamageZoneComponent
		push_warning("Inter_HazardZone: component_factory returned incompatible instance.")
	return C_DamageZoneComponent.new()

func _resolve_component_name() -> String:
	if String(component_name).is_empty():
		return "C_DamageZoneComponent"
	return String(component_name)

func _build_provisional_area_path(area: Area3D) -> NodePath:
	if area == null:
		return NodePath("")
	return NodePath("../%s" % String(area.name))

func _update_component_area_path() -> void:
	if _component == null or not is_instance_valid(_component):
		return
	var area := get_trigger_area()
	if area == null:
		return
	var path := _component.get_path_to(area)
	if path.is_empty():
		return
	_component.area_path = path
	if _component.has_method("set_area_path"):
		_component.set_area_path(path)

func _apply_component_config() -> void:
	if _component == null or not is_instance_valid(_component):
		return
	var typed := _resolve_config()
	if typed == null:
		return

	_component.damage_amount = typed.damage_amount
	_component.is_instant_death = typed.is_instant_death
	_component.damage_cooldown = max(typed.damage_cooldown, 0.0)

	if typed.trigger_settings != null:
		typed.trigger_settings.ignore_initial_overlap = false
		var mask := int(typed.trigger_settings.player_mask)
		if mask <= 0:
			mask = 1
		_component.collision_layer_mask = mask

	_update_component_area_path()

func refresh_volume_from_settings() -> void:
	super.refresh_volume_from_settings()
	_apply_component_config()

func _apply_config_resource() -> void:
	var typed := _resolve_config()
	if typed == null:
		return

	var trigger_settings: RS_SceneTriggerSettings = typed.get("trigger_settings") as RS_SceneTriggerSettings
	if trigger_settings != null:
		settings = trigger_settings

func _resolve_config() -> RS_HazardInteractionConfig:
	if _config != null and U_INTERACTION_CONFIG_RESOLVER.script_matches(_config, RS_HAZARD_INTERACTION_CONFIG):
		return _config as RS_HazardInteractionConfig
	return null
