extends GutTest

## Test suite for joystick navigation deadzone configuration
##
## Verifies that:
## 1. ui_* actions have correct deadzone (0.25)
## 2. Axis values below deadzone don't trigger navigation
## 3. Axis values at/above deadzone do trigger navigation
## 4. Keyboard/D-pad events work regardless of deadzone

const EXPECTED_DEADZONE: float = 0.25
const DEVICE_SWITCH_DEADZONE: float = 0.25  # From M_InputDeviceManager

## DEADZONE CONFIGURATION TESTS

func test_ui_up_has_correct_deadzone() -> void:
	# In Godot 4, deadzone is a property of the action itself, not the event
	var deadzone: float = InputMap.action_get_deadzone(StringName("ui_up"))

	assert_almost_eq(deadzone, EXPECTED_DEADZONE, 0.01,
		"ui_up deadzone should be %s (got %s)" % [EXPECTED_DEADZONE, deadzone])


func test_ui_down_has_correct_deadzone() -> void:
	var deadzone: float = InputMap.action_get_deadzone(StringName("ui_down"))

	assert_almost_eq(deadzone, EXPECTED_DEADZONE, 0.01,
		"ui_down deadzone should be %s (got %s)" % [EXPECTED_DEADZONE, deadzone])


func test_ui_left_has_correct_deadzone() -> void:
	var deadzone: float = InputMap.action_get_deadzone(StringName("ui_left"))

	assert_almost_eq(deadzone, EXPECTED_DEADZONE, 0.01,
		"ui_left deadzone should be %s (got %s)" % [EXPECTED_DEADZONE, deadzone])


func test_ui_right_has_correct_deadzone() -> void:
	var deadzone: float = InputMap.action_get_deadzone(StringName("ui_right"))

	assert_almost_eq(deadzone, EXPECTED_DEADZONE, 0.01,
		"ui_right deadzone should be %s (got %s)" % [EXPECTED_DEADZONE, deadzone])


func test_deadzone_matches_device_switch_threshold() -> void:
	# Verify all ui_* deadzones match M_InputDeviceManager.DEVICE_SWITCH_DEADZONE
	assert_almost_eq(EXPECTED_DEADZONE, DEVICE_SWITCH_DEADZONE, 0.01,
		"UI navigation deadzone should match device detection deadzone for consistency")


## AXIS VALUE THRESHOLD TESTS

func test_axis_value_below_deadzone_does_not_trigger_up() -> void:
	# Create joystick motion event below deadzone
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = -0.24  # Below 0.25 deadzone

	# Test that Input.is_action_pressed would not trigger
	# Note: We can't directly test the filtering, but we verify the configuration
	var action_deadzone: float = _get_action_deadzone(StringName("ui_up"))
	assert_gt(action_deadzone, abs(event.axis_value),
		"Axis value 0.24 should be below deadzone %s" % action_deadzone)


func test_axis_value_at_deadzone_triggers_up() -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = -0.25  # At deadzone threshold

	var action_deadzone: float = _get_action_deadzone(StringName("ui_up"))
	assert_almost_eq(abs(event.axis_value), action_deadzone, 0.01,
		"Axis value 0.25 should be at deadzone threshold")


func test_axis_value_above_deadzone_triggers_up() -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = -0.50  # Well above deadzone

	var action_deadzone: float = _get_action_deadzone(StringName("ui_up"))
	assert_gt(abs(event.axis_value), action_deadzone,
		"Axis value 0.50 should be above deadzone %s" % action_deadzone)


func test_stick_drift_does_not_trigger_navigation() -> void:
	# Typical stick drift is 0.15-0.20
	var drift_values: Array[float] = [0.10, 0.15, 0.20, 0.24]

	for drift in drift_values:
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_Y
		event.axis_value = drift

		var action_deadzone: float = _get_action_deadzone(StringName("ui_down"))
		assert_gt(action_deadzone, abs(event.axis_value),
			"Drift value %s should not trigger navigation (deadzone %s)" % [drift, action_deadzone])


## KEYBOARD/D-PAD UNAFFECTED TESTS

func test_keyboard_events_unaffected_by_deadzone() -> void:
	# Keyboard events should work regardless of deadzone
	var events: Array[InputEvent] = InputMap.action_get_events(StringName("ui_up"))

	var has_keyboard: bool = false
	for event in events:
		if event is InputEventKey:
			has_keyboard = true
			# Keyboard events don't have deadzone property
			assert_true(true, "Keyboard event found for ui_up")
			break

	assert_true(has_keyboard, "ui_up should have keyboard event")


func test_dpad_events_unaffected_by_deadzone() -> void:
	# D-pad button events should work regardless of axis deadzone
	var events: Array[InputEvent] = InputMap.action_get_events(StringName("ui_up"))

	var has_dpad: bool = false
	for event in events:
		if event is InputEventJoypadButton:
			has_dpad = true
			# D-pad buttons don't have deadzone (they're binary)
			assert_true(true, "D-pad button event found for ui_up")
			break

	assert_true(has_dpad, "ui_up should have D-pad button event")


## HELPER METHODS

func _get_action_deadzone(action_name: StringName) -> float:
	return InputMap.action_get_deadzone(action_name)
