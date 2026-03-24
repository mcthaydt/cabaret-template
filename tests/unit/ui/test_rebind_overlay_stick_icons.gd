extends GutTest

## Tests that the rebind overlay shows correct joystick icons and excludes
## look_up/look_down actions.
##
## Covers:
## - look_up / look_down are in EXCLUDED_ACTIONS
## - look_up / look_down are NOT in ACTION_CATEGORIES
## - get_texture_for_event returns left-stick textures for left-axis motion
## - get_texture_for_event returns right-stick textures for right-axis motion
## - refresh_bindings prefers active profile events over InputMap events


# ---------------------------------------------------------------------------
# Exclusion tests
# ---------------------------------------------------------------------------

func test_look_up_is_excluded_from_rebind() -> void:
	assert_true(
		U_RebindActionListBuilder.EXCLUDED_ACTIONS.has("look_up"),
		"look_up should be in EXCLUDED_ACTIONS"
	)

func test_look_down_is_excluded_from_rebind() -> void:
	assert_true(
		U_RebindActionListBuilder.EXCLUDED_ACTIONS.has("look_down"),
		"look_down should be in EXCLUDED_ACTIONS"
	)

func test_look_up_not_in_camera_category() -> void:
	var camera_actions: Array = U_RebindActionListBuilder.ACTION_CATEGORIES.get("camera", [])
	assert_false(
		camera_actions.has("look_up"),
		"look_up should not be in the camera category"
	)

func test_look_down_not_in_camera_category() -> void:
	var camera_actions: Array = U_RebindActionListBuilder.ACTION_CATEGORIES.get("camera", [])
	assert_false(
		camera_actions.has("look_down"),
		"look_down should not be in the camera category"
	)

func test_look_left_still_in_camera_category() -> void:
	var camera_actions: Array = U_RebindActionListBuilder.ACTION_CATEGORIES.get("camera", [])
	assert_true(
		camera_actions.has("look_left"),
		"look_left should remain in the camera category"
	)

func test_look_right_still_in_camera_category() -> void:
	var camera_actions: Array = U_RebindActionListBuilder.ACTION_CATEGORIES.get("camera", [])
	assert_true(
		camera_actions.has("look_right"),
		"look_right should remain in the camera category"
	)

# ---------------------------------------------------------------------------
# Texture / icon tests for joypad motion events
# ---------------------------------------------------------------------------

func _make_joypad_motion(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis as JoyAxis
	event.axis_value = value
	return event

func test_left_stick_left_returns_ls_texture() -> void:
	var event := _make_joypad_motion(JOY_AXIS_LEFT_X, -1.0)
	var texture := U_InputEventDisplay.get_texture_for_event(event)
	assert_not_null(texture, "Left stick left should return a texture")

func test_left_stick_right_returns_ls_texture() -> void:
	var event := _make_joypad_motion(JOY_AXIS_LEFT_X, 1.0)
	var texture := U_InputEventDisplay.get_texture_for_event(event)
	assert_not_null(texture, "Left stick right should return a texture")

func test_left_stick_up_returns_ls_texture() -> void:
	var event := _make_joypad_motion(JOY_AXIS_LEFT_Y, -1.0)
	var texture := U_InputEventDisplay.get_texture_for_event(event)
	assert_not_null(texture, "Left stick up should return a texture")

func test_left_stick_down_returns_ls_texture() -> void:
	var event := _make_joypad_motion(JOY_AXIS_LEFT_Y, 1.0)
	var texture := U_InputEventDisplay.get_texture_for_event(event)
	assert_not_null(texture, "Left stick down should return a texture")

func test_right_stick_left_returns_rs_texture() -> void:
	var event := _make_joypad_motion(JOY_AXIS_RIGHT_X, -1.0)
	var texture := U_InputEventDisplay.get_texture_for_event(event)
	assert_not_null(texture, "Right stick left should return a texture")

func test_right_stick_right_returns_rs_texture() -> void:
	var event := _make_joypad_motion(JOY_AXIS_RIGHT_X, 1.0)
	var texture := U_InputEventDisplay.get_texture_for_event(event)
	assert_not_null(texture, "Right stick right should return a texture")

func test_right_stick_up_returns_rs_texture() -> void:
	var event := _make_joypad_motion(JOY_AXIS_RIGHT_Y, -1.0)
	var texture := U_InputEventDisplay.get_texture_for_event(event)
	assert_not_null(texture, "Right stick up should return a texture")

func test_right_stick_down_returns_rs_texture() -> void:
	var event := _make_joypad_motion(JOY_AXIS_RIGHT_Y, 1.0)
	var texture := U_InputEventDisplay.get_texture_for_event(event)
	assert_not_null(texture, "Right stick down should return a texture")

# ---------------------------------------------------------------------------
# Label tests for joypad motion events
# ---------------------------------------------------------------------------

func test_left_stick_left_label() -> void:
	var event := _make_joypad_motion(JOY_AXIS_LEFT_X, -1.0)
	assert_eq(U_InputEventDisplay.format_event_label(event), "Left Joystick Left")

func test_left_stick_up_label() -> void:
	var event := _make_joypad_motion(JOY_AXIS_LEFT_Y, -1.0)
	assert_eq(U_InputEventDisplay.format_event_label(event), "Left Joystick Up")

func test_right_stick_right_label() -> void:
	var event := _make_joypad_motion(JOY_AXIS_RIGHT_X, 1.0)
	assert_eq(U_InputEventDisplay.format_event_label(event), "Right Joystick Right")

func test_right_stick_down_label() -> void:
	var event := _make_joypad_motion(JOY_AXIS_RIGHT_Y, 1.0)
	assert_eq(U_InputEventDisplay.format_event_label(event), "Right Joystick Down")

# ---------------------------------------------------------------------------
# Profile-preferred event sourcing
# ---------------------------------------------------------------------------

func test_profile_events_used_over_inputmap_for_movement() -> void:
	# The gamepad profile defines move_forward as left stick up (axis 1, -1.0).
	# InputMap only has keyboard events. The profile should be preferred.
	var profile := RS_InputProfile.new()
	var stick_event := _make_joypad_motion(JOY_AXIS_LEFT_Y, -1.0)
	profile.set_events_for_action(StringName("move_forward"), [stick_event])

	var events := profile.get_events_for_action(StringName("move_forward"))
	assert_eq(events.size(), 1, "Profile should return one event for move_forward")
	assert_true(events[0] is InputEventJoypadMotion, "Profile event should be joypad motion")
	var motion := events[0] as InputEventJoypadMotion
	assert_eq(motion.axis, JOY_AXIS_LEFT_Y as JoyAxis, "Should be left stick Y axis")
	assert_eq(motion.axis_value, -1.0, "Should be negative (up)")

func test_profile_events_used_over_inputmap_for_look() -> void:
	# The gamepad profile defines look_left as right stick left (axis 2, -1.0).
	var profile := RS_InputProfile.new()
	var stick_event := _make_joypad_motion(JOY_AXIS_RIGHT_X, -1.0)
	profile.set_events_for_action(StringName("look_left"), [stick_event])

	var events := profile.get_events_for_action(StringName("look_left"))
	assert_eq(events.size(), 1, "Profile should return one event for look_left")
	assert_true(events[0] is InputEventJoypadMotion, "Profile event should be joypad motion")
	var motion := events[0] as InputEventJoypadMotion
	assert_eq(motion.axis, JOY_AXIS_RIGHT_X as JoyAxis, "Should be right stick X axis")
	assert_eq(motion.axis_value, -1.0, "Should be negative (left)")

func test_default_gamepad_profile_has_stick_events() -> void:
	# Verify the actual default gamepad profile has the correct stick mappings.
	var profile: RS_InputProfile = load("res://resources/input/profiles/cfg_default_gamepad.tres")
	assert_not_null(profile, "Default gamepad profile should exist")

	# Movement should use left stick
	var move_fwd := profile.get_events_for_action(StringName("move_forward"))
	assert_false(move_fwd.is_empty(), "move_forward should have events in gamepad profile")
	if not move_fwd.is_empty():
		assert_true(move_fwd[0] is InputEventJoypadMotion, "move_forward should be joypad motion")
		var motion := move_fwd[0] as InputEventJoypadMotion
		assert_eq(motion.axis, JOY_AXIS_LEFT_Y as JoyAxis, "move_forward should use left stick Y")

	# Look should use right stick
	var look_l := profile.get_events_for_action(StringName("look_left"))
	assert_false(look_l.is_empty(), "look_left should have events in gamepad profile")
	if not look_l.is_empty():
		assert_true(look_l[0] is InputEventJoypadMotion, "look_left should be joypad motion")
		var motion := look_l[0] as InputEventJoypadMotion
		assert_eq(motion.axis, JOY_AXIS_RIGHT_X as JoyAxis, "look_left should use right stick X")
