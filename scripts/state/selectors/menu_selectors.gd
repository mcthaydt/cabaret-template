extends RefCounted
class_name MenuSelectors

## Selectors for menu state slice
##
## Pure functions that compute derived state from menu slice.
## Always pass the full menu state Dictionary to these functions.

## Get the current active screen
static func get_active_screen(state: Dictionary) -> String:
	return state.get("active_screen", "main_menu")

## Get pending game configuration (character + difficulty)
static func get_pending_game_config(state: Dictionary) -> Dictionary:
	return {
		"character": state.get("pending_character", ""),
		"difficulty": state.get("pending_difficulty", "")
	}

## Get list of available save files
static func get_available_saves(state: Dictionary) -> Array:
	return state.get("available_saves", [])

## Check if game config is complete (ready to start)
static func is_game_config_complete(state: Dictionary) -> bool:
	var character: String = state.get("pending_character", "")
	var difficulty: String = state.get("pending_difficulty", "")
	return not character.is_empty() and not difficulty.is_empty()

## Get pending character selection
static func get_pending_character(state: Dictionary) -> String:
	return state.get("pending_character", "")

## Get pending difficulty selection
static func get_pending_difficulty(state: Dictionary) -> String:
	return state.get("pending_difficulty", "")
