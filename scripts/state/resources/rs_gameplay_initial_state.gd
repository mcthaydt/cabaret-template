extends Resource
class_name RS_GameplayInitialState

## Initial state for gameplay slice
##
## Defines default values for gameplay state fields.
## Used by M_StateStore to initialize gameplay slice on _ready().
##
## Phase 16: Expanded for full project integration

# Core gameplay state
@export var paused: bool = false
@export var health: int = 100
@export var score: int = 0
@export var level: int = 1

# Input state (T449)
@export var move_input: Vector2 = Vector2.ZERO
@export var look_input: Vector2 = Vector2.ZERO
@export var jump_pressed: bool = false
@export var jump_just_pressed: bool = false

# Physics state (T450)
@export var gravity_scale: float = 1.0
@export var is_on_floor: bool = false
@export var velocity: Vector3 = Vector3.ZERO

# Player state (T451)
@export var position: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO
@export var is_moving: bool = false

# Visual state (T452)
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

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		# Core gameplay
		"paused": paused,
		"health": health,
		"score": score,
		"level": level,
		# Input state
		"move_input": move_input,
		"look_input": look_input,
		"jump_pressed": jump_pressed,
		"jump_just_pressed": jump_just_pressed,
		# Physics state
		"gravity_scale": gravity_scale,
		"is_on_floor": is_on_floor,
		"velocity": velocity,
		# Player state
		"position": position,
		"rotation": rotation,
		"is_moving": is_moving,
		# Visual state
		"show_landing_indicator": show_landing_indicator,
		"particle_settings": particle_settings.duplicate(true),
		"audio_settings": audio_settings.duplicate(true)
	}
