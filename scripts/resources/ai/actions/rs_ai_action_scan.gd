@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionScan

@export var scan_duration: float = 2.0
@export var rotation_speed: float = 1.0

func start(_context: Dictionary, task_state: Dictionary) -> void:
	task_state["scan_elapsed"] = 0.0
	task_state["scan_active"] = true
	task_state["scan_rotation_speed"] = rotation_speed

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = 0.0
	var elapsed_variant: Variant = task_state.get("scan_elapsed", 0.0)
	if elapsed_variant is float or elapsed_variant is int:
		elapsed = float(elapsed_variant)
	task_state["scan_elapsed"] = elapsed + maxf(delta, 0.0)

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	var elapsed: float = 0.0
	var elapsed_variant: Variant = task_state.get("scan_elapsed", 0.0)
	if elapsed_variant is float or elapsed_variant is int:
		elapsed = float(elapsed_variant)
	var complete: bool = elapsed >= maxf(scan_duration, 0.0)
	if complete:
		task_state["scan_active"] = false
	return complete
