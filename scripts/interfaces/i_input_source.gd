class_name I_InputSource
extends RefCounted

## Interface for input device sources.
##
## Each device type (keyboard/mouse, gamepad, touchscreen) implements this interface
## to provide polymorphic input capture. This allows adding new input types (e.g., VR)
## without modifying M_InputDeviceManager or S_InputSystem.
##
## Usage:
##   var source := KeyboardMouseSource.new()
##   if source.is_active():
##       var input_data := source.capture_input(delta)
##       # Process input_data...

## Returns the device type this source handles.
func get_device_type() -> int:
	return U_DeviceTypeConstants.DeviceType.KEYBOARD_MOUSE

## Returns the priority of this source (higher = overrides lower).
## Default priority: Keyboard=1, Gamepad=2, Touchscreen=3
func get_priority() -> int:
	return 0

## Returns the deadzone threshold for the specified stick.
## stick can be StringName("left") or StringName("right")
func get_stick_deadzone(_stick: StringName) -> float:
	return 0.2

## Returns true if this source has received input recently.
func is_active() -> bool:
	return false

## Captures input from this source and returns a Dictionary with:
## {
##   move_input: Vector2,
##   look_input: Vector2,
##   jump_pressed: bool,
##   jump_just_pressed: bool,
##   sprint_pressed: bool,
##   device_id: int (for gamepad, -1 otherwise)
## }
func capture_input(_delta: float) -> Dictionary:
	return {
		"move_input": Vector2.ZERO,
		"look_input": Vector2.ZERO,
		"jump_pressed": false,
		"jump_just_pressed": false,
		"sprint_pressed": false,
		"device_id": -1,
	}

## Returns the device ID (for gamepad sources, -1 for others).
func get_device_id() -> int:
	return -1
