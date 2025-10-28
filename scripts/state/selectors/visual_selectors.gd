extends RefCounted
class_name VisualSelectors

## Visual/audio state selectors for gameplay slice
##
## Phase 16: Created for full project integration
## Used by visual and audio systems to read settings

## Check if landing indicator should be shown
static func should_show_landing_indicator(state: Dictionary) -> bool:
	return state.get("gameplay", {}).get("show_landing_indicator", true)

## Get particle settings
static func get_particle_settings(state: Dictionary) -> Dictionary:
	return state.get("gameplay", {}).get("particle_settings", {
		"jump_particles_enabled": true,
		"landing_particles_enabled": true
	})

## Get audio settings
static func get_audio_settings(state: Dictionary) -> Dictionary:
	return state.get("gameplay", {}).get("audio_settings", {
		"jump_sound_enabled": true,
		"volume": 1.0,
		"pitch_scale": 1.0
	})

## Check if jump particles are enabled
static func are_jump_particles_enabled(state: Dictionary) -> bool:
	var settings: Dictionary = get_particle_settings(state)
	return settings.get("jump_particles_enabled", true)

## Check if landing particles are enabled
static func are_landing_particles_enabled(state: Dictionary) -> bool:
	var settings: Dictionary = get_particle_settings(state)
	return settings.get("landing_particles_enabled", true)

## Check if jump sound is enabled
static func is_jump_sound_enabled(state: Dictionary) -> bool:
	var settings: Dictionary = get_audio_settings(state)
	return settings.get("jump_sound_enabled", true)

## Get audio volume
static func get_audio_volume(state: Dictionary) -> float:
	var settings: Dictionary = get_audio_settings(state)
	return settings.get("volume", 1.0)

## Get audio pitch scale
static func get_audio_pitch_scale(state: Dictionary) -> float:
	var settings: Dictionary = get_audio_settings(state)
	return settings.get("pitch_scale", 1.0)
