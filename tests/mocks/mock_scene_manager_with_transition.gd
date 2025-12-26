extends Node
class_name MockSceneManagerWithTransition

## Mock scene manager for testing load workflow
##
## Provides:
## - is_transitioning() method for rejection tests
## - transition_to_scene() tracking for verification tests

var _is_transitioning: bool = false
var _transition_called: bool = false
var _transition_target: StringName = StringName("")

func is_transitioning() -> bool:
	return _is_transitioning

func transition_to_scene(scene_id: StringName, transition_type: String = "", priority: int = 0) -> void:
	_transition_called = true
	_transition_target = scene_id
