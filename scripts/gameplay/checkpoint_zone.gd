extends "res://scripts/ecs/ecs_entity.gd"

## Checkpoint Zone Controller (entity-level, E_FinalGoal-style)
##
## Ensures a C_CheckpointComponent exists under this entity and configures it
## from the entity's exported fields. Allows authoring a single entity node
## without nested component setup.

const C_CheckpointComponent := preload("res://scripts/ecs/components/c_checkpoint_component.gd")
const RS_SceneTriggerSettings := preload("res://scripts/ecs/resources/rs_scene_trigger_settings.gd")

@export var checkpoint_id: StringName = StringName("")
@export var spawn_point_id: StringName = StringName("")
@export var component_name: StringName = StringName("C_CheckpointComponent")
@export_node_path("Area3D") var area_path: NodePath
@export var settings: RS_SceneTriggerSettings

var _component: C_CheckpointComponent = null

func _ready() -> void:
	await get_tree().process_frame
	_ensure_component()
	_apply_config()

func _ensure_component() -> void:
	# Try by name first
	if not String(component_name).is_empty():
		var existing: Node = get_node_or_null(NodePath(String(component_name)))
		if existing is C_CheckpointComponent:
			_component = existing as C_CheckpointComponent
	# Search any child
	if _component == null:
		for child in get_children():
			if child is C_CheckpointComponent:
				_component = child as C_CheckpointComponent
				break
	# Create if missing
	if _component == null:
		var new_comp := C_CheckpointComponent.new()
		new_comp.name = String(component_name) if not String(component_name).is_empty() else "C_CheckpointComponent"
		add_child(new_comp)
		_component = new_comp

func _apply_config() -> void:
	if _component == null:
		return
	_component.checkpoint_id = checkpoint_id
	_component.spawn_point_id = spawn_point_id
	if settings != null:
		_component.settings = settings
	if not area_path.is_empty():
		_component.area_path = area_path

func get_trigger_area() -> Area3D:
	if _component != null:
		return _component.get_trigger_area()
	return null

func set_enabled(enabled: bool) -> void:
	if _component != null:
		_component.set_enabled(enabled)
