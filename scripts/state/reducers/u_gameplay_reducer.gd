extends RefCounted
class_name U_GameplayReducer

## Gameplay state slice reducer
##
## All reducers are pure functions. NEVER mutate state directly. Always use .duplicate(true).
## Reducers process actions and return new state. Unrecognized actions return state unchanged.

const U_TransitionActions := preload("res://scripts/state/actions/u_transition_actions.gd")
const U_EntityActions := preload("res://scripts/state/actions/u_entity_actions.gd")
const INPUT_ACTIONS := preload("res://scripts/state/actions/u_input_actions.gd")
const INPUT_REDUCER := preload("res://scripts/state/reducers/u_input_reducer.gd")

## Reduce gameplay state based on dispatched action
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: Variant = action.get("type")
	
	var input_state_result: Variant = _apply_input_action(state, action)
	if input_state_result != null:
		return input_state_result
	
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
			var move_vec: Vector2 = action.get("payload", Vector2.ZERO)
			var forwarded_move: Dictionary = INPUT_ACTIONS.update_move_input(move_vec)
			var applied_move: Variant = _apply_input_action(state, forwarded_move)
			if applied_move != null:
				return applied_move
			var fallback_move: Dictionary = state.duplicate(true)
			fallback_move.move_input = move_vec
			return fallback_move

		U_GameplayActions.ACTION_UPDATE_LOOK_INPUT:
			var look_vec: Vector2 = action.get("payload", Vector2.ZERO)
			var forwarded_look: Dictionary = INPUT_ACTIONS.update_look_input(look_vec)
			var applied_look: Variant = _apply_input_action(state, forwarded_look)
			if applied_look != null:
				return applied_look
			var fallback_look: Dictionary = state.duplicate(true)
			fallback_look.look_input = look_vec
			return fallback_look

		U_GameplayActions.ACTION_SET_JUMP_PRESSED:
			var pressed: bool = action.get("payload", false)
			var current_input: Dictionary = _get_current_input(state)
			var forwarded_jump: Dictionary = INPUT_ACTIONS.update_jump_state(
				pressed,
				current_input.get("jump_just_pressed", false)
			)
			var applied_jump: Variant = _apply_input_action(state, forwarded_jump)
			if applied_jump != null:
				return applied_jump
			var fallback_jump: Dictionary = state.duplicate(true)
			fallback_jump.jump_pressed = pressed
			return fallback_jump

		U_GameplayActions.ACTION_SET_JUMP_JUST_PRESSED:
			var just_pressed: bool = action.get("payload", false)
			var current_jump: Dictionary = _get_current_input(state)
			var forwarded_jump_state: Dictionary = INPUT_ACTIONS.update_jump_state(
				current_jump.get("jump_pressed", false),
				just_pressed
			)
			var applied_jump_state: Variant = _apply_input_action(state, forwarded_jump_state)
			if applied_jump_state != null:
				return applied_jump_state
			var fallback_jump_state: Dictionary = state.duplicate(true)
			fallback_jump_state.jump_just_pressed = just_pressed
			return fallback_jump_state

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
			var player_id_damage: String = String(state.get("player_entity_id", "player"))
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
			var player_id_heal: String = String(state.get("player_entity_id", "player"))
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
			var tracked_player: String = String(state.get("player_entity_id", "player"))
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
			reset_state.last_checkpoint = StringName("")

			var player_id: String = String(reset_state.get("player_entity_id", "player"))
			var updated_entities: Dictionary = {}
			if reset_state.has("entities"):
				var entities_copy: Dictionary = reset_state["entities"].duplicate(true)
				if entities_copy.has(player_id):
					var player_snapshot: Dictionary = entities_copy[player_id].duplicate(true)
					player_snapshot["health"] = max_health_reset
					player_snapshot["is_dead"] = false
					updated_entities[player_id] = player_snapshot
			reset_state["entities"] = updated_entities

			# Preserve device state (active_device, gamepad_connected, etc.) while resetting gameplay input
			var current_input: Dictionary = _get_current_input(state)
			var reset_input := INPUT_REDUCER.get_default_gameplay_input_state()
			reset_input["active_device"] = current_input.get("active_device", 0)
			reset_input["gamepad_connected"] = current_input.get("gamepad_connected", false)
			reset_input["gamepad_device_id"] = current_input.get("gamepad_device_id", -1)
			reset_input["touchscreen_enabled"] = current_input.get("touchscreen_enabled", false)
			reset_input["last_input_time"] = current_input.get("last_input_time", 0.0)
			return _apply_input_state(reset_state, reset_input)

		U_GameplayActions.ACTION_RESET_AFTER_DEATH:
			var reset_state: Dictionary = state.duplicate(true)
			var max_health_reset: float = float(reset_state.get("player_max_health", 100.0))
			reset_state.player_health = max_health_reset
			reset_state.last_victory_objective = StringName("")

			var player_id: String = String(reset_state.get("player_entity_id", "player"))
			if reset_state.has("entities"):
				var entities_copy: Dictionary = reset_state["entities"].duplicate(true)
				if entities_copy.has(player_id):
					var player_snapshot: Dictionary = entities_copy[player_id].duplicate(true)
					player_snapshot["health"] = max_health_reset
					player_snapshot["is_dead"] = false
					entities_copy[player_id] = player_snapshot
				reset_state["entities"] = entities_copy

			return reset_state

		U_GameplayActions.ACTION_INCREMENT_PLAYTIME:
			var new_state: Dictionary = state.duplicate(true)
			var seconds: int = int(action.get("payload", 0))
			new_state.playtime_seconds = int(new_state.get("playtime_seconds", 0)) + seconds
			return new_state

		U_GameplayActions.ACTION_SET_DEATH_IN_PROGRESS:
			var new_state: Dictionary = state.duplicate(true)
			new_state.death_in_progress = bool(action.get("payload", false))
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

			# Ensure gameplay starts unpaused
			new_state["paused"] = false

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

static func _apply_input_action(state: Variant, action: Dictionary) -> Variant:
	if action == null:
		return null
	var current_input: Dictionary = _get_current_input(state)
	var reduced: Variant = INPUT_REDUCER.reduce_gameplay_input(current_input, action)
	if reduced == null:
		return null
	return _apply_input_state(state, reduced)

static func _get_current_input(state: Variant) -> Dictionary:
	if state != null and state is Dictionary and (state as Dictionary).has("input") and (state as Dictionary)["input"] is Dictionary:
		return (state["input"] as Dictionary).duplicate(true)
	return INPUT_REDUCER.get_default_gameplay_input_state()

static func _apply_input_state(state: Variant, input_state: Dictionary) -> Dictionary:
	var next: Dictionary = {}
	if state != null and state is Dictionary:
		next = (state as Dictionary).duplicate(true)
	var cloned_input := input_state.duplicate(true)
	next["input"] = cloned_input
	next.move_input = cloned_input.get("move_input", Vector2.ZERO)
	next.look_input = cloned_input.get("look_input", Vector2.ZERO)
	next.jump_pressed = cloned_input.get("jump_pressed", false)
	next.jump_just_pressed = cloned_input.get("jump_just_pressed", false)
	next.sprint_pressed = cloned_input.get("sprint_pressed", false)
	return next
