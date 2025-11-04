extends RefCounted
class_name U_MenuReducer

## Reducer for menu state slice
##
## Pure function that takes current state and action, returns new state.
## NEVER mutates state directly - always uses .duplicate(true) for immutability.

const U_MenuActions := preload("res://scripts/state/actions/u_menu_actions.gd")

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName())
	
	match action_type:
		U_MenuActions.ACTION_NAVIGATE_TO_SCREEN:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state["active_screen"] = payload.get("screen_name", "main_menu")
			return new_state
		
		U_MenuActions.ACTION_SELECT_CHARACTER:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state["pending_character"] = payload.get("character_id", "")
			return new_state
		
		U_MenuActions.ACTION_SELECT_DIFFICULTY:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state["pending_difficulty"] = payload.get("difficulty", "")
			return new_state
		
		U_MenuActions.ACTION_LOAD_SAVE_FILES:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state["available_saves"] = payload.get("save_files", []).duplicate()
			return new_state
		
		_:
			# Unknown action - return state unchanged
			return state
