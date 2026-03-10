extends RefCounted
class_name U_VCamReducer

## Reducer for transient vCam runtime observability state.

const DEFAULT_VCAM_STATE := {
	"active_vcam_id": StringName(""),
	"active_mode": "",
	"previous_vcam_id": StringName(""),
	"blend_progress": 1.0,
	"is_blending": false,
	"silhouette_active_count": 0,
	"blend_from_vcam_id": StringName(""),
	"blend_to_vcam_id": StringName(""),
	"active_target_valid": true,
	"last_recovery_reason": "",
	"in_fov_zone": false,
}

static func get_default_vcam_state() -> Dictionary:
	return DEFAULT_VCAM_STATE.duplicate(true)

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var current := _merge_with_defaults(DEFAULT_VCAM_STATE, state)
	var action_type: Variant = action.get("type")
	var payload_variant: Variant = action.get("payload", {})
	var payload: Dictionary = payload_variant as Dictionary if payload_variant is Dictionary else {}

	match action_type:
		U_VCamActions.ACTION_SET_ACTIVE_RUNTIME:
			return _with_values(current, {
				"active_vcam_id": _to_string_name(payload.get("vcam_id", StringName(""))),
				"active_mode": str(payload.get("mode", "")),
			})

		U_VCamActions.ACTION_START_BLEND:
			var previous_vcam_id := _to_string_name(payload.get("previous_vcam_id", StringName("")))
			return _with_values(current, {
				"is_blending": true,
				"blend_progress": 0.0,
				"previous_vcam_id": previous_vcam_id,
				"blend_from_vcam_id": previous_vcam_id,
				"blend_to_vcam_id": _to_string_name(current.get("active_vcam_id", StringName(""))),
			})

		U_VCamActions.ACTION_UPDATE_BLEND:
			var raw_progress: float = float(payload.get("progress", 1.0))
			return _with_values(current, {
				"blend_progress": clampf(raw_progress, 0.0, 1.0),
			})

		U_VCamActions.ACTION_COMPLETE_BLEND:
			return _with_values(current, {
				"is_blending": false,
				"blend_progress": 1.0,
				"previous_vcam_id": StringName(""),
				"blend_from_vcam_id": StringName(""),
				"blend_to_vcam_id": StringName(""),
			})

		U_VCamActions.ACTION_UPDATE_SILHOUETTE_COUNT:
			return _with_values(current, {
				"silhouette_active_count": maxi(int(payload.get("count", 0)), 0),
			})

		U_VCamActions.ACTION_UPDATE_TARGET_VALIDITY:
			return _with_values(current, {
				"active_target_valid": bool(payload.get("valid", true)),
			})

		U_VCamActions.ACTION_RECORD_RECOVERY:
			return _with_values(current, {
				"last_recovery_reason": str(payload.get("reason", "")),
			})

		U_VCamActions.ACTION_UPDATE_FOV_ZONE:
			return _with_values(current, {
				"in_fov_zone": bool(payload.get("in_zone", false)),
			})

		_:
			return current

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

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value as StringName
	return StringName(str(value))
