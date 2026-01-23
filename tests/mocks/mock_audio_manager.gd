extends "res://scripts/interfaces/i_audio_manager.gd"
class_name MockAudioManager

## Lightweight mock audio manager for testing.
##
## Phase 6 (cleanup_v4): Created for duck typing cleanup - extends I_AudioManager interface
##
## Records method calls without creating audio buses or players.

var played: Array[StringName] = []
var last_sound_id: StringName = StringName("")
var play_calls: int = 0
var preview_settings: Dictionary = {}
var preview_active: bool = false

func _ready() -> void:
	# Override to skip base setup and ServiceLocator registration.
	pass

func play_ui_sound(sound_id: StringName) -> void:
	played.append(sound_id)
	last_sound_id = sound_id
	play_calls += 1

func set_audio_settings_preview(preview_settings_param: Dictionary) -> void:
	preview_settings = preview_settings_param.duplicate(true)
	preview_active = true

func clear_audio_settings_preview() -> void:
	preview_settings.clear()
	preview_active = false

func reset() -> void:
	played.clear()
	last_sound_id = StringName("")
	play_calls = 0
	preview_settings.clear()
	preview_active = false
