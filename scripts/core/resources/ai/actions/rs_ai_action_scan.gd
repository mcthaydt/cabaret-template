@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionScan

@export var scan_duration: float = 2.0
@export var rotation_speed: float = 1.0

func start(context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.SCAN_ELAPSED] = 0.0
	task_state[U_AITaskStateKeys.SCAN_ACTIVE] = true
	task_state[U_AITaskStateKeys.SCAN_ROTATION_SPEED] = rotation_speed
	print("[ACTION] %s Scan started (duration=%.2fs, rotation_speed=%.2f)" % [
		_resolve_entity_label(context),
		maxf(scan_duration, 0.0),
		rotation_speed
	])

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = task_state.get(U_AITaskStateKeys.SCAN_ELAPSED, 0.0)
	task_state[U_AITaskStateKeys.SCAN_ELAPSED] = elapsed + maxf(delta, 0.0)

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	var elapsed: float = task_state.get(U_AITaskStateKeys.SCAN_ELAPSED, 0.0)
	var complete: bool = elapsed >= maxf(scan_duration, 0.0)
	if complete:
		task_state[U_AITaskStateKeys.SCAN_ACTIVE] = false
		print("[ACTION] %s Scan complete after %.2fs" % [_resolve_entity_label(context), elapsed])
	return complete

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
