extends RefCounted
class_name U_MenuActions

## Action creators for menu state slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_NAVIGATE_TO_SCREEN := StringName("menu/navigate_to_screen")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	ActionRegistry.register_action(ACTION_NAVIGATE_TO_SCREEN)

## Navigate to a menu screen
static func navigate_to_screen(screen_name: String) -> Dictionary:
	return {
		"type": ACTION_NAVIGATE_TO_SCREEN,
		"payload": {"screen_name": screen_name}
	}
