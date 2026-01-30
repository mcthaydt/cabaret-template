extends Node
class_name I_AudioManager

## Minimal interface for M_AudioManager
##
## Phase 6 (cleanup_v4): Created for duck typing cleanup - removes has_method() checks
##
## Implementations:
## - M_AudioManager (production)
## - MockAudioManager (testing)

## Play a UI sound effect by ID
##
## Plays UI sounds (focus, confirm, cancel, tick) from the registered sound registry.
## No-op if sound_id is empty or not found in registry.
##
## @param _sound_id: Sound ID to play (e.g., "ui_focus", "ui_confirm")
func play_ui_sound(_sound_id: StringName) -> void:
	push_error("I_AudioManager.play_ui_sound not implemented")

## Set temporary audio settings preview
##
## Applies temporary audio settings for preview purposes (e.g., in settings menu).
## Preview settings override Redux state until cleared.
##
## @param _preview_settings: Dictionary with volume/mute values
func set_audio_settings_preview(_preview_settings: Dictionary) -> void:
	push_error("I_AudioManager.set_audio_settings_preview not implemented")

## Clear audio settings preview
##
## Removes temporary preview settings and restores audio state from Redux store.
func clear_audio_settings_preview() -> void:
	push_error("I_AudioManager.clear_audio_settings_preview not implemented")

## Play a music track by ID
##
## Crossfades to the specified music track from the registry.
## Crossfades if another track is currently playing.
##
## @param _track_id: Music track ID to play (e.g., "main_menu", "exterior")
## @param _duration: Crossfade duration in seconds (default: 1.5)
## @param _start_position: Starting position in seconds (default: 0.0)
func play_music(_track_id: StringName, _duration: float = 1.5, _start_position: float = 0.0) -> void:
	push_error("I_AudioManager.play_music not implemented")

## Stop currently playing music
##
## Fades out the active music track over the specified duration.
##
## @param _duration: Fade-out duration in seconds (default: 1.5)
func stop_music(_duration: float = 1.5) -> void:
	push_error("I_AudioManager.stop_music not implemented")

## Play an ambient track by ID
##
## Crossfades to the specified ambient track from the registry.
## Crossfades if another ambient is currently playing.
##
## @param _ambient_id: Ambient track ID to play (e.g., "exterior", "interior")
## @param _duration: Crossfade duration in seconds (default: 2.0)
func play_ambient(_ambient_id: StringName, _duration: float = 2.0) -> void:
	push_error("I_AudioManager.play_ambient not implemented")

## Stop currently playing ambient
##
## Fades out the active ambient track over the specified duration.
##
## @param _duration: Fade-out duration in seconds (default: 2.0)
func stop_ambient(_duration: float = 2.0) -> void:
	push_error("I_AudioManager.stop_ambient not implemented")
