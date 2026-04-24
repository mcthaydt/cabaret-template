extends RefCounted
class_name U_ObjectivesReducer

## Reducer for objectives slice.

const OBJECTIVES_ACTIONS := preload("res://scripts/core/state/actions/u_objectives_actions.gd")

const STATUS_INACTIVE := "inactive"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"

const DEFAULT_STATE := {
	"statuses": {},
	"active_set_id": StringName(""),
	"active_set_ids": [],
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
			var new_set_id: StringName = action.get("payload", StringName(""))
			next_set_state["active_set_id"] = new_set_id
			var set_ids: Array = next_set_state.get("active_set_ids", []).duplicate(true)
			if new_set_id != StringName("") and not set_ids.has(new_set_id):
				set_ids.append(new_set_id)
			next_set_state["active_set_ids"] = set_ids
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
			reset_state["active_set_ids"] = []
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

		OBJECTIVES_ACTIONS.ACTION_RESET_FOR_NEW_RUN:
			var reset_run_state: Dictionary = current.duplicate(true)
			reset_run_state["statuses"] = {}
			reset_run_state["event_log"] = []
			var payload_variant: Variant = action.get("payload", {})
			var run_set_id: StringName = StringName("")
			if payload_variant is Dictionary:
				var payload := payload_variant as Dictionary
				run_set_id = _to_string_name(payload.get("set_id", StringName("")))
			reset_run_state["active_set_id"] = run_set_id
			if run_set_id != StringName(""):
				reset_run_state["active_set_ids"] = [run_set_id]
			else:
				reset_run_state["active_set_ids"] = []
			return reset_run_state

		OBJECTIVES_ACTIONS.ACTION_ADD_ACTIVE_SET:
			var next_add_state: Dictionary = current.duplicate(true)
			var add_ids: Array = next_add_state.get("active_set_ids", []).duplicate(true)
			var add_set_id: StringName = _to_string_name(action.get("payload", StringName("")))
			if add_set_id != StringName("") and not add_ids.has(add_set_id):
				add_ids.append(add_set_id)
			next_add_state["active_set_ids"] = add_ids
			# Set primary active_set_id if currently empty
			var current_primary: StringName = _to_string_name(next_add_state.get("active_set_id", StringName("")))
			if current_primary == StringName("") and add_set_id != StringName(""):
				next_add_state["active_set_id"] = add_set_id
			return next_add_state

		OBJECTIVES_ACTIONS.ACTION_REMOVE_ACTIVE_SET:
			var next_remove_state: Dictionary = current.duplicate(true)
			var remove_ids: Array = next_remove_state.get("active_set_ids", []).duplicate(true)
			var remove_set_id: StringName = _to_string_name(action.get("payload", StringName("")))
			if remove_ids.has(remove_set_id):
				remove_ids.erase(remove_set_id)
			next_remove_state["active_set_ids"] = remove_ids
			return next_remove_state

		OBJECTIVES_ACTIONS.ACTION_RESET_SET_STATUSES:
			var next_reset_set_state: Dictionary = current.duplicate(true)
			var reset_statuses: Dictionary = next_reset_set_state.get("statuses", {}).duplicate(true)
			var reset_ids_variant: Variant = action.get("payload", [])
			if reset_ids_variant is Array:
				for reset_id_variant in reset_ids_variant:
					reset_statuses.erase(reset_id_variant)
			next_reset_set_state["statuses"] = reset_statuses
			return next_reset_set_state

		OBJECTIVES_ACTIONS.ACTION_RESET_ALL_STATUSES:
			var next_reset_all_state: Dictionary = current.duplicate(true)
			next_reset_all_state["statuses"] = {}
			return next_reset_all_state

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

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")