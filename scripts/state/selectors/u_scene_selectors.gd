extends RefCounted
class_name U_SceneSelectors

## Scene state selectors
##
## Provides derived answers for transitions and scene stack state.

## Check if scene is currently transitioning
static func is_transitioning(scene_slice: Dictionary) -> bool:
	return bool(scene_slice.get("is_transitioning", false))

## Get current scene stack
static func get_scene_stack(scene_slice: Dictionary) -> Array:
	return scene_slice.get("scene_stack", [])
