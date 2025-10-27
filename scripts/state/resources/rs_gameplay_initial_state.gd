extends Resource
class_name RS_GameplayInitialState

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

# Entity snapshots (read-only coordination layer)
# Populated at runtime by systems dispatching U_EntityActions.update_entity_snapshot()
# Structure: { "entity_id": { position, velocity, rotation, is_on_floor, is_moving, entity_type, health } }
@export var entities: Dictionary = {}

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		# Core gameplay (writable)
		"paused": paused,
		# Player input (writable)
		"move_input": move_input,
		"look_input": look_input,
		"jump_pressed": jump_pressed,
		"jump_just_pressed": jump_just_pressed,
		# Global settings (writable)
		"gravity_scale": gravity_scale,
		"show_landing_indicator": show_landing_indicator,
		"particle_settings": particle_settings.duplicate(true),
		"audio_settings": audio_settings.duplicate(true),
		# Entity snapshots (read-only coordination layer)
		"entities": entities.duplicate(true)
	}
