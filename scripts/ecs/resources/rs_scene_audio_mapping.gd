extends Resource
class_name RS_SceneAudioMapping

## Scene audio mapping resource
##
## Maps a scene ID to its music and ambient track IDs.
## Empty StringNames indicate no audio for that category.

@export var scene_id: StringName = StringName("")
@export var music_track_id: StringName = StringName("")
@export var ambient_track_id: StringName = StringName("")
