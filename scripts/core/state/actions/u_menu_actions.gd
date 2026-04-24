extends RefCounted
class_name U_MenuActions

## Action creators for menu state slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_NAVIGATE_TO_SCREEN := StringName("menu/navigate_to_screen")
const ACTION_SELECT_CHARACTER := StringName("menu/select_character")
const ACTION_SELECT_DIFFICULTY := StringName("menu/select_difficulty")
const ACTION_LOAD_SAVE_FILES := StringName("menu/load_save_files")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_NAVIGATE_TO_SCREEN)
	U_ActionRegistry.register_action(ACTION_SELECT_CHARACTER)
	U_ActionRegistry.register_action(ACTION_SELECT_DIFFICULTY)
	U_ActionRegistry.register_action(ACTION_LOAD_SAVE_FILES)

## Navigate to a menu screen
static func navigate_to_screen(screen_name: String) -> Dictionary:
	return {
		"type": ACTION_NAVIGATE_TO_SCREEN,
		"payload": {"screen_name": screen_name}
	}

## Select a character for gameplay
static func select_character(character_id: String) -> Dictionary:
	return {
		"type": ACTION_SELECT_CHARACTER,
		"payload": {"character_id": character_id}
	}

## Select difficulty level
static func select_difficulty(difficulty: String) -> Dictionary:
	return {
		"type": ACTION_SELECT_DIFFICULTY,
		"payload": {"difficulty": difficulty}
	}

## Load available save files
static func load_save_files(save_files: Array) -> Dictionary:
	return {
		"type": ACTION_LOAD_SAVE_FILES,
		"payload": {"save_files": save_files.duplicate()}
	}
