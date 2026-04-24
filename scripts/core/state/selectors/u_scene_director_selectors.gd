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

static func get_current_beat_id(state: Dictionary) -> StringName:
	var slice: Dictionary = _get_slice(state)
	return _to_string_name(slice.get("current_beat_id", StringName("")))

static func get_active_beat_ids(state: Dictionary) -> Array[StringName]:
	var slice: Dictionary = _get_slice(state)
	return _to_string_name_array(slice.get("active_beat_ids", []))

static func get_parallel_lane_ids(state: Dictionary) -> Array[StringName]:
	var slice: Dictionary = _get_slice(state)
	return _to_string_name_array(slice.get("parallel_lane_ids", []))

static func is_parallel(state: Dictionary) -> bool:
	return not get_parallel_lane_ids(state).is_empty()

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

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")

static func _to_string_name_array(value: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	if value is Array:
		for entry in value:
			var name: StringName = _to_string_name(entry)
			if name == StringName(""):
				continue
			names.append(name)
	elif value is PackedStringArray:
		for entry in value:
			var name: StringName = _to_string_name(entry)
			if name == StringName(""):
				continue
			names.append(name)
	return names
