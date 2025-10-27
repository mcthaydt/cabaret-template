extends RefCounted
class_name U_TransitionActions

## Action creators for state slice transitions
##
## Provides type-safe action creators for transitioning between boot, menu, and gameplay slices.
## All actions are automatically registered on static initialization.

const ACTION_TRANSITION_TO_MENU := StringName("transition/to_menu")
const ACTION_TRANSITION_TO_GAMEPLAY := StringName("transition/to_gameplay")
const ACTION_TRANSITION_TO_BOOT := StringName("transition/to_boot")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	ActionRegistry.register_action(ACTION_TRANSITION_TO_MENU)
	ActionRegistry.register_action(ACTION_TRANSITION_TO_GAMEPLAY)
	ActionRegistry.register_action(ACTION_TRANSITION_TO_BOOT)

## Transition to menu (from boot or gameplay)
static func transition_to_menu() -> Dictionary:
	return {
		"type": ACTION_TRANSITION_TO_MENU,
		"payload": null
	}

## Transition to gameplay with menu config (character, difficulty, etc.)
static func transition_to_gameplay(config: Dictionary = {}) -> Dictionary:
	return {
		"type": ACTION_TRANSITION_TO_GAMEPLAY,
		"payload": {"config": config.duplicate(true)}
	}

## Transition back to boot (for restart scenarios)
static func transition_to_boot() -> Dictionary:
	return {
		"type": ACTION_TRANSITION_TO_BOOT,
		"payload": null
	}
