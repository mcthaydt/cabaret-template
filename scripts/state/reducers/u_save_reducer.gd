extends RefCounted
class_name U_SaveReducer

## Save state slice reducer
##
## All reducers are pure functions. NEVER mutate state directly. Always use .duplicate(true).
## Reducers process actions and return new state. Unrecognized actions return state unchanged.

## Reduce save state based on dispatched action
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: Variant = action.get("type")

	match action_type:
		U_SaveActions.ACTION_SAVE_STARTED:
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_saving"] = true
			new_state["last_error"] = ""
			return new_state

		U_SaveActions.ACTION_SAVE_COMPLETED:
			var slot_index: int = action.get("slot_index", -1)
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_saving"] = false
			new_state["last_save_slot"] = slot_index
			new_state["last_error"] = ""
			return new_state

		U_SaveActions.ACTION_SAVE_FAILED:
			var error: String = action.get("error", "")
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_saving"] = false
			new_state["last_error"] = error
			return new_state

		U_SaveActions.ACTION_LOAD_STARTED:
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_loading"] = true
			new_state["last_error"] = ""
			return new_state

		U_SaveActions.ACTION_LOAD_COMPLETED:
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_loading"] = false
			new_state["last_error"] = ""
			return new_state

		U_SaveActions.ACTION_LOAD_FAILED:
			var error: String = action.get("error", "")
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_loading"] = false
			new_state["last_error"] = error
			return new_state

		U_SaveActions.ACTION_DELETE_STARTED:
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_deleting"] = true
			new_state["last_error"] = ""
			return new_state

		U_SaveActions.ACTION_DELETE_COMPLETED:
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_deleting"] = false
			new_state["last_error"] = ""
			return new_state

		U_SaveActions.ACTION_DELETE_FAILED:
			var error: String = action.get("error", "")
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_deleting"] = false
			new_state["last_error"] = error
			return new_state

		U_SaveActions.ACTION_SET_SAVE_MODE:
			var mode: int = action.get("mode", 1)
			var new_state: Dictionary = state.duplicate(true)
			new_state["current_mode"] = mode
			return new_state

		_:
			# Unhandled action - return state unchanged
			return state
