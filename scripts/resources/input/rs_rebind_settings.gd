extends Resource
class_name RS_RebindSettings

## Rebinding rules and validation toggles.

@export var reserved_actions: Array[StringName] = [
	StringName("pause")
]
@export var allow_conflicts: bool = false
@export var require_confirmation: bool = true
@export_range(1, 10) var max_events_per_action: int = 3
@export var warn_on_reserved: bool = true
@export var warning_actions: Array[StringName] = [
	StringName("toggle_debug_overlay")
]

func is_reserved(action: StringName) -> bool:
	return action in reserved_actions

func should_warn(action: StringName) -> bool:
	return action in warning_actions
