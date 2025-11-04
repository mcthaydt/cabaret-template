extends "res://scripts/ecs/ecs_entity.gd"

## Door Trigger Controller (E_FinalGoal-style)
##
## Ensures a C_SceneTriggerComponent exists under this entity and configures it
## from the entity's exported fields. Lets you author a single E_* node without
## nested component/Area3D children.

const C_SceneTriggerComponent := preload("res://scripts/ecs/components/c_scene_trigger_component.gd")
const RS_SceneTriggerSettings := preload("res://scripts/ecs/resources/rs_scene_trigger_settings.gd")

@export var door_id: StringName = StringName("")
@export var target_scene_id: StringName = StringName("")
@export var target_spawn_point: StringName = StringName("")
@export var cooldown_duration: float = 1.0
@export var trigger_mode: int = C_SceneTriggerComponent.TriggerMode.AUTO
@export var component_name: StringName = StringName("C_SceneTriggerComponent")
@export var settings: RS_SceneTriggerSettings

var _component: C_SceneTriggerComponent = null

func _ready() -> void:
	await get_tree().process_frame
	_ensure_component()
	_apply_config()

func _ensure_component() -> void:
	# Try by name first
	if not String(component_name).is_empty():
		var existing: Node = get_node_or_null(NodePath(String(component_name)))
		if existing is C_SceneTriggerComponent:
			_component = existing as C_SceneTriggerComponent
	# Search any child
	if _component == null:
		for child in get_children():
			if child is C_SceneTriggerComponent:
				_component = child as C_SceneTriggerComponent
				break
	# Create if missing
	if _component == null:
		var new_comp := C_SceneTriggerComponent.new()
		new_comp.name = String(component_name) if not String(component_name).is_empty() else "C_SceneTriggerComponent"
		add_child(new_comp)
		_component = new_comp

func _apply_config() -> void:
	if _component == null:
		return
	_component.door_id = door_id
	_component.target_scene_id = target_scene_id
	_component.target_spawn_point = target_spawn_point
	_component.cooldown_duration = cooldown_duration
	_component.trigger_mode = trigger_mode
	if settings != null:
		_component.settings = settings

func get_trigger_area() -> Area3D:
	if _component != null:
		return _component._trigger_area
	return null

func set_enabled(enabled: bool) -> void:
	var area := get_trigger_area()
	if area != null:
		area.monitoring = enabled
		area.monitorable = enabled

