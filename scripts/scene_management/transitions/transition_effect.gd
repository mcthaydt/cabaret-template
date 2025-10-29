extends RefCounted
class_name TransitionEffect

## Base class for scene transition effects
##
## Defines the interface for all transition effects.
## Subclasses implement execute() to perform the actual transition.

## Execute the transition effect
##
## @param overlay: CanvasLayer containing TransitionColorRect
## @param callback: Callable to invoke when transition completes
func execute(_overlay: CanvasLayer, _callback: Callable) -> void:
	# Virtual method - override in subclasses
	push_error("TransitionEffect.execute() must be overridden in subclass")
	if _callback != null and _callback.is_valid():
		_callback.call()

## Get the duration of this transition in seconds
##
## @return float: Duration in seconds
func get_duration() -> float:
	# Virtual method - override in subclasses
	return 0.0
