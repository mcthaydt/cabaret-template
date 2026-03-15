class_name KeyboardMouseSource
extends I_InputSource

## Keyboard and mouse input source.
##
## Captures input from keyboard (WASD, arrows) and mouse (motion, buttons).
## Priority: 1 (default, overridden by gamepad when gamepad is active)


var _mouse_delta: Vector2 = Vector2.ZERO
var _last_input_time: float = 0.0
var _mouse_sensitivity: float = 0.6
var _input_deadzone: float = 0.15
var _keyboard_look_enabled: bool = true
var _keyboard_look_speed: float = 2.0
var _invert_y_axis: bool = false

# Action names (configurable)
var negative_x_action: StringName = StringName("move_left")
var positive_x_action: StringName = StringName("move_right")
var negative_z_action: StringName = StringName("move_forward")
var positive_z_action: StringName = StringName("move_backward")
var look_left_action: StringName = StringName("look_left")
var look_right_action: StringName = StringName("look_right")
var look_up_action: StringName = StringName("look_up")
var look_down_action: StringName = StringName("look_down")
var aim_action: StringName = StringName("aim")
var camera_center_action: StringName = StringName("camera_center")
var jump_action: StringName = StringName("jump")
var sprint_action: StringName = StringName("sprint")

func _init(sensitivity: float = 0.6, deadzone: float = 0.15) -> void:
	_mouse_sensitivity = sensitivity
	_input_deadzone = deadzone

func get_device_type() -> int:
	return U_DeviceTypeConstants.DeviceType.KEYBOARD_MOUSE

func get_priority() -> int:
	return 1

func get_stick_deadzone(__stick: StringName) -> float:
	return _input_deadzone

func is_active() -> bool:
	# Active if we received input in the last 5 seconds
	if _last_input_time <= 0.0:
		return false
	var current_time := U_ECSUtils.get_current_time()
	return (current_time - _last_input_time) < 5.0

func capture_input(_delta: float) -> Dictionary:
	# Capture keyboard movement vector
	var keyboard_vector := Input.get_vector(
		negative_x_action,
		positive_x_action,
		negative_z_action,
		positive_z_action
	)

	# Apply deadzone
	if keyboard_vector.length() > 0.0 and keyboard_vector.length() < _input_deadzone:
		keyboard_vector = Vector2.ZERO

	# Capture button states
	var aim_pressed := Input.is_action_pressed(aim_action)
	var camera_center_just_pressed := Input.is_action_just_pressed(camera_center_action)
	var jump_pressed := Input.is_action_pressed(jump_action)
	var jump_just_pressed := Input.is_action_just_pressed(jump_action)
	var sprint_pressed := Input.is_action_pressed(sprint_action)

	# Mouse look delta (immediate, event-driven)
	var look_delta := _mouse_delta * _mouse_sensitivity

	# Keyboard look delta (continuous). Keep this in per-tick units to match
	# how S_VCamSystem consumes look_input from gamepad/mouse sources.
	if _keyboard_look_enabled:
		var keyboard_look_x: float = Input.get_action_strength(look_right_action) - Input.get_action_strength(look_left_action)
		var keyboard_look_y: float = Input.get_action_strength(look_down_action) - Input.get_action_strength(look_up_action)
		if _invert_y_axis:
			keyboard_look_y *= -1.0
		var keyboard_look_delta: Vector2 = Vector2(keyboard_look_x, keyboard_look_y) * _keyboard_look_speed
		look_delta += keyboard_look_delta

	# Update last input time if any input detected
	if (
		not keyboard_vector.is_zero_approx()
		or not look_delta.is_zero_approx()
		or aim_pressed
		or camera_center_just_pressed
		or jump_pressed
		or sprint_pressed
	):
		_last_input_time = U_ECSUtils.get_current_time()

	# Clear mouse delta after capture (will be repopulated by next mouse motion event)
	var result := {
		"move_input": keyboard_vector,
		"look_input": look_delta,
		"aim_pressed": aim_pressed,
		"camera_center_just_pressed": camera_center_just_pressed,
		"jump_pressed": jump_pressed,
		"jump_just_pressed": jump_just_pressed,
		"sprint_pressed": sprint_pressed,
		"device_id": -1,
	}

	_mouse_delta = Vector2.ZERO

	return result

func set_mouse_delta(delta: Vector2) -> void:
	# Accumulate all mouse motion events between capture ticks.
	_mouse_delta += delta

func set_sensitivity(sensitivity: float) -> void:
	_mouse_sensitivity = clampf(sensitivity, 0.1, 5.0)

func set_keyboard_look_enabled(enabled: bool) -> void:
	_keyboard_look_enabled = enabled

func set_keyboard_look_speed(speed: float) -> void:
	_keyboard_look_speed = clampf(speed, 0.1, 10.0)

func set_invert_y_axis(invert_y_axis: bool) -> void:
	_invert_y_axis = invert_y_axis

func get_device_id() -> int:
	return -1
