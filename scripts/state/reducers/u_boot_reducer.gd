extends RefCounted
class_name U_BootReducer

## Reducer for boot state slice
##
## Pure function that takes current state and action, returns new state.
## NEVER mutates state directly - always uses .duplicate(true) for immutability.


static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName())
	
	match action_type:
		U_BootActions.ACTION_UPDATE_LOADING_PROGRESS:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state["loading_progress"] = payload.get("progress", 0.0)
			return new_state
		
		U_BootActions.ACTION_BOOT_ERROR:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state["phase"] = "error"
			new_state["error_message"] = payload.get("error", "")
			return new_state
		
		U_BootActions.ACTION_BOOT_COMPLETE:
			var new_state: Dictionary = state.duplicate(true)
			new_state["is_ready"] = true
			new_state["phase"] = "ready"
			new_state["loading_progress"] = 1.0
			return new_state
		
		_:
			# Unknown action - return state unchanged
			return state
