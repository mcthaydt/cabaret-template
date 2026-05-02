extends RefCounted
class_name U_VCamSelectors

## Pure selectors for transient vCam runtime observability state.

static func _get_vcam_slice(state: Dictionary) -> Dictionary:
	var value: Variant = state.get("vcam", null)
	if value is Dictionary:
		return value as Dictionary
	return {}

static func get_active_vcam_id(state: Dictionary) -> StringName:
	var vcam := _get_vcam_slice(state)
	return vcam.get("active_vcam_id", StringName(""))

static func get_active_mode(state: Dictionary) -> String:
	var vcam := _get_vcam_slice(state)
	return str(vcam.get("active_mode", ""))

static func get_previous_vcam_id(state: Dictionary) -> StringName:
	var vcam := _get_vcam_slice(state)
	return vcam.get("previous_vcam_id", StringName(""))

static func get_blend_progress(state: Dictionary) -> float:
	var vcam := _get_vcam_slice(state)
	return float(vcam.get("blend_progress", 1.0))

static func is_blending(state: Dictionary) -> bool:
	var vcam := _get_vcam_slice(state)
	return bool(vcam.get("is_blending", false))

static func get_silhouette_active_count(state: Dictionary) -> int:
	var vcam := _get_vcam_slice(state)
	return int(vcam.get("silhouette_active_count", 0))

static func get_blend_from_vcam_id(state: Dictionary) -> StringName:
	var vcam := _get_vcam_slice(state)
	return vcam.get("blend_from_vcam_id", StringName(""))

static func get_blend_to_vcam_id(state: Dictionary) -> StringName:
	var vcam := _get_vcam_slice(state)
	return vcam.get("blend_to_vcam_id", StringName(""))

static func is_active_target_valid(state: Dictionary) -> bool:
	var vcam := _get_vcam_slice(state)
	return bool(vcam.get("active_target_valid", true))

static func get_last_recovery_reason(state: Dictionary) -> String:
	var vcam := _get_vcam_slice(state)
	return str(vcam.get("last_recovery_reason", ""))

static func is_in_fov_zone(state: Dictionary) -> bool:
	var vcam := _get_vcam_slice(state)
	return bool(vcam.get("in_fov_zone", false))
