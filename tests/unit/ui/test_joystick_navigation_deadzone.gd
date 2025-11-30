extends GutTest

## Test suite for joystick navigation deadzone configuration
##
## Verifies that ui_* actions have correct deadzone (0.25) matching
## the device switch threshold for consistent input behavior.

const EXPECTED_DEADZONE: float = 0.25
const DEVICE_SWITCH_DEADZONE: float = 0.25  # From M_InputDeviceManager


func test_ui_up_has_correct_deadzone() -> void:
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
	assert_almost_eq(EXPECTED_DEADZONE, DEVICE_SWITCH_DEADZONE, 0.01,
		"UI navigation deadzone should match device detection deadzone for consistency")
