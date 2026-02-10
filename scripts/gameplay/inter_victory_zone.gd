extends "res://scripts/gameplay/base_volume_controller.gd"
class_name Inter_VictoryZone

const RS_VICTORY_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_victory_interaction_config.gd")
const U_INTERACTION_CONFIG_RESOLVER := preload("res://scripts/gameplay/helpers/u_interaction_config_resolver.gd")

@export var component_name: StringName = StringName("C_VictoryTriggerComponent")

var component_factory: Callable

var _config: Resource = null
@export var config: Resource:
	get:
		return _config
	set(value):
		_config = value
		_apply_config_resource()
		_apply_component_config()

var _objective_id: StringName = StringName("")
@export var objective_id: StringName:
	get:
		return _objective_id
	set(value):
		_objective_id = value
		_apply_component_config()

var _area_id: String = ""
@export var area_id: String:
	get:
		return _area_id
	set(value):
		_area_id = value
		_apply_component_config()

var _victory_type: C_VictoryTriggerComponent.VictoryType = C_VictoryTriggerComponent.VictoryType.LEVEL_COMPLETE
@export var victory_type: C_VictoryTriggerComponent.VictoryType:
	get:
		return _victory_type
	set(value):
		_victory_type = value
		_apply_component_config()

var _trigger_once: bool = true
@export var trigger_once: bool:
	get:
		return _trigger_once
	set(value):
		_trigger_once = value
		_apply_component_config()

var _component: C_VictoryTriggerComponent = null

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
		push_error("Inter_VictoryZone: Unable to instantiate C_VictoryTriggerComponent.")
		return

	instance.name = _resolve_component_name()
	var provisional_path := _build_provisional_area_path(area)
	if not provisional_path.is_empty():
		instance.area_path = provisional_path

	add_child(instance)
	_component = instance
	_update_component_area_path()
	_component._resolve_area()

func _instantiate_component() -> C_VictoryTriggerComponent:
	if component_factory != null and component_factory.is_valid():
		var created: Variant = component_factory.call()
		if created is C_VictoryTriggerComponent:
			return created as C_VictoryTriggerComponent
		push_warning("Inter_VictoryZone: component_factory returned incompatible instance.")
	return C_VictoryTriggerComponent.new()

func _resolve_component_name() -> String:
	if String(component_name).is_empty():
		return "C_VictoryTriggerComponent"
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

func _apply_component_config() -> void:
	if _component == null or not is_instance_valid(_component):
		return

	_component.objective_id = _get_effective_objective_id()
	_component.area_id = _get_effective_area_id()
	_component.victory_type = _get_effective_victory_type()
	_component.trigger_once = _get_effective_trigger_once()
	var trigger_settings := _get_effective_trigger_settings()
	if trigger_settings != null:
		trigger_settings.ignore_initial_overlap = false

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

func _resolve_config() -> Resource:
	if _config == null:
		return null
	if U_INTERACTION_CONFIG_RESOLVER.script_matches(_config, RS_VICTORY_INTERACTION_CONFIG):
		return _config
	return null

func _get_effective_objective_id() -> StringName:
	var typed := _resolve_config()
	if typed != null:
		return U_INTERACTION_CONFIG_RESOLVER.as_string_name(typed.get("objective_id"), _objective_id)
	return _objective_id

func _get_effective_area_id() -> String:
	var typed := _resolve_config()
	if typed != null:
		return U_INTERACTION_CONFIG_RESOLVER.as_string(typed.get("area_id"), _area_id)
	return _area_id

func _get_effective_victory_type() -> int:
	var typed := _resolve_config()
	if typed != null:
		return U_INTERACTION_CONFIG_RESOLVER.as_int(typed.get("victory_type"), _victory_type)
	return _victory_type

func _get_effective_trigger_once() -> bool:
	var typed := _resolve_config()
	if typed != null:
		return U_INTERACTION_CONFIG_RESOLVER.as_bool(typed.get("trigger_once"), _trigger_once)
	return _trigger_once

func _get_effective_trigger_settings() -> RS_SceneTriggerSettings:
	var typed := _resolve_config()
	if typed != null:
		var trigger_settings := typed.get("trigger_settings") as RS_SceneTriggerSettings
		if trigger_settings != null:
			return trigger_settings
	return _get_settings()
