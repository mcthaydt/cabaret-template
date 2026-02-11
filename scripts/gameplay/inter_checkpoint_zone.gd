extends "res://scripts/gameplay/base_volume_controller.gd"
class_name Inter_CheckpointZone

const RS_CHECKPOINT_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_checkpoint_interaction_config.gd")
const U_INTERACTION_CONFIG_RESOLVER := preload("res://scripts/gameplay/helpers/u_interaction_config_resolver.gd")

@export var component_name: StringName = StringName("C_CheckpointComponent")

var component_factory: Callable

var _config: Resource = null
@export var config: Resource:
	get:
		return _config
	set(value):
		if value != null and not U_INTERACTION_CONFIG_RESOLVER.script_matches(value, RS_CHECKPOINT_INTERACTION_CONFIG):
			return
		_config = value
		_apply_config_resource()
		_apply_component_config()

var _component: C_CheckpointComponent = null

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
		push_error("Inter_CheckpointZone: Unable to instantiate C_CheckpointComponent.")
		return

	instance.name = _resolve_component_name()
	var provisional_path := _build_provisional_area_path(area)
	if not provisional_path.is_empty():
		instance.area_path = provisional_path
	var typed := _resolve_config()
	if typed != null:
		instance.checkpoint_id = typed.checkpoint_id
		instance.spawn_point_id = typed.spawn_point_id
		if typed.trigger_settings != null:
			typed.trigger_settings.ignore_initial_overlap = false
			instance.settings = typed.trigger_settings

	add_child(instance)
	_component = instance
	_update_component_area_path()
	_component._resolve_or_create_area()

func _instantiate_component() -> C_CheckpointComponent:
	if component_factory != null and component_factory.is_valid():
		var created: Variant = component_factory.call()
		if created is C_CheckpointComponent:
			return created as C_CheckpointComponent
		push_warning("Inter_CheckpointZone: component_factory returned incompatible instance.")
	return C_CheckpointComponent.new()

func _resolve_component_name() -> String:
	if String(component_name).is_empty():
		return "C_CheckpointComponent"
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
	var typed := _resolve_config()
	if typed == null:
		return

	_component.checkpoint_id = typed.checkpoint_id
	_component.spawn_point_id = typed.spawn_point_id
	if typed.trigger_settings != null:
		typed.trigger_settings.ignore_initial_overlap = false
		_component.settings = typed.trigger_settings

	_update_component_area_path()
	_component.set_enabled(is_enabled())

func refresh_volume_from_settings() -> void:
	super.refresh_volume_from_settings()
	_apply_component_config()

func _on_enabled_state_changed(enabled: bool) -> void:
	super._on_enabled_state_changed(enabled)
	if _component != null and is_instance_valid(_component):
		_component.set_enabled(enabled)

func _apply_config_resource() -> void:
	var typed := _resolve_config()
	if typed == null:
		return

	var trigger_settings: RS_SceneTriggerSettings = typed.get("trigger_settings") as RS_SceneTriggerSettings
	if trigger_settings != null:
		settings = trigger_settings

func _resolve_config() -> RS_CheckpointInteractionConfig:
	if _config != null and U_INTERACTION_CONFIG_RESOLVER.script_matches(_config, RS_CHECKPOINT_INTERACTION_CONFIG):
		return _config as RS_CheckpointInteractionConfig
	return null
