@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_GameplayInitialState

const INPUT_REDUCER := preload("res://scripts/state/reducers/u_input_reducer.gd")

## Initial state for gameplay slice
##
## Defines default values for gameplay state fields.
## Used by M_StateStore to initialize gameplay slice on _ready().
##
## Phase 16: Entity Coordination Pattern
## - Game-wide state (writable)
## - Player input (writable - single player)
## - Entity snapshots (read-only coordination layer)
## See: redux-state-store-entity-coordination-pattern.md

# Core gameplay state (writable)
@export var paused: bool = false

# Player input state (writable - single player)
@export var move_input: Vector2 = Vector2.ZERO
@export var look_input: Vector2 = Vector2.ZERO
@export var jump_pressed: bool = false
@export var jump_just_pressed: bool = false

# Player health + progression
@export var player_entity_id: String = "player"
@export var player_health: float = 100.0
@export var player_max_health: float = 100.0
@export var death_count: int = 0
@export var death_in_progress: bool = false  # Phase 0: Save Manager - blocks autosave during death
@export var completed_areas: Array[String] = []
@export var last_victory_objective: StringName = StringName("")
@export var game_completed: bool = false
@export var playtime_seconds: int = 0  # Phase 0: Save Manager - total playtime tracking

# Global settings (writable)
@export var gravity_scale: float = 1.0
@export var show_landing_indicator: bool = true
@export var particle_settings: Dictionary = {
	"jump_particles_enabled": true,
	"landing_particles_enabled": true
}
@export var audio_settings: Dictionary = {
	"jump_sound_enabled": true,
	"volume": 1.0,
	"pitch_scale": 1.0
}

# Area transition state (writable)
@export var target_spawn_point: StringName = StringName("")
@export var last_checkpoint: StringName = StringName("")  # Phase 12.3b: Last checkpoint activated

# Entity snapshots (read-only coordination layer)
# Populated at runtime by systems dispatching U_EntityActions.update_entity_snapshot()
# Structure: { "entity_id": { position, velocity, rotation, is_on_floor, is_moving, entity_type, health } }
@export var entities: Dictionary = {}

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	var input_state := INPUT_REDUCER.get_default_gameplay_input_state()
	# Keep legacy top-level fields in sync with nested state for backwards compatibility.
	input_state["move_input"] = move_input
	input_state["look_input"] = look_input
	input_state["jump_pressed"] = jump_pressed
	input_state["jump_just_pressed"] = jump_just_pressed

	return {
		# Core gameplay (writable)
		"paused": paused,
		# Player input (writable)
		"move_input": move_input,
		"look_input": look_input,
		"jump_pressed": jump_pressed,
		"jump_just_pressed": jump_just_pressed,
		# Player health/progression
		"player_entity_id": player_entity_id,
		"player_health": player_health,
		"player_max_health": player_max_health,
		"death_count": death_count,
		"death_in_progress": death_in_progress,
		"completed_areas": completed_areas.duplicate(true),
		"last_victory_objective": last_victory_objective,
		"game_completed": game_completed,
		"playtime_seconds": playtime_seconds,
		# Global settings (writable)
		"gravity_scale": gravity_scale,
		"show_landing_indicator": show_landing_indicator,
		"particle_settings": particle_settings.duplicate(true),
		"audio_settings": audio_settings.duplicate(true),
		"input": input_state,
		# Area transition state (writable)
		"target_spawn_point": target_spawn_point,
		"last_checkpoint": last_checkpoint,
		# Entity snapshots (read-only coordination layer)
		"entities": entities.duplicate(true)
	}
