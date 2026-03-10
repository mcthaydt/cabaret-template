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
