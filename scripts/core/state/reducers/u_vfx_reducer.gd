extends RefCounted
class_name U_VFXReducer

## VFX Reducer (Phase 0 - Task 0.4)
##
## Pure reducer functions for VFX slice state mutations. Handles screen shake
## and damage flash settings with intensity clamping (0.0-2.0 range).


const DEFAULT_VFX_STATE := {
	"screen_shake_enabled": true,
	"screen_shake_intensity": 1.0,
	"damage_flash_enabled": true,
	"particles_enabled": true,
}

const MIN_INTENSITY := 0.0
const MAX_INTENSITY := 2.0

static func get_default_vfx_state() -> Dictionary:
	return DEFAULT_VFX_STATE.duplicate(true)

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_VFX_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_VFXActions.ACTION_SET_SCREEN_SHAKE_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", true))
			return _with_values(current, {"screen_shake_enabled": enabled})

		U_VFXActions.ACTION_SET_SCREEN_SHAKE_INTENSITY:
			var payload: Dictionary = action.get("payload", {})
			var raw_intensity: float = float(payload.get("intensity", 1.0))
			var clamped_intensity := clampf(raw_intensity, MIN_INTENSITY, MAX_INTENSITY)
			return _with_values(current, {"screen_shake_intensity": clamped_intensity})

		U_VFXActions.ACTION_SET_DAMAGE_FLASH_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", true))
			return _with_values(current, {"damage_flash_enabled": enabled})

		U_VFXActions.ACTION_SET_PARTICLES_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", true))
			return _with_values(current, {"particles_enabled": enabled})

		_:
			return null

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
