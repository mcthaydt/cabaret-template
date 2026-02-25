extends RefCounted
class_name U_ObjectivesReducer

## Reducer for objectives slice.

const OBJECTIVES_ACTIONS := preload("res://scripts/state/actions/u_objectives_actions.gd")

const STATUS_INACTIVE := "inactive"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"

const DEFAULT_STATE := {
	"statuses": {},
	"active_set_id": StringName(""),
	"event_log": [],
}

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName(""))
	var current: Dictionary = _merge_with_defaults(DEFAULT_STATE, state)

	match action_type:
		OBJECTIVES_ACTIONS.ACTION_ACTIVATE:
			return _set_status(current, action.get("payload", StringName("")), STATUS_ACTIVE)

		OBJECTIVES_ACTIONS.ACTION_COMPLETE:
			return _set_status(current, action.get("payload", StringName("")), STATUS_COMPLETED)

		OBJECTIVES_ACTIONS.ACTION_FAIL:
			return _set_status(current, action.get("payload", StringName("")), STATUS_FAILED)

		OBJECTIVES_ACTIONS.ACTION_SET_ACTIVE_SET:
			var next_set_state: Dictionary = current.duplicate(true)
			next_set_state["active_set_id"] = action.get("payload", StringName(""))
			return next_set_state

		OBJECTIVES_ACTIONS.ACTION_LOG_EVENT:
			var next_log_state: Dictionary = current.duplicate(true)
			var next_log: Array = next_log_state.get("event_log", []).duplicate(true)
			var entry_variant: Variant = action.get("payload", {})
			if entry_variant is Dictionary:
				next_log.append((entry_variant as Dictionary).duplicate(true))
			else:
				next_log.append({})
			next_log_state["event_log"] = next_log
			return next_log_state

		OBJECTIVES_ACTIONS.ACTION_RESET_ALL:
			var reset_state: Dictionary = current.duplicate(true)
			reset_state["statuses"] = {}
			return reset_state

		OBJECTIVES_ACTIONS.ACTION_BULK_ACTIVATE:
			var next_bulk_state: Dictionary = current.duplicate(true)
			var statuses: Dictionary = next_bulk_state.get("statuses", {}).duplicate(true)
			var ids_variant: Variant = action.get("payload", [])
			if ids_variant is Array:
				for id_variant in ids_variant:
					var objective_id: StringName = id_variant
					if objective_id != StringName(""):
						statuses[objective_id] = STATUS_ACTIVE
			next_bulk_state["statuses"] = statuses
			return next_bulk_state

		_:
			return state

static func _set_status(state: Dictionary, objective_id: StringName, status: String) -> Dictionary:
	if objective_id == StringName(""):
		return state

	var next_state: Dictionary = state.duplicate(true)
	var statuses: Dictionary = next_state.get("statuses", {}).duplicate(true)
	statuses[objective_id] = status
	next_state["statuses"] = statuses
	return next_state

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
