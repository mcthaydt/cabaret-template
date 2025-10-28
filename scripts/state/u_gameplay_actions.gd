extends RefCounted
class_name U_GameplayActions

## Action creators for gameplay state slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_PAUSE_GAME := StringName("gameplay/pause")
const ACTION_UNPAUSE_GAME := StringName("gameplay/unpause")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_PAUSE_GAME)
	U_ActionRegistry.register_action(ACTION_UNPAUSE_GAME)

## Create a pause game action
static func pause_game() -> Dictionary:
	return {
		"type": ACTION_PAUSE_GAME,
		"payload": null
	}

## Create an unpause game action
static func unpause_game() -> Dictionary:
	return {
		"type": ACTION_UNPAUSE_GAME,
		"payload": null
	}
