extends Resource
class_name I_AIAction

## Interface for AI action resources.
##
## Implementations:
## - RS_AIAction* resources in scripts/resources/ai/actions/

func start(_context: Dictionary, _task_state: Dictionary) -> void:
	push_error("I_AIAction.start not implemented")

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	push_error("I_AIAction.tick not implemented")

func is_complete(_context: Dictionary, _task_state: Dictionary) -> bool:
	push_error("I_AIAction.is_complete not implemented")
	return false
