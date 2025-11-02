extends RefCounted
class_name U_GameplayActions

## Action creators for gameplay state slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_PAUSE_GAME := StringName("gameplay/pause")
const ACTION_UNPAUSE_GAME := StringName("gameplay/unpause")
const ACTION_UPDATE_MOVE_INPUT := StringName("gameplay/update_move_input")
const ACTION_UPDATE_LOOK_INPUT := StringName("gameplay/update_look_input")
const ACTION_SET_JUMP_PRESSED := StringName("gameplay/set_jump_pressed")
const ACTION_SET_JUMP_JUST_PRESSED := StringName("gameplay/set_jump_just_pressed")
const ACTION_SET_GRAVITY_SCALE := StringName("gameplay/set_gravity_scale")
const ACTION_SET_SHOW_LANDING_INDICATOR := StringName("gameplay/set_show_landing_indicator")
const ACTION_SET_PARTICLE_SETTINGS := StringName("gameplay/set_particle_settings")
const ACTION_SET_AUDIO_SETTINGS := StringName("gameplay/set_audio_settings")
const ACTION_SET_TARGET_SPAWN_POINT := StringName("gameplay/set_target_spawn_point")
const ACTION_TAKE_DAMAGE := StringName("gameplay/take_damage")
const ACTION_HEAL := StringName("gameplay/heal")
const ACTION_TRIGGER_DEATH := StringName("gameplay/trigger_death")
const ACTION_INCREMENT_DEATH_COUNT := StringName("gameplay/increment_death_count")
const ACTION_TRIGGER_VICTORY := StringName("gameplay/trigger_victory")
const ACTION_MARK_AREA_COMPLETE := StringName("gameplay/mark_area_complete")
const ACTION_GAME_COMPLETE := StringName("gameplay/game_complete")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_PAUSE_GAME)
	U_ActionRegistry.register_action(ACTION_UNPAUSE_GAME)
	U_ActionRegistry.register_action(ACTION_UPDATE_MOVE_INPUT)
	U_ActionRegistry.register_action(ACTION_UPDATE_LOOK_INPUT)
	U_ActionRegistry.register_action(ACTION_SET_JUMP_PRESSED)
	U_ActionRegistry.register_action(ACTION_SET_JUMP_JUST_PRESSED)
	U_ActionRegistry.register_action(ACTION_SET_GRAVITY_SCALE)
	U_ActionRegistry.register_action(ACTION_SET_SHOW_LANDING_INDICATOR)
	U_ActionRegistry.register_action(ACTION_SET_PARTICLE_SETTINGS)
	U_ActionRegistry.register_action(ACTION_SET_AUDIO_SETTINGS)
	U_ActionRegistry.register_action(ACTION_SET_TARGET_SPAWN_POINT)
	U_ActionRegistry.register_action(ACTION_TAKE_DAMAGE)
	U_ActionRegistry.register_action(ACTION_HEAL)
	U_ActionRegistry.register_action(ACTION_TRIGGER_DEATH)
	U_ActionRegistry.register_action(ACTION_INCREMENT_DEATH_COUNT)
	U_ActionRegistry.register_action(ACTION_TRIGGER_VICTORY)
	U_ActionRegistry.register_action(ACTION_MARK_AREA_COMPLETE)
	U_ActionRegistry.register_action(ACTION_GAME_COMPLETE)

## Create a pause game action
static func pause_game() -> Dictionary:
	return {
		"type": ACTION_PAUSE_GAME,
		"payload": null
	}

## Create an unpause game action
static func unpause_game() -> Dictionary:
	return {
		"type": ACTION_UNPAUSE_GAME,
		"payload": null
	}

## Update player move input
static func update_move_input(move_input: Vector2) -> Dictionary:
	return {
		"type": ACTION_UPDATE_MOVE_INPUT,
		"payload": move_input
	}

## Update player look input
static func update_look_input(look_input: Vector2) -> Dictionary:
	return {
		"type": ACTION_UPDATE_LOOK_INPUT,
		"payload": look_input
	}

## Set jump pressed state
static func set_jump_pressed(pressed: bool) -> Dictionary:
	return {
		"type": ACTION_SET_JUMP_PRESSED,
		"payload": pressed
	}

## Set jump just pressed state
static func set_jump_just_pressed(just_pressed: bool) -> Dictionary:
	return {
		"type": ACTION_SET_JUMP_JUST_PRESSED,
		"payload": just_pressed
	}

## Set gravity scale
static func set_gravity_scale(scale: float) -> Dictionary:
	return {
		"type": ACTION_SET_GRAVITY_SCALE,
		"payload": scale
	}

## Set landing indicator visibility
static func set_show_landing_indicator(show: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SHOW_LANDING_INDICATOR,
		"payload": show
	}

## Set particle settings
static func set_particle_settings(settings: Dictionary) -> Dictionary:
	return {
		"type": ACTION_SET_PARTICLE_SETTINGS,
		"payload": settings.duplicate(true)  # Deep copy for immutability
	}

## Set audio settings
static func set_audio_settings(settings: Dictionary) -> Dictionary:
	return {
		"type": ACTION_SET_AUDIO_SETTINGS,
		"payload": settings.duplicate(true)  # Deep copy for immutability
	}

## Set target spawn point for area transitions
static func set_target_spawn_point(spawn_point: StringName) -> Dictionary:
	return {
		"type": ACTION_SET_TARGET_SPAWN_POINT,
		"payload": spawn_point
	}

## Record damage taken (health reduced)
static func take_damage(entity_id: String, amount: float) -> Dictionary:
	return {
		"type": ACTION_TAKE_DAMAGE,
		"payload": {
			"entity_id": entity_id,
			"amount": amount
		}
	}

## Record healing applied
static func heal(entity_id: String, amount: float) -> Dictionary:
	return {
		"type": ACTION_HEAL,
		"payload": {
			"entity_id": entity_id,
			"amount": amount
		}
	}

## Signal that an entity has died
static func trigger_death(entity_id: String) -> Dictionary:
	return {
		"type": ACTION_TRIGGER_DEATH,
		"payload": {
			"entity_id": entity_id
		}
	}

## Increment total death counter
static func increment_death_count() -> Dictionary:
	return {
		"type": ACTION_INCREMENT_DEATH_COUNT,
		"payload": null
	}

## Record victory objective completion
static func trigger_victory(objective_id: StringName) -> Dictionary:
	return {
		"type": ACTION_TRIGGER_VICTORY,
		"payload": objective_id
	}

## Mark an area as completed
static func mark_area_complete(area_id: String) -> Dictionary:
	return {
		"type": ACTION_MARK_AREA_COMPLETE,
		"payload": area_id
	}

## Flag entire game completion
static func game_complete() -> Dictionary:
	return {
		"type": ACTION_GAME_COMPLETE,
		"payload": null
	}
