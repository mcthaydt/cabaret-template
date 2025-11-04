extends RefCounted
class_name U_GameplayReducer

## Gameplay state slice reducer
##
## All reducers are pure functions. NEVER mutate state directly. Always use .duplicate(true).
## Reducers process actions and return new state. Unrecognized actions return state unchanged.

const U_TransitionActions := preload("res://scripts/state/actions/u_transition_actions.gd")
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

		U_GameplayActions.ACTION_UPDATE_MOVE_INPUT:
			var new_state: Dictionary = state.duplicate(true)
			new_state.move_input = action.get("payload", Vector2.ZERO)
			return new_state

		U_GameplayActions.ACTION_UPDATE_LOOK_INPUT:
			var new_state: Dictionary = state.duplicate(true)
			new_state.look_input = action.get("payload", Vector2.ZERO)
			return new_state

		U_GameplayActions.ACTION_SET_JUMP_PRESSED:
			var new_state: Dictionary = state.duplicate(true)
			new_state.jump_pressed = action.get("payload", false)
			return new_state

		U_GameplayActions.ACTION_SET_JUMP_JUST_PRESSED:
			var new_state: Dictionary = state.duplicate(true)
			new_state.jump_just_pressed = action.get("payload", false)
			return new_state

		U_GameplayActions.ACTION_SET_GRAVITY_SCALE:
			var new_state: Dictionary = state.duplicate(true)
			new_state.gravity_scale = action.get("payload", 1.0)
			return new_state

		U_GameplayActions.ACTION_SET_SHOW_LANDING_INDICATOR:
			var new_state: Dictionary = state.duplicate(true)
			new_state.show_landing_indicator = action.get("payload", true)
			return new_state

		U_GameplayActions.ACTION_SET_PARTICLE_SETTINGS:
			var new_state: Dictionary = state.duplicate(true)
			new_state.particle_settings = action.get("payload", {}).duplicate(true)
			return new_state

		U_GameplayActions.ACTION_SET_AUDIO_SETTINGS:
			var new_state: Dictionary = state.duplicate(true)
			new_state.audio_settings = action.get("payload", {}).duplicate(true)
			return new_state

		U_GameplayActions.ACTION_SET_TARGET_SPAWN_POINT:
			var new_state: Dictionary = state.duplicate(true)
			new_state.target_spawn_point = action.get("payload", StringName(""))
			return new_state

		U_GameplayActions.ACTION_SET_LAST_CHECKPOINT:
			var new_state: Dictionary = state.duplicate(true)
			new_state.last_checkpoint = action.get("payload", StringName(""))
			return new_state

		U_GameplayActions.ACTION_TAKE_DAMAGE:
			var damage_state: Dictionary = state.duplicate(true)
			var damage_payload: Dictionary = action.get("payload", {})
			var damage_entity: String = String(damage_payload.get("entity_id", ""))
			var player_id_damage: String = String(state.get("player_entity_id", "E_Player"))
			if damage_entity.is_empty() or damage_entity == player_id_damage:
				var current_health: float = float(damage_state.get("player_health", 0.0))
				var max_health: float = float(damage_state.get("player_max_health", current_health))
				var damage_amount: float = float(damage_payload.get("amount", 0.0))
				damage_state.player_health = clampf(current_health - damage_amount, 0.0, max_health)
			return damage_state

		U_GameplayActions.ACTION_HEAL:
			var heal_state: Dictionary = state.duplicate(true)
			var heal_payload: Dictionary = action.get("payload", {})
			var heal_entity: String = String(heal_payload.get("entity_id", ""))
			var player_id_heal: String = String(state.get("player_entity_id", "E_Player"))
			if heal_entity.is_empty() or heal_entity == player_id_heal:
				var current_health_heal: float = float(heal_state.get("player_health", 0.0))
				var max_health_heal: float = float(heal_state.get("player_max_health", current_health_heal))
				var heal_amount: float = float(heal_payload.get("amount", 0.0))
				heal_state.player_health = clampf(current_health_heal + heal_amount, 0.0, max_health_heal)
			return heal_state

		U_GameplayActions.ACTION_TRIGGER_DEATH:
			var death_state: Dictionary = state.duplicate(true)
			var death_payload: Dictionary = action.get("payload", {})
			var death_entity: String = String(death_payload.get("entity_id", ""))
			var tracked_player: String = String(state.get("player_entity_id", "E_Player"))
			if death_entity.is_empty() or death_entity == tracked_player:
				death_state.player_health = 0.0
			return death_state

		U_GameplayActions.ACTION_INCREMENT_DEATH_COUNT:
			var count_state: Dictionary = state.duplicate(true)
			count_state.death_count = int(count_state.get("death_count", 0)) + 1
			return count_state

		U_GameplayActions.ACTION_TRIGGER_VICTORY:
			var victory_state: Dictionary = state.duplicate(true)
			victory_state.last_victory_objective = action.get("payload", StringName(""))
			return victory_state

		U_GameplayActions.ACTION_MARK_AREA_COMPLETE:
			var area_state: Dictionary = state.duplicate(true)
			var area_id: String = String(action.get("payload", ""))
			var areas: Array = []
			if area_state.has("completed_areas"):
				areas = (area_state.completed_areas as Array).duplicate(true)
			if not area_id.is_empty() and not areas.has(area_id):
				areas.append(area_id)
			area_state.completed_areas = areas
			return area_state

		U_GameplayActions.ACTION_GAME_COMPLETE:
			var complete_state: Dictionary = state.duplicate(true)
			complete_state.game_completed = true
			return complete_state

		U_GameplayActions.ACTION_RESET_PROGRESS:
			var reset_state: Dictionary = state.duplicate(true)
			var max_health_reset: float = float(reset_state.get("player_max_health", 100.0))

			reset_state.paused = false
			reset_state.move_input = Vector2.ZERO
			reset_state.look_input = Vector2.ZERO
			reset_state.jump_pressed = false
			reset_state.jump_just_pressed = false

			reset_state.player_health = max_health_reset
			reset_state.death_count = 0
			reset_state.completed_areas = []
			reset_state.last_victory_objective = StringName("")
			reset_state.game_completed = false
			reset_state.target_spawn_point = StringName("")

			var player_id: String = String(reset_state.get("player_entity_id", "E_Player"))
			var updated_entities: Dictionary = {}
			if reset_state.has("entities"):
				var entities_copy: Dictionary = reset_state["entities"].duplicate(true)
				if entities_copy.has(player_id):
					var player_snapshot: Dictionary = entities_copy[player_id].duplicate(true)
					player_snapshot["health"] = max_health_reset
					player_snapshot["is_dead"] = false
					updated_entities[player_id] = player_snapshot
			reset_state["entities"] = updated_entities

			return reset_state

		U_GameplayActions.ACTION_RESET_AFTER_DEATH:
			var reset_state: Dictionary = state.duplicate(true)
			var max_health_reset: float = float(reset_state.get("player_max_health", 100.0))
			reset_state.player_health = max_health_reset
			reset_state.last_victory_objective = StringName("")

			var player_id: String = String(reset_state.get("player_entity_id", "E_Player"))
			if reset_state.has("entities"):
				var entities_copy: Dictionary = reset_state["entities"].duplicate(true)
				if entities_copy.has(player_id):
					var player_snapshot: Dictionary = entities_copy[player_id].duplicate(true)
					player_snapshot["health"] = max_health_reset
					player_snapshot["is_dead"] = false
					entities_copy[player_id] = player_snapshot
				reset_state["entities"] = entities_copy

			return reset_state

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
