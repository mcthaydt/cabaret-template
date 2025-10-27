extends RefCounted
class_name GameplayReducer

## Gameplay state slice reducer
##
## All reducers are pure functions. NEVER mutate state directly. Always use .duplicate(true).
## Reducers process actions and return new state. Unrecognized actions return state unchanged.

## Reduce gameplay state based on dispatched action
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: Variant = action.get("type")
	
	match action_type:
		U_GameplayActions.ACTION_PAUSE_GAME:
			var new_state: Dictionary = state.duplicate(true)
			new_state.paused = true
			return new_state
		
		U_GameplayActions.ACTION_UNPAUSE_GAME:
			var new_state: Dictionary = state.duplicate(true)
			new_state.paused = false
			return new_state
		
		_:
			# Unknown action - return state unchanged
			return state
