extends RefCounted
class_name U_GameplayActions

## Action creators for gameplay state slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_PAUSE_GAME := StringName("gameplay/pause")
const ACTION_UNPAUSE_GAME := StringName("gameplay/unpause")
const ACTION_UPDATE_HEALTH := StringName("gameplay/update_health")
const ACTION_UPDATE_SCORE := StringName("gameplay/update_score")
const ACTION_SET_LEVEL := StringName("gameplay/set_level")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	ActionRegistry.register_action(ACTION_PAUSE_GAME)
	ActionRegistry.register_action(ACTION_UNPAUSE_GAME)
	ActionRegistry.register_action(ACTION_UPDATE_HEALTH)
	ActionRegistry.register_action(ACTION_UPDATE_SCORE)
	ActionRegistry.register_action(ACTION_SET_LEVEL)

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

## Create an update health action
static func update_health(health: int) -> Dictionary:
	return {
		"type": ACTION_UPDATE_HEALTH,
		"payload": {"health": health}
	}

## Create an update score action
static func update_score(score: int) -> Dictionary:
	return {
		"type": ACTION_UPDATE_SCORE,
		"payload": {"score": score}
	}

## Create a set level action
static func set_level(level: int) -> Dictionary:
	return {
		"type": ACTION_SET_LEVEL,
		"payload": {"level": level}
	}
