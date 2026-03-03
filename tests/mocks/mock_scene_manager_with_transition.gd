extends "res://scripts/interfaces/i_scene_manager.gd"
class_name MockSceneManagerWithTransition

## Mock scene manager for testing load workflow
##
## Provides:
## - is_transitioning() method for rejection tests
## - transition_to_scene() tracking for verification tests
## - Minimal implementations of I_SceneManager interface methods

var _is_transitioning: bool = false
var _transition_called: bool = false
var _transition_target: StringName = StringName("")
var _transition_type: String = ""

func is_transitioning() -> bool:
	return _is_transitioning

func transition_to_scene(scene_id: StringName, transition_type: String = "", _priority: int = 0) -> void:
	_transition_called = true
	_transition_target = scene_id
	_transition_type = transition_type

func hint_preload_scene(_scene_path: String) -> void:
	pass

func suppress_pause_for_current_frame() -> void:
	pass

func push_overlay(_scene_id: StringName, _force: bool = false) -> void:
	pass

func pop_overlay() -> void:
	pass
