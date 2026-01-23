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
