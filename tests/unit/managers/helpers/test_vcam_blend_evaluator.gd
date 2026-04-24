extends GutTest

const BLEND_EVALUATOR := preload("res://scripts/core/managers/helpers/u_vcam_blend_evaluator.gd")
const RS_VCAM_BLEND_HINT := preload("res://scripts/resources/display/vcam/rs_vcam_blend_hint.gd")

func test_blend_at_zero_progress_returns_from_transform() -> void:
	var from_result: Dictionary = _make_result(Vector3.ZERO, 80.0)
	var to_result: Dictionary = _make_result(Vector3(10.0, 0.0, 0.0), 60.0)

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, to_result, null, 0.0)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(blended_transform.origin.x, 0.0, 0.0001)
	assert_almost_eq(float(blended.get("fov", 0.0)), 80.0, 0.0001)

func test_blend_at_one_progress_returns_to_transform() -> void:
	var from_result: Dictionary = _make_result(Vector3.ZERO, 80.0)
	var to_result: Dictionary = _make_result(Vector3(10.0, 0.0, 0.0), 60.0)

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, to_result, null, 1.0)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(blended_transform.origin.x, 10.0, 0.0001)
	assert_almost_eq(float(blended.get("fov", 0.0)), 60.0, 0.0001)

func test_blend_at_half_progress_interpolates_transform() -> void:
	var from_result: Dictionary = _make_result(Vector3(0.0, 2.0, 0.0), 80.0)
	var to_result: Dictionary = _make_result(Vector3(10.0, 6.0, 0.0), 60.0)

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, to_result, null, 0.5)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(blended_transform.origin.x, 5.0, 0.0001)
	assert_almost_eq(blended_transform.origin.y, 4.0, 0.0001)

func test_blend_interpolates_fov_between_from_and_to() -> void:
	var from_result: Dictionary = _make_result(Vector3.ZERO, 90.0)
	var to_result: Dictionary = _make_result(Vector3(5.0, 0.0, 0.0), 70.0)

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, to_result, null, 0.25)

	assert_almost_eq(float(blended.get("fov", 0.0)), 85.0, 0.0001)

func test_blend_applies_ease_type_from_hint() -> void:
	var from_result: Dictionary = _make_result(Vector3.ZERO, 80.0)
	var to_result: Dictionary = _make_result(Vector3(10.0, 0.0, 0.0), 60.0)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.trans_type = Tween.TRANS_CUBIC
	hint.ease_type = Tween.EASE_OUT

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, to_result, hint, 0.5)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_gt(blended_transform.origin.x, 5.0)

func test_blend_cuts_when_distance_threshold_exceeded() -> void:
	var from_result: Dictionary = _make_result(Vector3.ZERO, 80.0)
	var to_result: Dictionary = _make_result(Vector3(20.0, 0.0, 0.0), 60.0)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.cut_on_distance_threshold = 5.0

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, to_result, hint, 0.1)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(blended_transform.origin.x, 20.0, 0.0001)
	assert_almost_eq(float(blended.get("fov", 0.0)), 60.0, 0.0001)

func test_blend_does_not_cut_when_distance_threshold_not_exceeded() -> void:
	var from_result: Dictionary = _make_result(Vector3.ZERO, 80.0)
	var to_result: Dictionary = _make_result(Vector3(1.0, 0.0, 0.0), 60.0)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.cut_on_distance_threshold = 5.0

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, to_result, hint, 0.5)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_true(blended_transform.origin.x > 0.0 and blended_transform.origin.x < 1.0)

func test_blend_with_null_hint_defaults_to_linear() -> void:
	var from_result: Dictionary = _make_result(Vector3.ZERO, 80.0)
	var to_result: Dictionary = _make_result(Vector3(8.0, 0.0, 0.0), 60.0)

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, to_result, null, 0.5)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(blended_transform.origin.x, 4.0, 0.0001)

func test_blend_with_empty_from_result_returns_to_result() -> void:
	var to_result: Dictionary = _make_result(Vector3(5.0, 1.0, -2.0), 63.0)

	var blended: Dictionary = BLEND_EVALUATOR.blend({}, to_result, null, 0.5)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(blended_transform.origin.x, 5.0, 0.0001)
	assert_almost_eq(float(blended.get("fov", 0.0)), 63.0, 0.0001)

func test_blend_with_empty_to_result_returns_from_result() -> void:
	var from_result: Dictionary = _make_result(Vector3(2.0, 3.0, 4.0), 77.0)

	var blended: Dictionary = BLEND_EVALUATOR.blend(from_result, {}, null, 0.5)
	var blended_transform: Transform3D = blended.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(blended_transform.origin.x, 2.0, 0.0001)
	assert_almost_eq(float(blended.get("fov", 0.0)), 77.0, 0.0001)

func _make_result(position: Vector3, fov: float) -> Dictionary:
	return {
		"transform": Transform3D(Basis.IDENTITY, position),
		"fov": fov,
		"mode_name": "orbit",
	}
