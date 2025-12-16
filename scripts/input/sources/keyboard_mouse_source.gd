class_name KeyboardMouseSource
extends I_InputSource

## Keyboard and mouse input source.
##
## Captures input from keyboard (WASD, arrows) and mouse (motion, buttons).
## Priority: 1 (default, overridden by gamepad when gamepad is active)

const U_ECSUtils := preload("res://scripts/utils/u_ecs_utils.gd")

var _mouse_delta: Vector2 = Vector2.ZERO
var _last_input_time: float = 0.0
var _mouse_sensitivity: float = 1.0
var _input_deadzone: float = 0.15

# Action names (configurable)
var negative_x_action: StringName = StringName("move_left")
var positive_x_action: StringName = StringName("move_right")
var negative_z_action: StringName = StringName("move_forward")
var positive_z_action: StringName = StringName("move_backward")
var jump_action: StringName = StringName("jump")
var sprint_action: StringName = StringName("sprint")

func _init(sensitivity: float = 1.0, deadzone: float = 0.15) -> void:
	_mouse_sensitivity = sensitivity
	_input_deadzone = deadzone

func get_device_type() -> int:
	return U_DeviceTypeConstants.DeviceType.KEYBOARD_MOUSE

func get_priority() -> int:
	return 1

func get_stick_deadzone(_stick: StringName) -> float:
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
	var jump_pressed := Input.is_action_pressed(jump_action)
	var jump_just_pressed := Input.is_action_just_pressed(jump_action)
	var sprint_pressed := Input.is_action_pressed(sprint_action)

	# Apply mouse sensitivity to look delta
	var look_delta := _mouse_delta * _mouse_sensitivity

	# Update last input time if any input detected
	if not keyboard_vector.is_zero_approx() or not _mouse_delta.is_zero_approx() or jump_pressed or sprint_pressed:
		_last_input_time = U_ECSUtils.get_current_time()

	# Clear mouse delta after capture (will be repopulated by next mouse motion event)
	var result := {
		"move_input": keyboard_vector,
		"look_input": look_delta,
		"jump_pressed": jump_pressed,
		"jump_just_pressed": jump_just_pressed,
		"sprint_pressed": sprint_pressed,
		"device_id": -1,
	}

	_mouse_delta = Vector2.ZERO

	return result

func set_mouse_delta(delta: Vector2) -> void:
	_mouse_delta = delta

func set_sensitivity(sensitivity: float) -> void:
	_mouse_sensitivity = clampf(sensitivity, 0.0, 20.0)

func get_device_id() -> int:
	return -1
