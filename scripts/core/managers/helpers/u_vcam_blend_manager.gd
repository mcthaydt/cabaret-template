extends RefCounted
class_name U_VCamBlendManager

const RS_VCAM_BLEND_HINT_SCRIPT := preload("res://scripts/core/resources/display/vcam/rs_vcam_blend_hint.gd")
const U_VCAM_BLEND_EVALUATOR := preload("res://scripts/core/managers/helpers/u_vcam_blend_evaluator.gd")

const DEFAULT_TRANS_TYPE: int = Tween.TRANS_LINEAR
const DEFAULT_EASE_TYPE: int = Tween.EASE_IN_OUT
const DEFAULT_STARTUP_TRANS_TYPE: int = Tween.TRANS_CUBIC
const DEFAULT_STARTUP_EASE_TYPE: int = Tween.EASE_IN_OUT

var _blend_progress: float = 1.0
var _is_blending_active: bool = false
var _blend_duration: float = 0.0
var _blend_elapsed: float = 0.0
var _blend_trans_type: int = DEFAULT_TRANS_TYPE
var _blend_ease_type: int = DEFAULT_EASE_TYPE
var _blend_cut_on_distance_threshold: float = 0.0
var _blend_from_snapshot_result: Dictionary = {}
var _blend_hint_runtime: Resource = null
var _blend_result_cache: Dictionary = {}
var _completed_on_cut_with_publish: bool = false

var _startup_blend_pending_vcam_id: StringName = StringName("")
var _startup_blend_active: bool = false
var _startup_blend_vcam_id: StringName = StringName("")
var _startup_blend_from_transform: Transform3D = Transform3D.IDENTITY
var _startup_blend_duration_sec: float = 0.0
var _startup_blend_elapsed_sec: float = 0.0
var _startup_blend_trans_type: int = DEFAULT_STARTUP_TRANS_TYPE
var _startup_blend_ease_type: int = DEFAULT_STARTUP_EASE_TYPE
var _startup_blend_cut_on_distance_threshold: float = 0.0

func configure_transition(
	from_vcam_id: StringName,
	to_vcam_id: StringName,
	settings: Dictionary,
	reentrant_snapshot: Dictionary = {}
) -> Dictionary:
	_completed_on_cut_with_publish = false
	if from_vcam_id == to_vcam_id:
		return {}
	if to_vcam_id == StringName("") or from_vcam_id == StringName(""):
		_clear_live_blend_runtime()
		return {}

	var duration_sec: float = maxf(float(settings.get("duration_sec", 0.0)), 0.0)
	if duration_sec <= 0.0:
		var was_blending: bool = _is_blending_active
		_clear_live_blend_runtime()
		if was_blending:
			return {"status": "completed"}
		return {"status": "cut"}

	_clear_startup_blend_runtime()
	_is_blending_active = true
	_blend_duration = duration_sec
	_blend_elapsed = 0.0
	_blend_progress = 0.0
	_blend_trans_type = int(settings.get("trans_type", DEFAULT_TRANS_TYPE))
	_blend_ease_type = int(settings.get("ease_type", DEFAULT_EASE_TYPE))
	_blend_cut_on_distance_threshold = maxf(float(settings.get("cut_on_distance_threshold", 0.0)), 0.0)
	_blend_result_cache.clear()
	_blend_from_snapshot_result = (
		reentrant_snapshot.duplicate(true) if not reentrant_snapshot.is_empty() else {}
	)

	var hint := RS_VCAM_BLEND_HINT_SCRIPT.new()
	hint.trans_type = _blend_trans_type as Tween.TransitionType
	hint.ease_type = _blend_ease_type as Tween.EaseType
	hint.cut_on_distance_threshold = _blend_cut_on_distance_threshold
	_blend_hint_runtime = hint
	return {"status": "started", "duration": _blend_duration}

func advance(delta: float) -> Dictionary:
	if not _is_blending_active:
		return {}
	if _blend_duration <= 0.0:
		_clear_live_blend_runtime()
		return {"status": "completed"}

	var dt: float = maxf(delta, 0.0)
	_blend_elapsed = minf(_blend_elapsed + dt, _blend_duration)
	var next_progress: float = clampf(_blend_elapsed / _blend_duration, 0.0, 1.0)
	var did_progress: bool = not is_equal_approx(next_progress, _blend_progress)
	_blend_progress = next_progress

	if _blend_progress >= 1.0 or is_equal_approx(_blend_elapsed, _blend_duration):
		_clear_live_blend_runtime()
		return {"status": "completed"}
	if did_progress:
		return {"status": "progress", "progress": _blend_progress}
	return {}

func resolve_blend_result(from_result: Dictionary, to_result: Dictionary) -> Dictionary:
	var resolved_from: Dictionary = _blend_from_snapshot_result if has_from_snapshot_result() else from_result
	if resolved_from.is_empty() or to_result.is_empty():
		return {}

	if _should_cut_current_blend(resolved_from, to_result):
		_clear_live_blend_runtime()
		_completed_on_cut_with_publish = true
		return to_result.duplicate(true)

	var hint: Resource = _blend_hint_runtime
	if hint == null:
		var fallback_hint := RS_VCAM_BLEND_HINT_SCRIPT.new()
		fallback_hint.trans_type = _blend_trans_type as Tween.TransitionType
		fallback_hint.ease_type = _blend_ease_type as Tween.EaseType
		fallback_hint.cut_on_distance_threshold = _blend_cut_on_distance_threshold
		hint = fallback_hint

	var blended: Dictionary = U_VCAM_BLEND_EVALUATOR.blend(
		resolved_from,
		to_result,
		hint,
		_blend_progress
	)
	_blend_result_cache.clear()
	for key in blended.keys():
		_blend_result_cache[key] = blended[key]
	return _blend_result_cache

func recover_invalid_members(has_to_vcam: bool, has_from_vcam: bool) -> Dictionary:
	if not _is_blending_active:
		return {}
	if has_from_vcam and has_to_vcam:
		return {}

	var reason: String = "blend_both_invalid"
	var publish_completed_event: bool = false
	if has_to_vcam and not has_from_vcam:
		reason = "blend_from_invalid"
		publish_completed_event = true
	elif has_from_vcam and not has_to_vcam:
		reason = "blend_to_invalid"

	_clear_live_blend_runtime()
	return {
		"status": "completed",
		"reason": reason,
		"publish_completed_event": publish_completed_event,
	}

func queue_startup_blend(next_vcam_id: StringName, previous_vcam_id: StringName) -> void:
	_clear_startup_blend_runtime()
	_startup_blend_pending_vcam_id = StringName("")
	if next_vcam_id == StringName(""):
		return
	if previous_vcam_id == StringName(""):
		_startup_blend_pending_vcam_id = next_vcam_id

func start_startup_blend_if_pending(
	vcam_id: StringName,
	main_camera_transform: Transform3D,
	settings: Dictionary
) -> bool:
	if vcam_id == StringName(""):
		return false
	if _startup_blend_active:
		return false
	if _startup_blend_pending_vcam_id != vcam_id:
		return false
	var duration_sec: float = maxf(float(settings.get("duration_sec", 0.0)), 0.0)
	if duration_sec <= 0.0:
		_startup_blend_pending_vcam_id = StringName("")
		return false

	_startup_blend_active = true
	_startup_blend_vcam_id = vcam_id
	_startup_blend_from_transform = main_camera_transform
	_startup_blend_duration_sec = duration_sec
	_startup_blend_elapsed_sec = 0.0
	_startup_blend_trans_type = int(settings.get("trans_type", DEFAULT_STARTUP_TRANS_TYPE))
	_startup_blend_ease_type = int(settings.get("ease_type", DEFAULT_STARTUP_EASE_TYPE))
	_startup_blend_cut_on_distance_threshold = maxf(
		float(settings.get("cut_on_distance_threshold", 0.0)),
		0.0
	)
	_startup_blend_pending_vcam_id = StringName("")
	return true

func resolve_startup_transform(
	vcam_id: StringName,
	target_transform: Transform3D,
	last_physics_delta: float
) -> Transform3D:
	if not _startup_blend_active:
		return target_transform
	if _startup_blend_vcam_id != vcam_id:
		_clear_startup_blend_runtime()
		return target_transform

	var distance_to_target: float = _startup_blend_from_transform.origin.distance_to(target_transform.origin)
	if (
		_startup_blend_cut_on_distance_threshold > 0.0
		and distance_to_target > _startup_blend_cut_on_distance_threshold
	):
		_clear_startup_blend_runtime()
		return target_transform
	if _startup_blend_duration_sec <= 0.0:
		_clear_startup_blend_runtime()
		return target_transform

	var dt: float = last_physics_delta
	if dt <= 0.0:
		dt = 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	_startup_blend_elapsed_sec = minf(_startup_blend_elapsed_sec + dt, _startup_blend_duration_sec)
	var weight: float = _compute_startup_blend_weight(
		_startup_blend_elapsed_sec,
		_startup_blend_duration_sec,
		_startup_blend_trans_type,
		_startup_blend_ease_type
	)

	var from_basis: Basis = _startup_blend_from_transform.basis.orthonormalized()
	var to_basis: Basis = target_transform.basis.orthonormalized()
	var blended_basis: Basis = from_basis.slerp(to_basis, weight).orthonormalized()
	var blended_origin: Vector3 = _startup_blend_from_transform.origin.lerp(target_transform.origin, weight)
	var blended_transform := Transform3D(blended_basis, blended_origin)

	if _startup_blend_elapsed_sec >= _startup_blend_duration_sec:
		_clear_startup_blend_runtime()
		return target_transform
	return blended_transform

func clear() -> void:
	_clear_live_blend_runtime()
	_clear_startup_blend_state()

func consume_completed_on_cut_with_publish() -> bool:
	var completed_on_cut: bool = _completed_on_cut_with_publish
	_completed_on_cut_with_publish = false
	return completed_on_cut

func is_active() -> bool:
	return _is_blending_active

func get_progress() -> float:
	return _blend_progress

func has_from_snapshot_result() -> bool:
	return not _blend_from_snapshot_result.is_empty()

func get_transition_type() -> int:
	return _blend_trans_type

func get_ease_type() -> int:
	return _blend_ease_type

func get_cut_on_distance_threshold() -> float:
	return _blend_cut_on_distance_threshold

func is_startup_blending() -> bool:
	return _startup_blend_active

func get_startup_pending_vcam_id() -> StringName:
	return _startup_blend_pending_vcam_id

func _should_cut_current_blend(from_result: Dictionary, to_result: Dictionary) -> bool:
	if _blend_cut_on_distance_threshold <= 0.0:
		return false
	var from_transform_variant: Variant = from_result.get("transform", null)
	var to_transform_variant: Variant = to_result.get("transform", null)
	if not (from_transform_variant is Transform3D) or not (to_transform_variant is Transform3D):
		return false
	var from_transform := from_transform_variant as Transform3D
	var to_transform := to_transform_variant as Transform3D
	var distance: float = from_transform.origin.distance_to(to_transform.origin)
	return distance > _blend_cut_on_distance_threshold

func _compute_startup_blend_weight(
	elapsed_sec: float,
	duration_sec: float,
	trans_type: int,
	ease_type: int
) -> float:
	if duration_sec <= 0.0:
		return 1.0
	var eased_value: Variant = Tween.interpolate_value(
		0.0,
		1.0,
		clampf(elapsed_sec, 0.0, duration_sec),
		duration_sec,
		trans_type,
		ease_type
	)
	if eased_value is float or eased_value is int:
		return clampf(float(eased_value), 0.0, 1.0)
	return clampf(elapsed_sec / duration_sec, 0.0, 1.0)

func _clear_live_blend_runtime() -> void:
	_blend_progress = 1.0
	_is_blending_active = false
	_blend_duration = 0.0
	_blend_elapsed = 0.0
	_blend_trans_type = DEFAULT_TRANS_TYPE
	_blend_ease_type = DEFAULT_EASE_TYPE
	_blend_cut_on_distance_threshold = 0.0
	_blend_from_snapshot_result.clear()
	_blend_result_cache.clear()
	_blend_hint_runtime = null

func _clear_startup_blend_runtime() -> void:
	_startup_blend_active = false
	_startup_blend_vcam_id = StringName("")
	_startup_blend_from_transform = Transform3D.IDENTITY
	_startup_blend_duration_sec = 0.0
	_startup_blend_elapsed_sec = 0.0
	_startup_blend_trans_type = DEFAULT_STARTUP_TRANS_TYPE
	_startup_blend_ease_type = DEFAULT_STARTUP_EASE_TYPE
	_startup_blend_cut_on_distance_threshold = 0.0

func _clear_startup_blend_state() -> void:
	_startup_blend_pending_vcam_id = StringName("")
	_clear_startup_blend_runtime()

