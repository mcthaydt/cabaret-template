extends GutTest

const BLEND_HINT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_blend_hint.gd")

func _new_blend_hint() -> Resource:
	return BLEND_HINT_SCRIPT.new()

func test_blend_duration_default_is_one_second() -> void:
	var blend_hint := _new_blend_hint()
	assert_almost_eq(float(blend_hint.get("blend_duration")), 1.0, 0.0001)

func test_ease_type_default_is_ease_in_out() -> void:
	var blend_hint := _new_blend_hint()
	assert_eq(int(blend_hint.get("ease_type")), int(Tween.EASE_IN_OUT))

func test_trans_type_default_is_trans_cubic() -> void:
	var blend_hint := _new_blend_hint()
	assert_eq(int(blend_hint.get("trans_type")), int(Tween.TRANS_CUBIC))

func test_cut_on_distance_threshold_default_is_zero() -> void:
	var blend_hint := _new_blend_hint()
	assert_almost_eq(float(blend_hint.get("cut_on_distance_threshold")), 0.0, 0.0001)

func test_blend_duration_is_non_negative() -> void:
	var blend_hint := _new_blend_hint()
	assert_true(float(blend_hint.get("blend_duration")) >= 0.0)

func test_cut_on_distance_threshold_is_non_negative() -> void:
	var blend_hint := _new_blend_hint()
	assert_true(float(blend_hint.get("cut_on_distance_threshold")) >= 0.0)

func test_zero_blend_duration_means_instant_cut() -> void:
	var blend_hint := _new_blend_hint()
	blend_hint.set("blend_duration", 0.0)
	assert_true(blend_hint.call("is_instant_cut"))
