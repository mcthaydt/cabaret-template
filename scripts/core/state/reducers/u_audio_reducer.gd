extends RefCounted
class_name U_AudioReducer

## Audio Reducer (Audio Manager Phase 0 - Task 0.4)
##
## Pure reducer functions for audio slice state mutations. Handles volume
## clamping (0.0-1.0), mute toggles, and spatial audio flag.


const DEFAULT_AUDIO_STATE := {
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"ambient_volume": 1.0,
	"master_muted": false,
	"music_muted": false,
	"sfx_muted": false,
	"ambient_muted": false,
	"spatial_audio_enabled": true,
}

static func get_default_audio_state() -> Dictionary:
	return DEFAULT_AUDIO_STATE.duplicate(true)

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_AUDIO_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_AudioActions.ACTION_SET_MASTER_VOLUME:
			var volume := _get_volume_from_action(action)
			return _with_values(current, {"master_volume": volume})

		U_AudioActions.ACTION_SET_MUSIC_VOLUME:
			var volume := _get_volume_from_action(action)
			return _with_values(current, {"music_volume": volume})

		U_AudioActions.ACTION_SET_SFX_VOLUME:
			var volume := _get_volume_from_action(action)
			return _with_values(current, {"sfx_volume": volume})

		U_AudioActions.ACTION_SET_AMBIENT_VOLUME:
			var volume := _get_volume_from_action(action)
			return _with_values(current, {"ambient_volume": volume})

		U_AudioActions.ACTION_SET_MASTER_MUTED:
			var muted := _get_muted_from_action(action)
			return _with_values(current, {"master_muted": muted})

		U_AudioActions.ACTION_SET_MUSIC_MUTED:
			var muted := _get_muted_from_action(action)
			return _with_values(current, {"music_muted": muted})

		U_AudioActions.ACTION_SET_SFX_MUTED:
			var muted := _get_muted_from_action(action)
			return _with_values(current, {"sfx_muted": muted})

		U_AudioActions.ACTION_SET_AMBIENT_MUTED:
			var muted := _get_muted_from_action(action)
			return _with_values(current, {"ambient_muted": muted})

		U_AudioActions.ACTION_SET_SPATIAL_AUDIO_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", true))
			return _with_values(current, {"spatial_audio_enabled": enabled})

		U_AudioActions.ACTION_TOGGLE_MASTER_MUTE:
			return _with_values(current, {"master_muted": not bool(current.get("master_muted", false))})

		U_AudioActions.ACTION_TOGGLE_MUSIC_MUTE:
			return _with_values(current, {"music_muted": not bool(current.get("music_muted", false))})

		U_AudioActions.ACTION_TOGGLE_SFX_MUTE:
			return _with_values(current, {"sfx_muted": not bool(current.get("sfx_muted", false))})

		_:
			return null

static func _get_volume_from_action(action: Dictionary) -> float:
	var payload: Dictionary = action.get("payload", {})
	var raw_volume: float = float(payload.get("volume", 1.0))
	return clampf(raw_volume, 0.0, 1.0)

static func _get_muted_from_action(action: Dictionary) -> bool:
	var payload: Dictionary = action.get("payload", {})
	return bool(payload.get("muted", false))

static func _merge_with_defaults(defaults: Dictionary, state: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	if state == null:
		return merged
	for key in state.keys():
		merged[key] = _deep_copy(state[key])
	return merged

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	for key in updates.keys():
		next[key] = _deep_copy(updates[key])
	return next

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

