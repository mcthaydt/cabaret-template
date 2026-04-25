@icon("res://assets/core/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionWait

@export var duration: float = 1.0

func start(context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.ELAPSED] = 0.0
	print("[ACTION] %s Wait started (duration=%.2fs)" % [_resolve_entity_label(context), maxf(duration, 0.0)])

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = task_state.get(U_AITaskStateKeys.ELAPSED, 0.0)
	task_state[U_AITaskStateKeys.ELAPSED] = elapsed + maxf(delta, 0.0)

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	var elapsed: float = task_state.get(U_AITaskStateKeys.ELAPSED, 0.0)
	var complete: bool = elapsed >= maxf(duration, 0.0)
	if complete:
		print("[ACTION] %s Wait complete after %.2fs" % [_resolve_entity_label(context), elapsed])
	return complete

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
