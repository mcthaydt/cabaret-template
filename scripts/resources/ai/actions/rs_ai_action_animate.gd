@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionAnimate

@export var animation_state: StringName

func start(_context: Dictionary, task_state: Dictionary) -> void:
	task_state["animation_state"] = animation_state
	task_state["animation_requested"] = true

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get("animation_requested", false))
