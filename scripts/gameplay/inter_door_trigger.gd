extends "res://scripts/gameplay/triggered_interactable_controller.gd"
class_name Inter_DoorTrigger

const RS_DOOR_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_door_interaction_config.gd")
const U_INTERACTION_CONFIG_RESOLVER := preload("res://scripts/gameplay/helpers/u_interaction_config_resolver.gd")

## Door trigger authored as a single E_* entity.
## Relies on TriggeredInteractableController for player detection
## and delegates transition logic to C_SceneTriggerComponent.


@export var component_name: StringName = StringName("C_SceneTriggerComponent")

var component_factory: Callable

var _config: Resource = null
@export var config: Resource:
	get:
		return _config
	set(value):
		if value != null and not U_INTERACTION_CONFIG_RESOLVER.script_matches(value, RS_DOOR_INTERACTION_CONFIG):
			return
		_config = value
		_apply_config_resource()
		_apply_component_config()

var _component: C_SceneTriggerComponent = null

func _init() -> void:
	cooldown_duration = 1.0
	interact_prompt = "Enter"

func _ready() -> void:
	_apply_config_resource()
	super._ready()
	trigger_area_ready.connect(_on_controller_area_ready)
	var existing_area := get_trigger_area()
	if existing_area != null:
		_on_controller_area_ready(existing_area)

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
		push_error("Inter_DoorTrigger: Unable to instantiate C_SceneTriggerComponent.")
		return

	instance.name = _resolve_component_name()
	var provisional_path := _build_provisional_area_path(area)
	if not provisional_path.is_empty():
		instance.area_path = provisional_path
	add_child(instance)
	_component = instance
	_update_component_area_path()

func _instantiate_component() -> C_SceneTriggerComponent:
	if component_factory != null and component_factory.is_valid():
		var created: Variant = component_factory.call()
		if created is C_SceneTriggerComponent:
			return created as C_SceneTriggerComponent
		push_warning("Inter_DoorTrigger: component_factory returned incompatible instance.")
	return C_SceneTriggerComponent.new()

func _resolve_component_name() -> String:
	if String(component_name).is_empty():
		return "C_SceneTriggerComponent"
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

	_component.door_id = typed.door_id
	_component.target_scene_id = typed.target_scene_id
	_component.target_spawn_point = typed.target_spawn_point
	_component.cooldown_duration = max(typed.cooldown_duration, 0.0)
	_component.trigger_mode = typed.trigger_mode

	# Keep controller prompt/activation mode aligned with component configuration
	match _component.trigger_mode:
		C_SceneTriggerComponent.TriggerMode.AUTO:
			trigger_mode = TriggeredInteractableController.TriggerMode.AUTO
		C_SceneTriggerComponent.TriggerMode.INTERACT:
			trigger_mode = TriggeredInteractableController.TriggerMode.INTERACT

	_update_component_area_path()
	if _component != null:
		_component._resolve_or_create_trigger_area()

	if typed.trigger_settings != null:
		typed.trigger_settings.ignore_initial_overlap = true
		_component.settings = typed.trigger_settings

func refresh_volume_from_settings() -> void:
	super.refresh_volume_from_settings()
	_apply_component_config()

func _on_activated(player: Node3D) -> void:
	if _component != null and is_instance_valid(_component):
		_component.trigger_interact()
	super._on_activated(player)

func _apply_config_resource() -> void:
	var typed := _resolve_config()
	if typed == null:
		return

	var trigger_settings: RS_SceneTriggerSettings = typed.get("trigger_settings") as RS_SceneTriggerSettings
	if trigger_settings != null:
		settings = trigger_settings

func _resolve_config() -> RS_DoorInteractionConfig:
	if _config != null and U_INTERACTION_CONFIG_RESOLVER.script_matches(_config, RS_DOOR_INTERACTION_CONFIG):
		return _config as RS_DoorInteractionConfig
	return null
