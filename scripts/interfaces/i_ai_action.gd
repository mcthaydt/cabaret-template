extends Resource
class_name I_AIAction

## Base contract for AI action resources.
##
## Implementations should override all virtuals:
## - start(context, task_state)
## - tick(context, task_state, delta)
## - is_complete(context, task_state)

func start(_context: Dictionary, _task_state: Dictionary) -> void:
	push_error("I_AIAction.start: not implemented by subclass %s" % str(resource_name))

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	push_error("I_AIAction.tick: not implemented by subclass %s" % str(resource_name))

func is_complete(_context: Dictionary, _task_state: Dictionary) -> bool:
	push_error("I_AIAction.is_complete: not implemented by subclass %s" % str(resource_name))
	return false
