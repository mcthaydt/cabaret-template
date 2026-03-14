extends GutTest

const ROOM_FADE_SETTINGS_SCRIPT := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")

func _new_settings() -> Resource:
	return ROOM_FADE_SETTINGS_SCRIPT.new()

func test_fade_dot_threshold_default_is_point_three() -> void:
	var settings := _new_settings()
	assert_almost_eq(float(settings.get("fade_dot_threshold")), 0.3, 0.0001)

func test_fade_speed_default_is_four() -> void:
	var settings := _new_settings()
	assert_almost_eq(float(settings.get("fade_speed")), 4.0, 0.0001)

func test_min_alpha_default_is_point_zero_five() -> void:
	var settings := _new_settings()
	assert_almost_eq(float(settings.get("min_alpha")), 0.05, 0.0001)

func test_fade_dot_threshold_is_clamped_to_zero_to_one() -> void:
	var settings := _new_settings()
	settings.set("fade_dot_threshold", 5.0)
	var resolved_hi := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved_hi.get("fade_dot_threshold", -1.0)), 1.0, 0.0001)
	settings.set("fade_dot_threshold", -3.0)
	var resolved_lo := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved_lo.get("fade_dot_threshold", -1.0)), 0.0, 0.0001)

func test_fade_speed_is_clamped_non_negative() -> void:
	var settings := _new_settings()
	settings.set("fade_speed", -2.0)
	var resolved := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved.get("fade_speed", -1.0)), 0.0, 0.0001)

func test_min_alpha_is_clamped_to_zero_to_one() -> void:
	var settings := _new_settings()
	settings.set("min_alpha", 2.0)
	var resolved_hi := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved_hi.get("min_alpha", -1.0)), 1.0, 0.0001)
	settings.set("min_alpha", -2.0)
	var resolved_lo := settings.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved_lo.get("min_alpha", -1.0)), 0.0, 0.0001)

func test_resolved_values_contains_expected_keys() -> void:
	var settings := _new_settings()
	var resolved := settings.call("get_resolved_values") as Dictionary
	assert_true(resolved.has("fade_dot_threshold"))
	assert_true(resolved.has("fade_speed"))
	assert_true(resolved.has("min_alpha"))
