extends RefCounted
class_name U_ObjectivesSelectors

## Selectors for objectives slice.

const STATUS_INACTIVE := "inactive"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"

static func get_objective_status(state: Dictionary, objective_id: StringName) -> String:
	if objective_id == StringName(""):
		return STATUS_INACTIVE
	var slice: Dictionary = _get_slice(state)
	var statuses_variant: Variant = slice.get("statuses", {})
	if statuses_variant is Dictionary:
		var statuses := statuses_variant as Dictionary
		var status_variant: Variant = statuses.get(objective_id, STATUS_INACTIVE)
		return str(status_variant)
	return STATUS_INACTIVE

static func get_active_objectives(state: Dictionary) -> Array[StringName]:
	var active_ids: Array[StringName] = []
	var slice: Dictionary = _get_slice(state)
	var statuses_variant: Variant = slice.get("statuses", {})
	if not (statuses_variant is Dictionary):
		return active_ids

	var statuses := statuses_variant as Dictionary
	for key_variant in statuses.keys():
		var status: String = str(statuses.get(key_variant, STATUS_INACTIVE))
		if status == STATUS_ACTIVE:
			var objective_id: StringName = key_variant
			active_ids.append(objective_id)
	return active_ids

static func is_completed(state: Dictionary, objective_id: StringName) -> bool:
	return get_objective_status(state, objective_id) == STATUS_COMPLETED

static func get_event_log(state: Dictionary) -> Array[Dictionary]:
	var slice: Dictionary = _get_slice(state)
	var log_variant: Variant = slice.get("event_log", [])
	if log_variant is Array:
		var log_array: Array = (log_variant as Array).duplicate(true)
		var typed_log: Array[Dictionary] = []
		for entry_variant in log_array:
			if entry_variant is Dictionary:
				typed_log.append((entry_variant as Dictionary).duplicate(true))
		return typed_log
	return []

static func get_active_set_id(state: Dictionary) -> StringName:
	var slice: Dictionary = _get_slice(state)
	return slice.get("active_set_id", StringName(""))

static func get_active_set_ids(state: Dictionary) -> Array[StringName]:
	var slice: Dictionary = _get_slice(state)
	var ids_variant: Variant = slice.get("active_set_ids", [])
	if ids_variant is Array:
		var result: Array[StringName] = []
		for entry in ids_variant:
			if entry is StringName:
				result.append(entry)
		return result
	return []

static func get_statuses_snapshot(state: Dictionary) -> Dictionary:
	var slice: Dictionary = _get_slice(state)
	var statuses_variant: Variant = slice.get("statuses", {})
	if statuses_variant is Dictionary:
		return (statuses_variant as Dictionary).duplicate(true)
	return {}

static func _get_slice(state: Dictionary) -> Dictionary:
	var objectives_variant: Variant = state.get("objectives", null)
	if objectives_variant is Dictionary:
		return objectives_variant as Dictionary
	return state

