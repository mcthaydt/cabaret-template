extends GutTest

const RS_GamepadSettings := preload("res://scripts/resources/input/rs_gamepad_settings.gd")

func test_defaults_match_spec() -> void:
	var settings := RS_GamepadSettings.new()
	assert_almost_eq(settings.left_stick_deadzone, 0.2, 0.0001)
	assert_almost_eq(settings.right_stick_deadzone, 0.2, 0.0001)
	assert_almost_eq(settings.trigger_deadzone, 0.1, 0.0001)
	assert_true(settings.vibration_enabled)
	assert_almost_eq(settings.vibration_intensity, 1.0, 0.0001)
	assert_false(settings.invert_y_axis)
	assert_almost_eq(settings.right_stick_sensitivity, 1.0, 0.0001)
	assert_eq(settings.deadzone_curve, RS_GamepadSettings.DeadzoneCurve.LINEAR)

func test_apply_deadzone_zeroes_values_below_threshold() -> void:
	var result := RS_GamepadSettings.apply_deadzone(Vector2(0.05, 0.05), 0.2)
	assert_true(result.is_zero_approx(), "Values under deadzone should be filtered out")

func test_apply_deadzone_normalizes_and_applies_curve() -> void:
	var input := Vector2(0.8, 0.0)
	var result := RS_GamepadSettings.apply_deadzone(input, 0.2, RS_GamepadSettings.DeadzoneCurve.CUBIC)
	assert_true(result.x > 0.0)
	assert_true(result.x < 1.0, "Curve should soften magnitude")
	assert_true(result.y == 0.0)

func test_apply_deadzone_uses_response_curve_resource_when_provided() -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 0.5))
	var input := Vector2(1.0, 0.0)
	var result := RS_GamepadSettings.apply_deadzone(input, 0.0, RS_GamepadSettings.DeadzoneCurve.LINEAR, true, curve)
	assert_almost_eq(result.x, 0.5, 0.0001, "Custom response curve should remap magnitude")
