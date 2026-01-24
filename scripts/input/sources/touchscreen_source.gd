class_name TouchscreenSource
extends I_InputSource

## Touchscreen input source.
##
## Handles touch input events and delegates to virtual controls (MobileControls).
## Priority: 3 (highest - mobile exclusive)
##
## Note: Actual input capture is handled by MobileControls virtual joystick/buttons.
## This source acts as an activation detector for device switching.

const U_ECSUtils := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

var _last_touch_time: float = 0.0
var _is_mobile: bool = false

func _init() -> void:
	_is_mobile = OS.has_feature("mobile") or OS.has_feature("web")

func get_device_type() -> int:
	return U_DeviceTypeConstants.DeviceType.TOUCHSCREEN

func get_priority() -> int:
	return 3

func get_stick_deadzone(_stick: StringName) -> float:
	return 0.15

func is_active() -> bool:
	# Only active on mobile platforms and if touch detected recently
	if not _is_mobile:
		return false
	if _last_touch_time <= 0.0:
		return false
	var current_time := U_ECSUtils.get_current_time()
	return (current_time - _last_touch_time) < 5.0

func capture_input(_delta: float) -> Dictionary:
	# Touchscreen input is handled by MobileControls (virtual joystick/buttons)
	# This source is primarily used for device type detection
	# MobileControls publishes input to Redux state, which is read by gameplay systems
	return {
		"move_input": Vector2.ZERO,
		"look_input": Vector2.ZERO,
		"jump_pressed": false,
		"jump_just_pressed": false,
		"sprint_pressed": false,
		"device_id": -1,
	}

func handle_touch_event() -> void:
	# Called when touch input is detected
	_last_touch_time = U_ECSUtils.get_current_time()

func get_device_id() -> int:
	return -1
