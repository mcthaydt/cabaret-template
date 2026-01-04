extends RefCounted
class_name U_InputActions

## Input action creators for gameplay + settings slices.
##
## Provides explicit action types for Input Manager features.

const U_InputRebindUtils := preload("res://scripts/utils/u_input_rebind_utils.gd")

const ACTION_UPDATE_MOVE_INPUT := StringName("input/update_move_input")
const ACTION_UPDATE_LOOK_INPUT := StringName("input/update_look_input")
const ACTION_UPDATE_JUMP_STATE := StringName("input/update_jump_state")
const ACTION_UPDATE_SPRINT_STATE := StringName("input/update_sprint_state")
const ACTION_DEVICE_CHANGED := StringName("input/device_changed")
const ACTION_GAMEPAD_CONNECTED := StringName("input/gamepad_connected")
const ACTION_GAMEPAD_DISCONNECTED := StringName("input/gamepad_disconnected")
const ACTION_PROFILE_SWITCHED := StringName("input/profile_switched")
const ACTION_REBIND_ACTION := StringName("input/rebind_action")
const ACTION_RESET_BINDINGS := StringName("input/reset_bindings")
const ACTION_UPDATE_GAMEPAD_DEADZONE := StringName("input/update_gamepad_deadzone")
const ACTION_TOGGLE_VIBRATION := StringName("input/toggle_vibration")
const ACTION_SET_VIBRATION_INTENSITY := StringName("input/set_vibration_intensity")
const ACTION_UPDATE_MOUSE_SENSITIVITY := StringName("input/update_mouse_sensitivity")
const ACTION_UPDATE_ACCESSIBILITY := StringName("input/update_accessibility")
const ACTION_LOAD_INPUT_SETTINGS := StringName("input/load_input_settings")
const ACTION_REMOVE_ACTION_BINDINGS := StringName("input/remove_action_bindings")
const ACTION_REMOVE_EVENT_FROM_ACTION := StringName("input/remove_event_from_action")
const ACTION_UPDATE_TOUCHSCREEN_SETTINGS := StringName("input/update_touchscreen_settings")
const ACTION_SAVE_VIRTUAL_CONTROL_POSITION := StringName("input/save_virtual_control_position")

const REBIND_MODE_REPLACE := "replace"
const REBIND_MODE_ADD := "add"

## Static initializer - register all input actions.
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_UPDATE_MOVE_INPUT, {
		"required_fields": ["move_vector"]
	})
	U_ActionRegistry.register_action(ACTION_UPDATE_LOOK_INPUT, {
		"required_fields": ["look_delta"]
	})
	U_ActionRegistry.register_action(ACTION_UPDATE_JUMP_STATE, {
		"required_fields": ["pressed", "just_pressed"]
	})
	U_ActionRegistry.register_action(ACTION_UPDATE_SPRINT_STATE, {
		"required_fields": ["pressed"]
	})
	U_ActionRegistry.register_action(ACTION_DEVICE_CHANGED, {
		"required_fields": ["device_type", "device_id", "timestamp"]
	})
	U_ActionRegistry.register_action(ACTION_GAMEPAD_CONNECTED, {
		"required_fields": ["device_id"]
	})
	U_ActionRegistry.register_action(ACTION_GAMEPAD_DISCONNECTED, {
		"required_fields": ["device_id"]
	})
	U_ActionRegistry.register_action(ACTION_PROFILE_SWITCHED, {
		"required_fields": ["profile_id"]
	})
	U_ActionRegistry.register_action(ACTION_REBIND_ACTION, {
		"required_fields": ["action", "mode"]
	})
	U_ActionRegistry.register_action(ACTION_RESET_BINDINGS)
	U_ActionRegistry.register_action(ACTION_UPDATE_GAMEPAD_DEADZONE, {
		"required_fields": ["stick", "deadzone"]
	})
	U_ActionRegistry.register_action(ACTION_TOGGLE_VIBRATION, {
		"required_fields": ["enabled"]
	})
	U_ActionRegistry.register_action(ACTION_SET_VIBRATION_INTENSITY, {
		"required_fields": ["intensity"]
	})
	U_ActionRegistry.register_action(ACTION_UPDATE_MOUSE_SENSITIVITY, {
		"required_fields": ["sensitivity"]
	})
	U_ActionRegistry.register_action(ACTION_UPDATE_ACCESSIBILITY, {
		"required_fields": ["field", "value"]
	})
	U_ActionRegistry.register_action(ACTION_LOAD_INPUT_SETTINGS)
	U_ActionRegistry.register_action(ACTION_REMOVE_ACTION_BINDINGS, {
		"required_fields": ["action"]
	})
	U_ActionRegistry.register_action(ACTION_REMOVE_EVENT_FROM_ACTION, {
		"required_fields": ["action", "event"]
	})
	U_ActionRegistry.register_action(ACTION_UPDATE_TOUCHSCREEN_SETTINGS, {
		"required_fields": ["settings"]
	})
	U_ActionRegistry.register_action(ACTION_SAVE_VIRTUAL_CONTROL_POSITION, {
		"required_fields": ["control_name", "position"]
	})

## Update move vector (keyboard, mouse, or stick).
static func update_move_input(move_vector: Vector2) -> Dictionary:
	return {
		"type": ACTION_UPDATE_MOVE_INPUT,
		"payload": {
			"move_vector": move_vector
		}
	}

## Update look delta (mouse or right stick).
static func update_look_input(look_delta: Vector2) -> Dictionary:
	return {
		"type": ACTION_UPDATE_LOOK_INPUT,
		"payload": {
			"look_delta": look_delta
		}
	}

## Update jump button state (pressed + just pressed).
static func update_jump_state(pressed: bool, just_pressed: bool) -> Dictionary:
	return {
		"type": ACTION_UPDATE_JUMP_STATE,
		"payload": {
			"pressed": pressed,
			"just_pressed": just_pressed
		}
	}

## Update sprint button state.
static func update_sprint_state(pressed: bool) -> Dictionary:
	return {
		"type": ACTION_UPDATE_SPRINT_STATE,
		"payload": {
			"pressed": pressed
		}
	}

## Active input device changed (keyboard/mouse, gamepad, touchscreen).
static func device_changed(device_type: int, device_id: int = -1, timestamp: float = 0.0) -> Dictionary:
	return {
		"type": ACTION_DEVICE_CHANGED,
		"payload": {
			"device_type": device_type,
			"device_id": device_id,
			"timestamp": timestamp
		},
		"immediate": true
	}

## Gamepad connected.
static func gamepad_connected(device_id: int) -> Dictionary:
	return {
		"type": ACTION_GAMEPAD_CONNECTED,
		"payload": {
			"device_id": device_id
		}
	}

## Gamepad disconnected.
static func gamepad_disconnected(device_id: int) -> Dictionary:
	return {
		"type": ACTION_GAMEPAD_DISCONNECTED,
		"payload": {
			"device_id": device_id
		}
	}

## Profile switched (default/alternate/accessibility/etc.).
static func profile_switched(profile_id: String) -> Dictionary:
	return {
		"type": ACTION_PROFILE_SWITCHED,
		"payload": {
			"profile_id": profile_id
		}
	}

## Apply a single rebind entry (action + InputEvent data dictionary).
static func rebind_action(action_name: StringName, event: Variant, mode: String = REBIND_MODE_REPLACE, events: Array = []) -> Dictionary:
	var payload_event: Dictionary = {}
	if event is InputEvent:
		payload_event = U_InputRebindUtils.event_to_dict(event)
	elif event is Dictionary:
		payload_event = (event as Dictionary).duplicate(true)
	var payload_events: Array = []
	for entry in events:
		if entry is InputEvent:
			payload_events.append(U_InputRebindUtils.event_to_dict(entry))
		elif entry is Dictionary:
			payload_events.append((entry as Dictionary).duplicate(true))
	return {
		"type": ACTION_REBIND_ACTION,
		"payload": {
			"action": action_name,
			"event": payload_event,
			"mode": mode,
			"events": payload_events
		},
		"immediate": true
	}

## Reset all bindings for the active profile.
static func reset_bindings() -> Dictionary:
	return {
		"type": ACTION_RESET_BINDINGS,
		"payload": {},
		"immediate": true
	}

## Update per-stick deadzone configuration.
static func update_gamepad_deadzone(stick: String, deadzone: float) -> Dictionary:
	return {
		"type": ACTION_UPDATE_GAMEPAD_DEADZONE,
		"payload": {
			"stick": stick,
			"deadzone": deadzone
		}
	}

## Enable/disable vibration globally.
static func toggle_vibration(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_TOGGLE_VIBRATION,
		"payload": {
			"enabled": enabled
		}
	}

## Update vibration intensity multiplier (0.0-1.0).
static func set_vibration_intensity(intensity: float) -> Dictionary:
	return {
		"type": ACTION_SET_VIBRATION_INTENSITY,
		"payload": {
			"intensity": intensity
		}
	}

## Update mouse sensitivity setting.
static func update_mouse_sensitivity(sensitivity: float) -> Dictionary:
	return {
		"type": ACTION_UPDATE_MOUSE_SENSITIVITY,
		"payload": {
			"sensitivity": sensitivity
		}
	}

## Update accessibility option by field name.
static func update_accessibility(field: String, value) -> Dictionary:
	return {
		"type": ACTION_UPDATE_ACCESSIBILITY,
		"payload": {
			"field": field,
			"value": value
		}
	}

static func load_input_settings(settings: Dictionary) -> Dictionary:
	var payload := {}
	if settings != null:
		payload = settings.duplicate(true)
	return {
		"type": ACTION_LOAD_INPUT_SETTINGS,
		"payload": payload
	}

static func remove_action_bindings(action_name: StringName) -> Dictionary:
	return {
		"type": ACTION_REMOVE_ACTION_BINDINGS,
		"payload": {
			"action": action_name
		}
	}

static func remove_event_from_action(action_name: StringName, event_dict: Dictionary) -> Dictionary:
	var payload_event := event_dict
	if event_dict != null and event_dict is Dictionary:
		payload_event = (event_dict as Dictionary).duplicate(true)
	return {
		"type": ACTION_REMOVE_EVENT_FROM_ACTION,
		"payload": {
			"action": action_name,
			"event": payload_event
		}
	}

## Update touchscreen settings (opacity, button size, etc.).
static func update_touchscreen_settings(settings: Dictionary) -> Dictionary:
	return {
		"type": ACTION_UPDATE_TOUCHSCREEN_SETTINGS,
		"payload": {
			"settings": settings
		}
	}

## Save custom position for a virtual control (joystick or button).
## Position is stored as Vector2 in Redux state (in-memory).
static func save_virtual_control_position(control_name: String, position: Vector2) -> Dictionary:
	return {
		"type": ACTION_SAVE_VIRTUAL_CONTROL_POSITION,
		"payload": {
			"control_name": control_name,
			"position": position
		}
	}
