extends Resource
class_name I_AIAction

## Base contract for AI action resources.
##
## Implementations should override all virtuals:
## - start(context, task_state)
## - tick(context, task_state, delta)
## - is_complete(context, task_state)

func start(_context: Dictionary, _task_state: Dictionary) -> void:
	pass

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, _task_state: Dictionary) -> bool:
	return false
