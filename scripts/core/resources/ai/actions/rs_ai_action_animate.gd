@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionAnimate

## Fire-and-forget action: writes animation state to task_state and completes
## immediately on the same tick. The task runner advances past this action
## without waiting for an animation event — animation playback is initiated
## by the animation-state write, not tracked by this action.

@export var animation_state: StringName

func start(context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.ANIMATION_STATE] = animation_state
	task_state[U_AITaskStateKeys.ANIMATION_REQUESTED] = true
	print("[ACTION] %s Animate → state=%s" % [_resolve_entity_label(context), animation_state])

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AITaskStateKeys.ANIMATION_REQUESTED, false))

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
