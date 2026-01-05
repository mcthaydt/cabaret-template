@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_AudioInitialState

## Audio Initial State Resource (Audio Manager Phase 0 - Task 0.2)
##
## Defines default audio settings. M_StateStore merges these values with reducer
## defaults to create the initial audio slice state.

const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")

@export_group("Volumes")
@export_range(0.0, 1.0, 0.01) var master_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var music_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var ambient_volume: float = 1.0

@export_group("Mutes")
@export var master_muted: bool = false
@export var music_muted: bool = false
@export var sfx_muted: bool = false
@export var ambient_muted: bool = false

@export_group("Spatial Audio")
@export var spatial_audio_enabled: bool = true

## Convert resource to Dictionary for state store.
##
## Merges with reducer defaults so future fields are picked up automatically.
func to_dictionary() -> Dictionary:
	var defaults: Dictionary = U_AUDIO_REDUCER.get_default_audio_state()
	var merged: Dictionary = defaults.duplicate(true)

	merged["master_volume"] = master_volume
	merged["music_volume"] = music_volume
	merged["sfx_volume"] = sfx_volume
	merged["ambient_volume"] = ambient_volume

	merged["master_muted"] = master_muted
	merged["music_muted"] = music_muted
	merged["sfx_muted"] = sfx_muted
	merged["ambient_muted"] = ambient_muted

	merged["spatial_audio_enabled"] = spatial_audio_enabled
	return merged

