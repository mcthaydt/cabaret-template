class_name GamepadSource
extends I_InputSource

## Gamepad input source.
##
## Captures input from gamepad sticks and buttons.
## Priority: 2 (overrides keyboard/mouse when active)

const U_ECSUtils := preload("res://scripts/utils/u_ecs_utils.gd")
const RS_GamepadSettings := preload("res://scripts/ecs/resources/rs_gamepad_settings.gd")

var _left_stick_raw: Vector2 = Vector2.ZERO
var _right_stick_raw: Vector2 = Vector2.ZERO
var _left_stick_processed: Vector2 = Vector2.ZERO
var _right_stick_processed: Vector2 = Vector2.ZERO
var _button_states: Dictionary = {}
var _last_input_time: float = 0.0
var _device_id: int = -1
var _is_connected: bool = false

# Settings
var _left_stick_deadzone: float = 0.2
var _right_stick_deadzone: float = 0.2
var _right_stick_sensitivity: float = 1.0
var _invert_right_stick_y: bool = false
var _deadzone_curve: int = RS_GamepadSettings.DeadzoneCurve.LINEAR

# Action names
var jump_action: StringName = StringName("jump")
var sprint_action: StringName = StringName("sprint")

func _init(device_id: int = -1) -> void:
	_device_id = device_id

func get_device_type() -> int:
	return U_DeviceTypeConstants.DeviceType.GAMEPAD

func get_priority() -> int:
	return 2

func get_stick_deadzone(stick: StringName) -> float:
	if stick == StringName("left"):
		return _left_stick_deadzone
	elif stick == StringName("right"):
		return _right_stick_deadzone
	return 0.2

func is_active() -> bool:
	# Active if connected and received input in last 5 seconds
	if not _is_connected:
		return false
	if _last_input_time <= 0.0:
		return false
	var current_time := U_ECSUtils.get_current_time()
	return (current_time - _last_input_time) < 5.0

func capture_input(_delta: float) -> Dictionary:
	# Capture button states
	var jump_pressed := Input.is_action_pressed(jump_action)
	var jump_just_pressed := Input.is_action_just_pressed(jump_action)
	var sprint_pressed := Input.is_action_pressed(sprint_action)

	# Apply sensitivity and deadzone to right stick for look input
	var look_delta := _right_stick_processed * _right_stick_sensitivity

	# Update last input time if any input detected
	if not _left_stick_processed.is_zero_approx() or not _right_stick_processed.is_zero_approx() or jump_pressed or sprint_pressed:
		_last_input_time = U_ECSUtils.get_current_time()

	return {
		"move_input": _left_stick_processed,
		"look_input": look_delta,
		"jump_pressed": jump_pressed,
		"jump_just_pressed": jump_just_pressed,
		"sprint_pressed": sprint_pressed,
		"device_id": _device_id,
	}

func handle_motion_event(axis: int, axis_value: float) -> void:
	# Update raw stick values
	match axis:
		JOY_AXIS_LEFT_X:
			_left_stick_raw.x = axis_value
		JOY_AXIS_LEFT_Y:
			_left_stick_raw.y = axis_value
		JOY_AXIS_RIGHT_X:
			_right_stick_raw.x = axis_value
		JOY_AXIS_RIGHT_Y:
			_right_stick_raw.y = axis_value
		_:
			return

	# Process left stick with deadzone
	_left_stick_processed = RS_GamepadSettings.apply_deadzone(
		_left_stick_raw,
		_left_stick_deadzone,
		_deadzone_curve
	)

	# Process right stick with deadzone and inversion
	var right_y := _right_stick_raw.y
	if _invert_right_stick_y:
		right_y = -right_y
	var right_processed := Vector2(_right_stick_raw.x, right_y)
	_right_stick_processed = RS_GamepadSettings.apply_deadzone(
		right_processed,
		_right_stick_deadzone,
		_deadzone_curve
	)

func handle_button_event(button_index: int, pressed: bool) -> void:
	_button_states[button_index] = pressed

func set_device_id(device_id: int) -> void:
	_device_id = device_id

func set_connected(connected: bool) -> void:
	_is_connected = connected
	if not connected:
		_reset_state()

func apply_settings(settings: Dictionary) -> void:
	_left_stick_deadzone = clampf(float(settings.get("left_stick_deadzone", 0.2)), 0.0, 1.0)
	_right_stick_deadzone = clampf(float(settings.get("right_stick_deadzone", 0.2)), 0.0, 1.0)
	_right_stick_sensitivity = clampf(float(settings.get("right_stick_sensitivity", 1.0)), 0.0, 5.0)
	_invert_right_stick_y = bool(settings.get("invert_y_axis", false))
	_deadzone_curve = int(settings.get("deadzone_curve", RS_GamepadSettings.DeadzoneCurve.LINEAR))

func get_device_id() -> int:
	return _device_id

func get_button_states() -> Dictionary:
	return _button_states.duplicate(true)

func _reset_state() -> void:
	_left_stick_raw = Vector2.ZERO
	_right_stick_raw = Vector2.ZERO
	_left_stick_processed = Vector2.ZERO
	_right_stick_processed = Vector2.ZERO
	_button_states.clear()
