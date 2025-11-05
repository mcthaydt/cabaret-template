extends "res://scripts/gameplay/triggered_interactable_controller.gd"
class_name E_DoorTriggerController

## Door trigger authored as a single E_* entity.
## Relies on TriggeredInteractableController for player detection
## and delegates transition logic to C_SceneTriggerComponent.

const C_SceneTriggerComponent := preload("res://scripts/ecs/components/c_scene_trigger_component.gd")

@export var component_name: StringName = StringName("C_SceneTriggerComponent")

var component_factory: Callable

var _door_id: StringName = StringName("")
@export var door_id: StringName:
	get:
		return _door_id
	set(value):
		_door_id = value
		_apply_component_config()

var _target_scene_id: StringName = StringName("")
@export var target_scene_id: StringName:
	get:
		return _target_scene_id
	set(value):
		_target_scene_id = value
		_apply_component_config()

var _target_spawn_point: StringName = StringName("")
@export var target_spawn_point: StringName:
	get:
		return _target_spawn_point
	set(value):
		_target_spawn_point = value
		_apply_component_config()

var _component: C_SceneTriggerComponent = null

func _init() -> void:
	cooldown_duration = 1.0
	interact_prompt = "Enter"

func _ready() -> void:
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
		push_error("E_DoorTriggerController: Unable to instantiate C_SceneTriggerComponent.")
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
		var created := component_factory.call()
		if created is C_SceneTriggerComponent:
			return created as C_SceneTriggerComponent
		push_warning("E_DoorTriggerController: component_factory returned incompatible instance.")
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

	_component.door_id = _door_id
	_component.target_scene_id = _target_scene_id
	_component.target_spawn_point = _target_spawn_point
	_component.cooldown_duration = max(cooldown_duration, 0.0)
	_component.trigger_mode = C_SceneTriggerComponent.TriggerMode.INTERACT

	_update_component_area_path()
	if _component != null:
		_component._resolve_or_create_trigger_area()

	if settings != null:
		settings.ignore_initial_overlap = true
		_component.settings = settings

func refresh_volume_from_settings() -> void:
	super.refresh_volume_from_settings()
	_apply_component_config()

func _on_activated(player: Node3D) -> void:
	if _component != null and is_instance_valid(_component):
		_component.trigger_interact()
	super._on_activated(player)
