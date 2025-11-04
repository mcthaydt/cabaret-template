extends "res://scripts/scene_management/transitions/base_transition_effect.gd"
class_name InstantTransition

## Instant transition effect - completes immediately
##
## Used for instant scene changes with no visual transition.

## Execute instant transition
##
## Calls the completion callback immediately (synchronous).
func execute(_overlay: CanvasLayer, callback: Callable) -> void:
	# Call callback immediately for instant scene swap
	if callback != Callable():
		callback.call()

## Get duration (always 0.0 for instant transitions)
func get_duration() -> float:
	return 0.0
