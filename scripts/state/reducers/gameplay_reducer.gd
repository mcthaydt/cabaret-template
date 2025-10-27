extends RefCounted
class_name GameplayReducer

## Gameplay state slice reducer
##
## All reducers are pure functions. NEVER mutate state directly. Always use .duplicate(true).
## Reducers process actions and return new state. Unrecognized actions return state unchanged.

const U_TransitionActions := preload("res://scripts/state/u_transition_actions.gd")

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
		
		U_GameplayActions.ACTION_UPDATE_HEALTH:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.health = payload.get("health", state.get("health", 0))
			return new_state
		
		U_GameplayActions.ACTION_UPDATE_SCORE:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.score = payload.get("score", state.get("score", 0))
			return new_state
		
		U_GameplayActions.ACTION_SET_LEVEL:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.level = payload.get("level", state.get("level", 1))
			return new_state
		
		U_GameplayActions.ACTION_TAKE_DAMAGE:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			var damage: int = payload.get("amount", 0)
			new_state.health = max(0, new_state.health - damage)  # Don't go below 0
			return new_state
		
		U_GameplayActions.ACTION_ADD_SCORE:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			var points: int = payload.get("points", 0)
			new_state.score += points
			return new_state
		
		U_TransitionActions.ACTION_TRANSITION_TO_GAMEPLAY:
			# Apply menu config to gameplay state
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			var config: Dictionary = payload.get("config", {})
			
			# Apply character and difficulty from menu config
			if config.has("character"):
				new_state["character"] = config.get("character")
			if config.has("difficulty"):
				new_state["difficulty"] = config.get("difficulty")
			
			return new_state
		
		# Phase 16: Input actions
		"gameplay/UPDATE_MOVE_INPUT":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.move_input = payload.get("move_input", Vector2.ZERO)
			return new_state
		
		"gameplay/UPDATE_LOOK_INPUT":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.look_input = payload.get("look_input", Vector2.ZERO)
			return new_state
		
		"gameplay/UPDATE_JUMP_STATE":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.jump_pressed = payload.get("jump_pressed", false)
			new_state.jump_just_pressed = payload.get("jump_just_pressed", false)
			return new_state
		
		# Phase 16: Physics actions
		"gameplay/UPDATE_GRAVITY_SCALE":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.gravity_scale = payload.get("gravity_scale", 1.0)
			return new_state
		
		"gameplay/UPDATE_FLOOR_STATE":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.is_on_floor = payload.get("is_on_floor", false)
			return new_state
		
		"gameplay/UPDATE_VELOCITY":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.velocity = payload.get("velocity", Vector3.ZERO)
			return new_state
		
		"gameplay/UPDATE_POSITION":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.position = payload.get("position", Vector3.ZERO)
			return new_state
		
		"gameplay/UPDATE_ROTATION":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.rotation = payload.get("rotation", Vector3.ZERO)
			return new_state
		
		"gameplay/UPDATE_IS_MOVING":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.is_moving = payload.get("is_moving", false)
			return new_state
		
		# Phase 16: Visual actions
		"gameplay/TOGGLE_LANDING_INDICATOR":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.show_landing_indicator = payload.get("show_landing_indicator", true)
			return new_state
		
		"gameplay/UPDATE_PARTICLE_SETTINGS":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.particle_settings = payload.get("particle_settings", {}).duplicate(true)
			return new_state
		
		"gameplay/UPDATE_AUDIO_SETTINGS":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.audio_settings = payload.get("audio_settings", {}).duplicate(true)
			return new_state
		
		_:
			# Unknown action - return state unchanged
			return state
