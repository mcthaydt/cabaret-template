extends GutTest

## Integration tests for gamepad menu navigation deadzone
##
## Tests cover:
## - Deadzone threshold preventing stick drift
## - Input action strength calculation with deadzone
## - Verification that 0.25 deadzone works across all ui_* actions

const EXPECTED_DEADZONE: float = 0.25

## DEADZONE THRESHOLD TESTS

func test_stick_drift_does_not_trigger_menu_navigation() -> void:
	# Verify that typical stick drift values (< 0.25) don't trigger navigation
	# This is a regression guard to ensure deadzone prevents false inputs

	var drift_values: Array[float] = [0.10, 0.15, 0.20, 0.24]

	for drift in drift_values:
		# Create a gamepad motion event below deadzone
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = JOY_AXIS_LEFT_Y
		event.axis_value = drift

		# Verify the event wouldn't pass action strength threshold
		var action_strength: float = _get_event_action_strength(event, StringName("ui_down"))
		assert_eq(action_strength, 0.0,
			"Drift value %s should not trigger ui_down (got strength %s)" % [drift, action_strength])


func test_valid_input_above_deadzone_triggers_navigation() -> void:
	# Verify that valid input (>= 0.25) passes action tests
	var valid_values: Array[float] = [0.25, 0.30, 0.50, 1.0]

	for value in valid_values:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = JOY_AXIS_LEFT_Y
		event.axis_value = value

		# Check if the event would be recognized as the action
		var is_action: bool = event.is_action(StringName("ui_down"))
		assert_true(is_action,
			"Value %s should be recognized as ui_down action" % value)


## COMPREHENSIVE DEADZONE VERIFICATION

func test_all_directional_actions_have_correct_deadzone() -> void:
	# Verify all four directional actions have 0.25 deadzone
	var actions: Array[StringName] = [
		StringName("ui_up"),
		StringName("ui_down"),
		StringName("ui_left"),
		StringName("ui_right")
	]

	for action in actions:
		var deadzone: float = InputMap.action_get_deadzone(action)
		assert_almost_eq(deadzone, EXPECTED_DEADZONE, 0.01,
			"Action '%s' deadzone should be %s (got %s)" % [action, EXPECTED_DEADZONE, deadzone])


func test_deadzone_filters_input_for_all_directions() -> void:
	# Test that deadzone filtering works for all four directions
	var test_cases: Array[Dictionary] = [
		{"action": StringName("ui_up"), "axis": JOY_AXIS_LEFT_Y, "value": -0.24},
		{"action": StringName("ui_down"), "axis": JOY_AXIS_LEFT_Y, "value": 0.24},
		{"action": StringName("ui_left"), "axis": JOY_AXIS_LEFT_X, "value": -0.24},
		{"action": StringName("ui_right"), "axis": JOY_AXIS_LEFT_X, "value": 0.24}
	]

	for test_case in test_cases:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = test_case.axis
		event.axis_value = test_case.value

		var action_strength: float = _get_event_action_strength(event, test_case.action)
		assert_eq(action_strength, 0.0,
			"Drift value 0.24 should not trigger %s" % test_case.action)


## HELPER METHODS

func _get_event_action_strength(event: InputEvent, action: StringName) -> float:
	# Get action strength directly from Input system
	# This verifies that Godot's internal filtering matches our expectations
	return event.get_action_strength(action)
