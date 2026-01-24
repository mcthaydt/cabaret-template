@icon("res://assets/editor_icons/settings.svg")
extends Resource
class_name RS_FootstepSoundSettings

## Settings resource for S_FootstepSoundSystem.
##
## Configures footstep sound behavior including:
## - Step timing and velocity thresholds
## - Surface-specific sound arrays (4 variations each)
## - Volume and audio bus routing

@export_group("Behavior")
## Enable/disable footstep sound system
@export var enabled: bool = true

## Time interval between footstep sounds (in seconds) at `reference_speed`.
@export_range(0.1, 2.0, 0.05) var step_interval: float = 0.5

## Reference speed (m/s) for `step_interval` cadence scaling.
## Example: if reference_speed is 6.0 and step_interval is 0.5, then at speed 6.0
## footsteps play every 0.5s (≈120 steps/min), and scale up/down from there.
@export_range(0.1, 20.0, 0.1) var reference_speed: float = 6.0

## Minimum horizontal velocity to trigger footsteps (m/s)
@export_range(0.1, 10.0, 0.1) var min_velocity: float = 1.0

@export_group("Audio")
## Volume of footstep sounds (in dB)
@export_range(-80.0, 0.0, 0.1) var volume_db: float = 0.0

@export_group("Surface Sounds")
## Default surface sounds (4 variations)
@export var default_sounds: Array[AudioStream] = []

## Grass surface sounds (4 variations)
@export var grass_sounds: Array[AudioStream] = []

## Stone surface sounds (4 variations)
@export var stone_sounds: Array[AudioStream] = []

## Wood surface sounds (4 variations)
@export var wood_sounds: Array[AudioStream] = []

## Metal surface sounds (4 variations)
@export var metal_sounds: Array[AudioStream] = []

## Water surface sounds (4 variations)
@export var water_sounds: Array[AudioStream] = []

## Returns the sound array for a given surface type.
## Returns default_sounds if the specific surface has no sounds configured.
func get_sounds_for_surface(surface_type: C_SurfaceDetectorComponent.SurfaceType) -> Array[AudioStream]:
	match surface_type:
		C_SurfaceDetectorComponent.SurfaceType.GRASS:
			return grass_sounds if grass_sounds.size() > 0 else default_sounds
		C_SurfaceDetectorComponent.SurfaceType.STONE:
			return stone_sounds if stone_sounds.size() > 0 else default_sounds
		C_SurfaceDetectorComponent.SurfaceType.WOOD:
			return wood_sounds if wood_sounds.size() > 0 else default_sounds
		C_SurfaceDetectorComponent.SurfaceType.METAL:
			return metal_sounds if metal_sounds.size() > 0 else default_sounds
		C_SurfaceDetectorComponent.SurfaceType.WATER:
			return water_sounds if water_sounds.size() > 0 else default_sounds
		_:
			return default_sounds
