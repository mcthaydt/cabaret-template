extends RefCounted
class_name U_SceneSelectors

## Scene state selectors
##
## Provides derived answers for transitions and scene stack state.
## All methods accept full state; slice extraction is handled internally.

## Check if scene is currently transitioning
static func is_transitioning(state: Dictionary) -> bool:
	return bool(_get_scene_slice(state).get("is_transitioning", false))

## Get current scene stack
static func get_scene_stack(state: Dictionary) -> Array:
	var stack: Variant = _get_scene_slice(state).get("scene_stack", [])
	if stack is Array:
		return (stack as Array).duplicate(true)
	return []

## Get the current scene ID
static func get_current_scene_id(state: Dictionary) -> StringName:
	return _get_scene_slice(state).get("current_scene_id", StringName(""))

## Get the previous scene ID (scene we transitioned from)
static func get_previous_scene_id(state: Dictionary) -> StringName:
	return _get_scene_slice(state).get("previous_scene_id", StringName(""))

## Get the transition type (e.g. "fade", "instant", "loading")
static func get_transition_type(state: Dictionary) -> String:
	return str(_get_scene_slice(state).get("transition_type", ""))

## Private: extract scene slice from full state
static func _get_scene_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var scene: Variant = state.get("scene", {})
	if scene is Dictionary:
		return scene as Dictionary
	return {}