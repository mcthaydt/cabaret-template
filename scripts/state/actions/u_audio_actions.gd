extends RefCounted
class_name U_AudioActions

## Audio Actions (Audio Manager Phase 0 - Task 0.4)
##
## Action creators for Audio slice mutations. All actions are registered with
## U_ActionRegistry for validation and dispatched via M_StateStore.

const U_ActionRegistry := preload("res://scripts/state/utils/u_action_registry.gd")

const ACTION_SET_MASTER_VOLUME := StringName("audio/set_master_volume")
const ACTION_SET_MUSIC_VOLUME := StringName("audio/set_music_volume")
const ACTION_SET_SFX_VOLUME := StringName("audio/set_sfx_volume")
const ACTION_SET_AMBIENT_VOLUME := StringName("audio/set_ambient_volume")

const ACTION_SET_MASTER_MUTED := StringName("audio/set_master_muted")
const ACTION_SET_MUSIC_MUTED := StringName("audio/set_music_muted")
const ACTION_SET_SFX_MUTED := StringName("audio/set_sfx_muted")
const ACTION_SET_AMBIENT_MUTED := StringName("audio/set_ambient_muted")

const ACTION_SET_SPATIAL_AUDIO_ENABLED := StringName("audio/set_spatial_audio_enabled")

const ACTION_TOGGLE_MASTER_MUTE := StringName("audio/toggle_master_mute")
const ACTION_TOGGLE_MUSIC_MUTE := StringName("audio/toggle_music_mute")
const ACTION_TOGGLE_SFX_MUTE := StringName("audio/toggle_sfx_mute")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_MASTER_VOLUME)
	U_ActionRegistry.register_action(ACTION_SET_MUSIC_VOLUME)
	U_ActionRegistry.register_action(ACTION_SET_SFX_VOLUME)
	U_ActionRegistry.register_action(ACTION_SET_AMBIENT_VOLUME)
	U_ActionRegistry.register_action(ACTION_SET_MASTER_MUTED)
	U_ActionRegistry.register_action(ACTION_SET_MUSIC_MUTED)
	U_ActionRegistry.register_action(ACTION_SET_SFX_MUTED)
	U_ActionRegistry.register_action(ACTION_SET_AMBIENT_MUTED)
	U_ActionRegistry.register_action(ACTION_SET_SPATIAL_AUDIO_ENABLED)
	U_ActionRegistry.register_action(ACTION_TOGGLE_MASTER_MUTE)
	U_ActionRegistry.register_action(ACTION_TOGGLE_MUSIC_MUTE)
	U_ActionRegistry.register_action(ACTION_TOGGLE_SFX_MUTE)

static func set_master_volume(volume: float) -> Dictionary:
	return {
		"type": ACTION_SET_MASTER_VOLUME,
		"payload": {"volume": volume},
		"immediate": true,
	}

static func set_music_volume(volume: float) -> Dictionary:
	return {
		"type": ACTION_SET_MUSIC_VOLUME,
		"payload": {"volume": volume},
		"immediate": true,
	}

static func set_sfx_volume(volume: float) -> Dictionary:
	return {
		"type": ACTION_SET_SFX_VOLUME,
		"payload": {"volume": volume},
		"immediate": true,
	}

static func set_ambient_volume(volume: float) -> Dictionary:
	return {
		"type": ACTION_SET_AMBIENT_VOLUME,
		"payload": {"volume": volume},
		"immediate": true,
	}

static func set_master_muted(muted: bool) -> Dictionary:
	return {
		"type": ACTION_SET_MASTER_MUTED,
		"payload": {"muted": muted},
		"immediate": true,
	}

static func set_music_muted(muted: bool) -> Dictionary:
	return {
		"type": ACTION_SET_MUSIC_MUTED,
		"payload": {"muted": muted},
		"immediate": true,
	}

static func set_sfx_muted(muted: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SFX_MUTED,
		"payload": {"muted": muted},
		"immediate": true,
	}

static func set_ambient_muted(muted: bool) -> Dictionary:
	return {
		"type": ACTION_SET_AMBIENT_MUTED,
		"payload": {"muted": muted},
		"immediate": true,
	}

static func set_spatial_audio_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SPATIAL_AUDIO_ENABLED,
		"payload": {"enabled": enabled},
		"immediate": true,
	}

static func toggle_master_mute() -> Dictionary:
	return {
		"type": ACTION_TOGGLE_MASTER_MUTE,
		"payload": null,
		"immediate": true,
	}

static func toggle_music_mute() -> Dictionary:
	return {
		"type": ACTION_TOGGLE_MUSIC_MUTE,
		"payload": null,
		"immediate": true,
	}

static func toggle_sfx_mute() -> Dictionary:
	return {
		"type": ACTION_TOGGLE_SFX_MUTE,
		"payload": null,
		"immediate": true,
	}

