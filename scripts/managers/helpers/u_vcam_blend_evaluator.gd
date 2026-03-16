extends RefCounted
class_name U_VCamBlendEvaluator

const RS_VCAM_BLEND_HINT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_blend_hint.gd")

const DEFAULT_TRANS_TYPE: int = Tween.TRANS_LINEAR
const DEFAULT_EASE_TYPE: int = Tween.EASE_IN_OUT

static func blend(from_result: Dictionary, to_result: Dictionary, hint: Resource, progress: float) -> Dictionary:
	if from_result.is_empty():
		return to_result.duplicate(true)
	if to_result.is_empty():
		return from_result.duplicate(true)

	var from_transform: Variant = from_result.get("transform", null)
	var to_transform: Variant = to_result.get("transform", null)
	if not (from_transform is Transform3D) or not (to_transform is Transform3D):
		return to_result.duplicate(true)

	var resolved_hint: Dictionary = _resolve_hint(hint)
	var from_xform: Transform3D = from_transform as Transform3D
	var to_xform: Transform3D = to_transform as Transform3D
	var cut_distance: float = float(resolved_hint.get("cut_on_distance_threshold", 0.0))
	if cut_distance > 0.0 and from_xform.origin.distance_to(to_xform.origin) > cut_distance:
		return to_result.duplicate(true)

	var t: float = _resolve_weight(
		clampf(progress, 0.0, 1.0),
		int(resolved_hint.get("trans_type", DEFAULT_TRANS_TYPE)),
		int(resolved_hint.get("ease_type", DEFAULT_EASE_TYPE))
	)

	var blended_basis: Basis = from_xform.basis.orthonormalized().slerp(
		to_xform.basis.orthonormalized(),
		t
	).orthonormalized()
	var blended_origin: Vector3 = from_xform.origin.lerp(to_xform.origin, t)
	var blended_transform := Transform3D(blended_basis, blended_origin)

	var blended: Dictionary = to_result.duplicate(true)
	blended["transform"] = blended_transform
	blended["fov"] = _blend_fov(from_result, to_result, t)
	if not blended.has("mode_name") and from_result.has("mode_name"):
		blended["mode_name"] = from_result.get("mode_name", "")
	return blended

static func _blend_fov(from_result: Dictionary, to_result: Dictionary, t: float) -> float:
	var has_from_fov: bool = from_result.has("fov")
	var has_to_fov: bool = to_result.has("fov")
	if has_from_fov and has_to_fov:
		return lerpf(float(from_result.get("fov", 0.0)), float(to_result.get("fov", 0.0)), t)
	if has_to_fov:
		return float(to_result.get("fov", 0.0))
	if has_from_fov:
		return float(from_result.get("fov", 0.0))
	return 75.0

static func _resolve_hint(hint: Resource) -> Dictionary:
	var resolved: Dictionary = {
		"trans_type": DEFAULT_TRANS_TYPE,
		"ease_type": DEFAULT_EASE_TYPE,
		"cut_on_distance_threshold": 0.0,
	}
	if hint == null:
		return resolved
	if hint.get_script() != RS_VCAM_BLEND_HINT_SCRIPT:
		return resolved
	resolved["trans_type"] = int(hint.get("trans_type"))
	resolved["ease_type"] = int(hint.get("ease_type"))
	resolved["cut_on_distance_threshold"] = maxf(float(hint.get("cut_on_distance_threshold")), 0.0)
	return resolved

static func _resolve_weight(progress: float, trans_type: int, ease_type: int) -> float:
	var eased: Variant = Tween.interpolate_value(0.0, 1.0, progress, 1.0, trans_type, ease_type)
	if eased is float or eased is int:
		return clampf(float(eased), 0.0, 1.0)
	return progress
