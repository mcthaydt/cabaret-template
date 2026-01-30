extends Resource
class_name RS_MusicTrackDefinition

## Music track definition resource
##
## Defines a music track with its stream, fade duration, volume offset,
## loop behavior, and pause behavior.

@export var track_id: StringName = StringName("")
@export var stream: AudioStream = null
@export var default_fade_duration: float = 1.5
@export var base_volume_offset_db: float = 0.0
@export var loop: bool = true
@export_enum("pause", "duck", "continue") var pause_behavior: String = "pause"
