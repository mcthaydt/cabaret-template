extends Resource
class_name RS_AmbientTrackDefinition

## Ambient track definition resource
##
## Defines an ambient track with its stream, fade duration, volume offset,
## and loop behavior.

@export var ambient_id: StringName = StringName("")
@export var stream: AudioStream = null
@export var default_fade_duration: float = 2.0
@export var base_volume_offset_db: float = 0.0
@export var loop: bool = true
