extends GutTest

const RESPONSE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")

func _new_response() -> Resource:
	return RESPONSE_SCRIPT.new()

func test_follow_frequency_default_is_three() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("follow_frequency")), 3.0, 0.0001)

func test_follow_damping_default_is_point_seven() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("follow_damping")), 0.7, 0.0001)

func test_follow_initial_response_default_is_one() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("follow_initial_response")), 1.0, 0.0001)

func test_rotation_frequency_default_is_four() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("rotation_frequency")), 4.0, 0.0001)

func test_rotation_damping_default_is_one() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("rotation_damping")), 1.0, 0.0001)

func test_rotation_initial_response_default_is_one() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("rotation_initial_response")), 1.0, 0.0001)

func test_look_ahead_defaults_are_zero_distance_and_three_hz_smoothing() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("look_ahead_distance")), 0.0, 0.0001)
	assert_almost_eq(float(response.get("look_ahead_smoothing")), 3.0, 0.0001)

func test_auto_level_defaults_are_zero_speed_and_one_second_delay() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("auto_level_speed")), 0.0, 0.0001)
	assert_almost_eq(float(response.get("auto_level_delay")), 1.0, 0.0001)

func test_look_input_filter_defaults_match_expected_values() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("look_input_deadzone")), 0.02, 0.0001)
	assert_almost_eq(float(response.get("look_input_hold_sec")), 0.06, 0.0001)
	assert_almost_eq(float(response.get("look_input_release_decay")), 25.0, 0.0001)

func test_orbit_bypass_speed_defaults_are_expected() -> void:
	var response := _new_response()
	assert_almost_eq(float(response.get("orbit_look_bypass_enable_speed")), 0.15, 0.0001)
	assert_almost_eq(float(response.get("orbit_look_bypass_disable_speed")), 0.3, 0.0001)

func test_frequency_values_are_clamped_to_positive_minimum() -> void:
	var response := _new_response()
	response.set("follow_frequency", 0.0)
	response.set("rotation_frequency", -5.0)
	var resolved := response.call("get_resolved_values") as Dictionary
	assert_true(float(resolved.get("follow_frequency", 0.0)) > 0.0)
	assert_true(float(resolved.get("rotation_frequency", 0.0)) > 0.0)

func test_damping_values_are_clamped_to_non_negative() -> void:
	var response := _new_response()
	response.set("follow_damping", -0.5)
	response.set("rotation_damping", -0.5)
	var resolved := response.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved.get("follow_damping", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("rotation_damping", -1.0)), 0.0, 0.0001)

func test_look_ahead_and_auto_level_values_are_clamped_to_non_negative() -> void:
	var response := _new_response()
	response.set("look_ahead_distance", -1.0)
	response.set("look_ahead_smoothing", -4.0)
	response.set("auto_level_speed", -5.0)
	response.set("auto_level_delay", -2.0)
	var resolved := response.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved.get("look_ahead_distance", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("look_ahead_smoothing", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("auto_level_speed", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("auto_level_delay", -1.0)), 0.0, 0.0001)

func test_look_input_filter_values_are_clamped_to_non_negative() -> void:
	var response := _new_response()
	response.set("look_input_deadzone", -1.0)
	response.set("look_input_hold_sec", -2.0)
	response.set("look_input_release_decay", -3.0)
	var resolved := response.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved.get("look_input_deadzone", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("look_input_hold_sec", -1.0)), 0.0, 0.0001)
	assert_almost_eq(float(resolved.get("look_input_release_decay", -1.0)), 0.0, 0.0001)

func test_orbit_bypass_disable_speed_is_clamped_to_enable_speed_floor() -> void:
	var response := _new_response()
	response.set("orbit_look_bypass_enable_speed", 0.4)
	response.set("orbit_look_bypass_disable_speed", 0.1)
	var resolved := response.call("get_resolved_values") as Dictionary
	assert_almost_eq(float(resolved.get("orbit_look_bypass_enable_speed", -1.0)), 0.4, 0.0001)
	assert_almost_eq(float(resolved.get("orbit_look_bypass_disable_speed", -1.0)), 0.4, 0.0001)
