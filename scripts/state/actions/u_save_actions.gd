extends RefCounted
class_name U_SaveActions

## Action creators for save state slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_SAVE_STARTED := StringName("save/save_started")
const ACTION_SAVE_COMPLETED := StringName("save/save_completed")
const ACTION_SAVE_FAILED := StringName("save/save_failed")
const ACTION_LOAD_STARTED := StringName("save/load_started")
const ACTION_LOAD_COMPLETED := StringName("save/load_completed")
const ACTION_LOAD_FAILED := StringName("save/load_failed")
const ACTION_DELETE_STARTED := StringName("save/delete_started")
const ACTION_DELETE_COMPLETED := StringName("save/delete_completed")
const ACTION_DELETE_FAILED := StringName("save/delete_failed")
const ACTION_SET_SAVE_MODE := StringName("save/set_save_mode")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SAVE_STARTED)
	U_ActionRegistry.register_action(ACTION_SAVE_COMPLETED)
	U_ActionRegistry.register_action(ACTION_SAVE_FAILED)
	U_ActionRegistry.register_action(ACTION_LOAD_STARTED)
	U_ActionRegistry.register_action(ACTION_LOAD_COMPLETED)
	U_ActionRegistry.register_action(ACTION_LOAD_FAILED)
	U_ActionRegistry.register_action(ACTION_DELETE_STARTED)
	U_ActionRegistry.register_action(ACTION_DELETE_COMPLETED)
	U_ActionRegistry.register_action(ACTION_DELETE_FAILED)
	U_ActionRegistry.register_action(ACTION_SET_SAVE_MODE)

## Create a save started action
static func save_started(slot_index: int) -> Dictionary:
	return {
		"type": ACTION_SAVE_STARTED,
		"slot_index": slot_index
	}

## Create a save completed action
static func save_completed(slot_index: int) -> Dictionary:
	return {
		"type": ACTION_SAVE_COMPLETED,
		"slot_index": slot_index
	}

## Create a save failed action
static func save_failed(slot_index: int, error: String) -> Dictionary:
	return {
		"type": ACTION_SAVE_FAILED,
		"slot_index": slot_index,
		"error": error
	}

## Create a load started action
static func load_started(slot_index: int) -> Dictionary:
	return {
		"type": ACTION_LOAD_STARTED,
		"slot_index": slot_index
	}

## Create a load completed action
static func load_completed(slot_index: int) -> Dictionary:
	return {
		"type": ACTION_LOAD_COMPLETED,
		"slot_index": slot_index
	}

## Create a load failed action
static func load_failed(slot_index: int, error: String) -> Dictionary:
	return {
		"type": ACTION_LOAD_FAILED,
		"slot_index": slot_index,
		"error": error
	}

## Create a delete started action
static func delete_started(slot_index: int) -> Dictionary:
	return {
		"type": ACTION_DELETE_STARTED,
		"slot_index": slot_index
	}

## Create a delete completed action
static func delete_completed(slot_index: int) -> Dictionary:
	return {
		"type": ACTION_DELETE_COMPLETED,
		"slot_index": slot_index
	}

## Create a delete failed action
static func delete_failed(slot_index: int, error: String) -> Dictionary:
	return {
		"type": ACTION_DELETE_FAILED,
		"slot_index": slot_index,
		"error": error
	}

## Create a set save mode action
static func set_save_mode(mode: int) -> Dictionary:
	return {
		"type": ACTION_SET_SAVE_MODE,
		"mode": mode
	}
