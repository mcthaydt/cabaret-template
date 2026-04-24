extends RefCounted
class_name U_TransitionState

## Mutable transition state container shared by scene transition callbacks.
##
## Replaces Array-wrapper mutable captures in M_SceneManager transition paths.
## Closures can safely mutate this object by reference.

var progress: float = 0.0
var scene_swap_complete: bool = false
var new_scene_ref: Node = null
var old_camera_state: Variant = null
var should_blend: bool = false


func reset() -> void:
	progress = 0.0
	scene_swap_complete = false
	new_scene_ref = null
	old_camera_state = null
	should_blend = false
