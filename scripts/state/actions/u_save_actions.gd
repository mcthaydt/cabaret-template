extends RefCounted
class_name U_SaveActions

## Action creators for save lifecycle notifications
##
## Replaces ECS event bus publishes from M_SaveManager per channel taxonomy
## (docs/adr/0001-channel-taxonomy.md). Managers dispatch to Redux only;
## subscribers connect to M_StateStore.action_dispatched and filter by type.

const ACTION_SAVE_STARTED := StringName("save/started")
const ACTION_SAVE_COMPLETED := StringName("save/completed")
const ACTION_SAVE_FAILED := StringName("save/failed")
const ACTION_LOAD_STARTED := StringName("save/load_started")
const ACTION_LOAD_COMPLETED := StringName("save/load_completed")
const ACTION_LOAD_FAILED := StringName("save/load_failed")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SAVE_STARTED)
	U_ActionRegistry.register_action(ACTION_SAVE_COMPLETED)
	U_ActionRegistry.register_action(ACTION_SAVE_FAILED)
	U_ActionRegistry.register_action(ACTION_LOAD_STARTED)
	U_ActionRegistry.register_action(ACTION_LOAD_COMPLETED)
	U_ActionRegistry.register_action(ACTION_LOAD_FAILED)

static func save_started(slot_id: StringName, is_autosave: bool) -> Dictionary:
	return {
		"type": ACTION_SAVE_STARTED,
		"slot_id": slot_id,
		"is_autosave": is_autosave,
	}

static func save_completed(slot_id: StringName, is_autosave: bool) -> Dictionary:
	return {
		"type": ACTION_SAVE_COMPLETED,
		"slot_id": slot_id,
		"is_autosave": is_autosave,
	}

static func save_failed(slot_id: StringName, is_autosave: bool, error_code: int) -> Dictionary:
	return {
		"type": ACTION_SAVE_FAILED,
		"slot_id": slot_id,
		"is_autosave": is_autosave,
		"error_code": error_code,
	}

static func load_started(slot_id: StringName) -> Dictionary:
	return {
		"type": ACTION_LOAD_STARTED,
		"slot_id": slot_id,
	}

static func load_completed(slot_id: StringName) -> Dictionary:
	return {
		"type": ACTION_LOAD_COMPLETED,
		"slot_id": slot_id,
	}

static func load_failed(slot_id: StringName, error_code: int) -> Dictionary:
	return {
		"type": ACTION_LOAD_FAILED,
		"slot_id": slot_id,
		"error_code": error_code,
	}