extends RefCounted
class_name U_SceneDirectorSelectors

## Selectors for scene_director slice.

const STATE_IDLE := "idle"
const STATE_RUNNING := "running"

static func get_active_directive_id(state: Dictionary) -> StringName:
	var slice: Dictionary = _get_slice(state)
	return slice.get("active_directive_id", StringName(""))

static func get_current_beat_index(state: Dictionary) -> int:
	var slice: Dictionary = _get_slice(state)
	return int(slice.get("current_beat_index", -1))

static func is_running(state: Dictionary) -> bool:
	return get_director_state(state) == STATE_RUNNING

static func get_director_state(state: Dictionary) -> String:
	var slice: Dictionary = _get_slice(state)
	return str(slice.get("state", STATE_IDLE))

static func _get_slice(state: Dictionary) -> Dictionary:
	var director_variant: Variant = state.get("scene_director", null)
	if director_variant is Dictionary:
		return director_variant as Dictionary
	return state

