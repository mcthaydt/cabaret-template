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

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SAVE_STARTED)
	U_ActionRegistry.register_action(ACTION_SAVE_COMPLETED)
	U_ActionRegistry.register_action(ACTION_SAVE_FAILED)

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