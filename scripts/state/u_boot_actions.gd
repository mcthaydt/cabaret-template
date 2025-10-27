extends RefCounted
class_name U_BootActions

## Action creators for boot state slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_UPDATE_LOADING_PROGRESS := StringName("boot/update_loading_progress")
const ACTION_BOOT_ERROR := StringName("boot/error")
const ACTION_BOOT_COMPLETE := StringName("boot/complete")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	ActionRegistry.register_action(ACTION_UPDATE_LOADING_PROGRESS)
	ActionRegistry.register_action(ACTION_BOOT_ERROR)
	ActionRegistry.register_action(ACTION_BOOT_COMPLETE)

## Update loading progress (0.0 to 1.0)
static func update_loading_progress(progress: float) -> Dictionary:
	return {
		"type": ACTION_UPDATE_LOADING_PROGRESS,
		"payload": {"progress": progress}
	}

## Set boot error state with message
static func boot_error(error: String) -> Dictionary:
	return {
		"type": ACTION_BOOT_ERROR,
		"payload": {"error": error}
	}

## Mark boot sequence as complete
static func boot_complete() -> Dictionary:
	return {
		"type": ACTION_BOOT_COMPLETE,
		"payload": null
	}
