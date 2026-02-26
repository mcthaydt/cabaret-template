extends RefCounted
class_name U_SceneDirectorReducer

## Reducer for scene_director slice.

const SCENE_DIRECTOR_ACTIONS := preload("res://scripts/state/actions/u_scene_director_actions.gd")

const STATE_IDLE := "idle"
const STATE_RUNNING := "running"
const STATE_COMPLETED := "completed"

const DEFAULT_STATE := {
	"active_directive_id": StringName(""),
	"current_beat_index": -1,
	"current_beat_id": StringName(""),
	"active_beat_ids": [],
	"parallel_lane_ids": [],
	"state": STATE_IDLE,
}

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName(""))
	var current: Dictionary = _merge_with_defaults(DEFAULT_STATE, state)

	match action_type:
		SCENE_DIRECTOR_ACTIONS.ACTION_START_DIRECTIVE:
			var start_state: Dictionary = current.duplicate(true)
			start_state["active_directive_id"] = action.get("payload", StringName(""))
			start_state["current_beat_index"] = 0
			start_state["current_beat_id"] = StringName("")
			start_state["active_beat_ids"] = []
			start_state["parallel_lane_ids"] = []
			start_state["state"] = STATE_RUNNING
			return start_state

		SCENE_DIRECTOR_ACTIONS.ACTION_ADVANCE_BEAT:
			var next_state: Dictionary = current.duplicate(true)
			var current_index: int = int(next_state.get("current_beat_index", -1))
			next_state["current_beat_index"] = current_index + 1
			return next_state

		SCENE_DIRECTOR_ACTIONS.ACTION_SET_BEAT_INDEX:
			var index_state: Dictionary = current.duplicate(true)
			var index_variant: Variant = action.get("payload", -1)
			if index_variant is int:
				index_state["current_beat_index"] = index_variant
			elif index_variant is float:
				index_state["current_beat_index"] = int(index_variant)
			return index_state

		SCENE_DIRECTOR_ACTIONS.ACTION_SET_CURRENT_BEAT:
			var beat_state: Dictionary = current.duplicate(true)
			var beat_id: StringName = _to_string_name(action.get("payload", StringName("")))
			beat_state["current_beat_id"] = beat_id
			return beat_state

		SCENE_DIRECTOR_ACTIONS.ACTION_SET_ACTIVE_BEATS:
			var active_state: Dictionary = current.duplicate(true)
			active_state["active_beat_ids"] = _to_string_name_array(
				action.get("payload", [])
			)
			return active_state

		SCENE_DIRECTOR_ACTIONS.ACTION_START_PARALLEL:
			var parallel_state: Dictionary = current.duplicate(true)
			parallel_state["parallel_lane_ids"] = _to_string_name_array(
				action.get("payload", [])
			)
			return parallel_state

		SCENE_DIRECTOR_ACTIONS.ACTION_COMPLETE_PARALLEL:
			var complete_parallel_state: Dictionary = current.duplicate(true)
			complete_parallel_state["parallel_lane_ids"] = []
			return complete_parallel_state

		SCENE_DIRECTOR_ACTIONS.ACTION_COMPLETE_DIRECTIVE:
			var complete_state: Dictionary = current.duplicate(true)
			complete_state["state"] = STATE_COMPLETED
			complete_state["active_beat_ids"] = []
			complete_state["parallel_lane_ids"] = []
			return complete_state

		SCENE_DIRECTOR_ACTIONS.ACTION_RESET:
			return DEFAULT_STATE.duplicate(true)

		_:
			return state

static func _merge_with_defaults(defaults: Dictionary, state: Dictionary) -> Dictionary:
	var merged: Dictionary = defaults.duplicate(true)
	if state == null:
		return merged
	for key in state.keys():
		merged[key] = _deep_copy(state[key])
	return merged

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

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
