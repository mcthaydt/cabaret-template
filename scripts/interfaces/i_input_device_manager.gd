extends Node
class_name I_InputDeviceManager

## Minimal interface for M_InputDeviceManager
##
## Phase 7 (cleanup_v4): Created for duck typing cleanup - removes has_method() checks
##
## Implementations:
## - M_InputDeviceManager (production)
## - MockInputDeviceManager (testing, if needed)

## Get the mobile controls node if registered
##
## Returns the mobile controls node (MobileControls) if it has been registered
## and is still valid, otherwise returns null.
##
## @return Node: The mobile controls node, or null if not registered
func get_mobile_controls() -> Node:
	push_error("I_InputDeviceManager.get_mobile_controls not implemented")
	return null

## Get the currently active device type
##
## Returns the active device type constant from U_DeviceTypeConstants.DeviceType
## (KEYBOARD_MOUSE, GAMEPAD, or TOUCHSCREEN)
##
## @return int: Active device type constant
func get_active_device() -> int:
	push_error("I_InputDeviceManager.get_active_device not implemented")
	return 0
