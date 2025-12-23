extends RefCounted
class_name U_SaveActions

## Action creators for save system + UI flows.
##
## UI should dispatch these actions; managers (M_SaveManager) listen and execute
## side-effects.

const ACTION_REFRESH_SLOTS := StringName("save/refresh_slots")
const ACTION_SET_AVAILABLE_SLOTS := StringName("save/set_available_slots")
const ACTION_SET_SELECTED_SLOT := StringName("save/set_selected_slot")
const ACTION_SET_SLOT_SELECTOR_MODE := StringName("save/set_slot_selector_mode")

const ACTION_SAVE_TO_SLOT := StringName("save/save_to_slot")
const ACTION_LOAD_FROM_SLOT := StringName("save/load_from_slot")
const ACTION_DELETE_SLOT := StringName("save/delete_slot")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_REFRESH_SLOTS)
	U_ActionRegistry.register_action(ACTION_SET_AVAILABLE_SLOTS)
	U_ActionRegistry.register_action(ACTION_SET_SELECTED_SLOT)
	U_ActionRegistry.register_action(ACTION_SET_SLOT_SELECTOR_MODE)
	U_ActionRegistry.register_action(ACTION_SAVE_TO_SLOT)
	U_ActionRegistry.register_action(ACTION_LOAD_FROM_SLOT)
	U_ActionRegistry.register_action(ACTION_DELETE_SLOT)

static func refresh_slots() -> Dictionary:
	return {
		"type": ACTION_REFRESH_SLOTS,
		"payload": null
	}

static func set_available_slots(slots: Array) -> Dictionary:
	return {
		"type": ACTION_SET_AVAILABLE_SLOTS,
		"payload": {
			"slots": slots.duplicate(true)
		}
	}

static func set_selected_slot(slot_id: int) -> Dictionary:
	return {
		"type": ACTION_SET_SELECTED_SLOT,
		"payload": {
			"slot_id": slot_id
		}
	}

static func set_slot_selector_mode(mode: int) -> Dictionary:
	return {
		"type": ACTION_SET_SLOT_SELECTOR_MODE,
		"payload": {
			"mode": mode
		}
	}

static func save_to_slot(slot_id: int) -> Dictionary:
	return {
		"type": ACTION_SAVE_TO_SLOT,
		"payload": {
			"slot_id": slot_id
		}
	}

static func load_from_slot(slot_id: int) -> Dictionary:
	return {
		"type": ACTION_LOAD_FROM_SLOT,
		"payload": {
			"slot_id": slot_id
		}
	}

static func delete_slot(slot_id: int) -> Dictionary:
	return {
		"type": ACTION_DELETE_SLOT,
		"payload": {
			"slot_id": slot_id
		}
	}
