@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_LandingSoundSettings

@export var enabled: bool = true
@export var audio_stream: AudioStream
@export var volume_db: float = 0.0
@export var pitch_variation: float = 0.1
@export var min_interval: float = 0.1
