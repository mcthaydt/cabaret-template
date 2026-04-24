extends RefCounted
class_name U_InputEventSerialization

## Utilities for serializing InputEvent instances to Dictionaries and back.
##
## This helper centralizes event→Dictionary and Dictionary→event conversions
## so input rebinding, profile persistence, and settings serialization share
## a single implementation.

static func event_to_dict(event: InputEvent) -> Dictionary:
	if event == null:
		return {}

	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {
			"type": "key",
			"keycode": key_event.keycode,
			"physical_keycode": key_event.physical_keycode,
			"unicode": key_event.unicode,
			"pressed": key_event.pressed,
			"echo": key_event.echo,
			"alt": key_event.alt_pressed,
			"shift": key_event.shift_pressed,
			"ctrl": key_event.ctrl_pressed,
			"meta": key_event.meta_pressed
		}

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return {
			"type": "mouse_button",
			"button_index": mouse_event.button_index,
			"pressed": mouse_event.pressed,
			"double_click": mouse_event.double_click,
			"position": mouse_event.position,
			"global_position": mouse_event.global_position
		}

	if event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		return {
			"type": "joypad_button",
			"button_index": joy_button.button_index,
			"pressed": joy_button.pressed,
			"pressure": joy_button.pressure
		}

	if event is InputEventJoypadMotion:
		var joy_motion := event as InputEventJoypadMotion
		return {
			"type": "joypad_motion",
			"axis": joy_motion.axis,
			"axis_value": joy_motion.axis_value
		}

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		return {
			"type": "screen_touch",
			"index": touch.index,
			"position": touch.position,
			"pressed": touch.pressed
		}

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		return {
			"type": "screen_drag",
			"index": drag.index,
			"position": drag.position,
			"relative": drag.relative,
			"velocity": drag.velocity
		}

	push_warning("U_InputEventSerialization.event_to_dict: Unsupported InputEvent type: %s" % event.get_class())
	return {}

static func dict_to_event(data: Dictionary) -> InputEvent:
	if data == null or data.is_empty():
		return null

	var event_type: String = String(data.get("type", ""))

	match event_type:
		"key", "InputEventKey":
			var e_key := InputEventKey.new()
			var keycode_val: int = int(data.get("keycode", 0))
			var physical_keycode_val: int = int(data.get("physical_keycode", 0))

			if keycode_val != 0 and physical_keycode_val == 0:
				physical_keycode_val = keycode_val
			elif physical_keycode_val != 0 and keycode_val == 0:
				keycode_val = physical_keycode_val

			e_key.keycode = keycode_val as Key
			e_key.physical_keycode = physical_keycode_val as Key
			e_key.unicode = int(data.get("unicode", 0))
			e_key.pressed = bool(data.get("pressed", false))
			e_key.echo = bool(data.get("echo", false))
			e_key.alt_pressed = bool(data.get("alt", false))
			e_key.shift_pressed = bool(data.get("shift", false))
			e_key.ctrl_pressed = bool(data.get("ctrl", false))
			e_key.meta_pressed = bool(data.get("meta", false))
			return e_key

		"mouse_button", "InputEventMouseButton":
			var e_mouse := InputEventMouseButton.new()
			e_mouse.button_index = int(data.get("button_index", 0)) as MouseButton
			e_mouse.pressed = bool(data.get("pressed", false))
			e_mouse.double_click = bool(data.get("double_click", false))

			var position_variant: Variant = data.get("position", null)
			if position_variant is Vector2:
				e_mouse.position = position_variant

			var global_position_variant: Variant = data.get("global_position", null)
			if global_position_variant is Vector2:
				e_mouse.global_position = global_position_variant

			return e_mouse

		"joypad_button", "InputEventJoypadButton":
			var e_button := InputEventJoypadButton.new()
			e_button.button_index = int(data.get("button_index", 0)) as JoyButton
			e_button.pressed = bool(data.get("pressed", false))
			e_button.pressure = float(data.get("pressure", 0.0))
			return e_button

		"joypad_motion", "InputEventJoypadMotion":
			var e_motion := InputEventJoypadMotion.new()
			e_motion.axis = int(data.get("axis", 0)) as JoyAxis
			e_motion.axis_value = float(data.get("axis_value", 0.0))
			return e_motion

		"screen_touch", "InputEventScreenTouch":
			var e_touch := InputEventScreenTouch.new()
			e_touch.index = int(data.get("index", 0))
			var touch_position: Variant = data.get("position", null)
			if touch_position is Vector2:
				e_touch.position = touch_position
			e_touch.pressed = bool(data.get("pressed", false))
			return e_touch

		"screen_drag", "InputEventScreenDrag":
			var e_drag := InputEventScreenDrag.new()
			e_drag.index = int(data.get("index", 0))
			var drag_position: Variant = data.get("position", null)
			if drag_position is Vector2:
				e_drag.position = drag_position
			var drag_relative: Variant = data.get("relative", null)
			if drag_relative is Vector2:
				e_drag.relative = drag_relative
			var drag_velocity: Variant = data.get("velocity", null)
			if drag_velocity is Vector2:
				e_drag.velocity = drag_velocity
			return e_drag

		_:
			push_warning("U_InputEventSerialization.dict_to_event: Unknown event type: %s" % event_type)

	return null

