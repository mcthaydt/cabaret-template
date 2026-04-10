@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_AIBrainComponent

const COMPONENT_TYPE := StringName("C_AIBrainComponent")
@export var brain_settings: RS_AIBrainSettings = null

var _current_task_queue: Array[RS_AIPrimitiveTask] = []

var active_goal_id: StringName = StringName("")
var current_task_queue: Array[RS_AIPrimitiveTask] = []:
	get:
		return _current_task_queue
	set(value):
		_current_task_queue = _coerce_task_queue(value)
var current_task_index: int = 0
var task_state: Dictionary = {}
var evaluation_timer: float = 0.0
var suspended_goal_state: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if brain_settings == null:
		push_error("C_AIBrainComponent missing brain_settings; assign an RS_AIBrainSettings resource.")
		return false
	return true

func get_brain_settings() -> RS_AIBrainSettings:
	return brain_settings

func get_active_goal_id() -> StringName:
	return active_goal_id

func get_current_task() -> RS_AIPrimitiveTask:
	if current_task_index < 0 or current_task_index >= current_task_queue.size():
		return null
	return current_task_queue[current_task_index]

func _coerce_task_queue(value: Variant) -> Array[RS_AIPrimitiveTask]:
	var coerced: Array[RS_AIPrimitiveTask] = []
	if not (value is Array):
		return coerced
	for task_variant in value as Array:
		if task_variant is RS_AIPrimitiveTask:
			coerced.append(task_variant as RS_AIPrimitiveTask)
	return coerced
