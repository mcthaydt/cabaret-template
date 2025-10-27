extends RefCounted
class_name GameplayReducer

## Gameplay state slice reducer
##
## All reducers are pure functions. NEVER mutate state directly. Always use .duplicate(true).
## Reducers process actions and return new state. Unrecognized actions return state unchanged.

const U_TransitionActions := preload("res://scripts/state/u_transition_actions.gd")
const U_EntityActions := preload("res://scripts/state/actions/u_entity_actions.gd")

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
		
		# Phase 16: Global settings
		"gameplay/UPDATE_GRAVITY_SCALE":
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			new_state.gravity_scale = payload.get("gravity_scale", 1.0)
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
		
		# Phase 16: Entity Coordination Pattern
		U_EntityActions.ACTION_UPDATE_ENTITY_SNAPSHOT:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			var entity_id: String = payload.get("entity_id", "")
			var snapshot: Dictionary = payload.get("snapshot", {})
			
			if entity_id.is_empty():
				return state
			
			# Ensure entities dict exists
			if not new_state.has("entities"):
				new_state["entities"] = {}
			
			# Merge snapshot into entity data (preserves existing fields)
			if new_state["entities"].has(entity_id):
				var existing: Dictionary = new_state["entities"][entity_id].duplicate(true)
				for key in snapshot.keys():
					existing[key] = snapshot[key]
				new_state["entities"][entity_id] = existing
			else:
				new_state["entities"][entity_id] = snapshot.duplicate(true)
			
			return new_state
		
		U_EntityActions.ACTION_REMOVE_ENTITY:
			var new_state: Dictionary = state.duplicate(true)
			var payload: Dictionary = action.get("payload", {})
			var entity_id: String = payload.get("entity_id", "")
			
			if not entity_id.is_empty() and new_state.has("entities"):
				if new_state["entities"].has(entity_id):
					new_state["entities"].erase(entity_id)
			
			return new_state
		
		_:
			# Unknown action - return state unchanged
			return state
