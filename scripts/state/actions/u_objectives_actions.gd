extends RefCounted
class_name U_ObjectivesActions

## Action creators for objectives slice.

const ACTION_ACTIVATE := StringName("objectives/activate")
const ACTION_COMPLETE := StringName("objectives/complete")
const ACTION_FAIL := StringName("objectives/fail")
const ACTION_SET_ACTIVE_SET := StringName("objectives/set_active_set")
const ACTION_LOG_EVENT := StringName("objectives/log_event")
const ACTION_RESET_ALL := StringName("objectives/reset_all")
const ACTION_BULK_ACTIVATE := StringName("objectives/bulk_activate")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_ACTIVATE)
	U_ActionRegistry.register_action(ACTION_COMPLETE)
	U_ActionRegistry.register_action(ACTION_FAIL)
	U_ActionRegistry.register_action(ACTION_SET_ACTIVE_SET)
	U_ActionRegistry.register_action(ACTION_LOG_EVENT)
	U_ActionRegistry.register_action(ACTION_RESET_ALL)
	U_ActionRegistry.register_action(ACTION_BULK_ACTIVATE)

static func activate(objective_id: StringName) -> Dictionary:
	return {
		"type": ACTION_ACTIVATE,
		"payload": objective_id
	}

static func complete(objective_id: StringName) -> Dictionary:
	return {
		"type": ACTION_COMPLETE,
		"payload": objective_id
	}

static func fail(objective_id: StringName) -> Dictionary:
	return {
		"type": ACTION_FAIL,
		"payload": objective_id
	}

static func set_active_set(set_id: StringName) -> Dictionary:
	return {
		"type": ACTION_SET_ACTIVE_SET,
		"payload": set_id
	}

static func log_event(event_data: Dictionary) -> Dictionary:
	return {
		"type": ACTION_LOG_EVENT,
		"payload": event_data.duplicate(true)
	}

static func reset_all() -> Dictionary:
	return {
		"type": ACTION_RESET_ALL,
		"payload": null
	}

static func bulk_activate(objective_ids: Array[StringName]) -> Dictionary:
	return {
		"type": ACTION_BULK_ACTIVATE,
		"payload": objective_ids.duplicate(true)
	}

