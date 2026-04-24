extends Resource
class_name RS_UISoundDefinition

## UI sound definition resource
##
## Defines a UI sound effect with its stream, volume, pitch variation,
## and throttle settings.

@export var sound_id: StringName = StringName("")
@export var stream: AudioStream = null
@export var volume_db: float = 0.0
@export_range(0.0, 1.0) var pitch_variation: float = 0.0
@export var throttle_ms: int = 0  ## Minimum milliseconds between plays (0 = no throttle)
