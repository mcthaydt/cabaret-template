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
			start_state["state"] = STATE_RUNNING
			return start_state

		SCENE_DIRECTOR_ACTIONS.ACTION_ADVANCE_BEAT:
			var next_state: Dictionary = current.duplicate(true)
			var current_index: int = int(next_state.get("current_beat_index", -1))
			next_state["current_beat_index"] = current_index + 1
			return next_state

		SCENE_DIRECTOR_ACTIONS.ACTION_COMPLETE_DIRECTIVE:
			var complete_state: Dictionary = current.duplicate(true)
			complete_state["state"] = STATE_COMPLETED
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
