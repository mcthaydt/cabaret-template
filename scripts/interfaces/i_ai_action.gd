extends Resource
class_name I_AIAction

## Base contract for AI action resources.
##
## Implementations should override all virtuals:
## - start(context, task_state)
## - tick(context, task_state, delta)
## - is_complete(context, task_state)

func start(_context: Dictionary, _task_state: Dictionary) -> void:
	assert(false, "I_AIAction.start must be overridden by subclasses")

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	assert(false, "I_AIAction.tick must be overridden by subclasses")

func is_complete(_context: Dictionary, _task_state: Dictionary) -> bool:
	assert(false, "I_AIAction.is_complete must be overridden by subclasses")
	return false
