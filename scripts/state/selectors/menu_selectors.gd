extends RefCounted
class_name MenuSelectors

## Selectors for menu state slice
##
## Pure functions that compute derived state from menu slice.
## Always pass the full menu state Dictionary to these functions.

## Get the current active screen
static func get_active_screen(state: Dictionary) -> String:
	return state.get("active_screen", "main_menu")
