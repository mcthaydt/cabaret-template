extends GutTest

const U_InputRebindUtils := preload("res://scripts/utils/input/u_input_rebind_utils.gd")

func test_key_event_roundtrip_preserves_modifiers() -> void:
	var event := InputEventKey.new()
	event.keycode = Key.KEY_V
	event.physical_keycode = Key.KEY_V
	event.unicode = int("v".unicode_at(0))
	event.pressed = true
	event.echo = true
	event.alt_pressed = true
	event.shift_pressed = true
	event.ctrl_pressed = true
	event.meta_pressed = true

	var serialized := U_InputRebindUtils.event_to_dict(event)
	assert_eq(serialized.get("type"), "key")

	var restored := U_InputRebindUtils.dict_to_event(serialized) as InputEventKey
	assert_not_null(restored)
	assert_true(restored is InputEventKey)
	assert_eq(restored.keycode, event.keycode)
	assert_eq(restored.physical_keycode, event.physical_keycode)
	assert_eq(restored.unicode, event.unicode)
	assert_true(restored.pressed)
	assert_true(restored.echo)
	assert_true(restored.alt_pressed)
	assert_true(restored.shift_pressed)
	assert_true(restored.ctrl_pressed)
	assert_true(restored.meta_pressed)

func test_mouse_button_roundtrip_preserves_pressure() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MouseButton.MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.double_click = true
	event.position = Vector2(12, 24)
	event.global_position = Vector2(100, 200)

	var serialized := U_InputRebindUtils.event_to_dict(event)
	assert_eq(serialized.get("type"), "mouse_button")

	var restored := U_InputRebindUtils.dict_to_event(serialized) as InputEventMouseButton
	assert_not_null(restored)
	assert_true(restored is InputEventMouseButton)
	assert_eq(restored.button_index, event.button_index)
	assert_true(restored.pressed)
	assert_true(restored.double_click)
	assert_eq(restored.position, event.position)
	assert_eq(restored.global_position, event.global_position)

func test_joypad_button_roundtrip_preserves_pressure() -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JoyButton.JOY_BUTTON_B
	event.pressed = true
	event.pressure = 0.75

	var serialized := U_InputRebindUtils.event_to_dict(event)
	assert_eq(serialized.get("type"), "joypad_button")

	var restored := U_InputRebindUtils.dict_to_event(serialized) as InputEventJoypadButton
	assert_not_null(restored)
	assert_true(restored is InputEventJoypadButton)
	assert_eq(restored.button_index, event.button_index)
	assert_true(restored.pressed)
	assert_almost_eq(restored.pressure, event.pressure, 0.0001)

func test_joypad_motion_roundtrip_preserves_axis() -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JoyAxis.JOY_AXIS_RIGHT_X
	event.axis_value = -0.42

	var serialized := U_InputRebindUtils.event_to_dict(event)
	assert_eq(serialized.get("type"), "joypad_motion")

	var restored := U_InputRebindUtils.dict_to_event(serialized) as InputEventJoypadMotion
	assert_not_null(restored)
	assert_true(restored is InputEventJoypadMotion)
	assert_eq(restored.axis, event.axis)
	assert_almost_eq(restored.axis_value, event.axis_value, 0.0001)

func test_screen_touch_and_drag_roundtrip() -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = Vector2(400, 250)
	touch.pressed = true

	var touch_dict := U_InputRebindUtils.event_to_dict(touch)
	assert_eq(touch_dict.get("type"), "screen_touch")
	var restored_touch := U_InputRebindUtils.dict_to_event(touch_dict) as InputEventScreenTouch
	assert_not_null(restored_touch)
	assert_eq(restored_touch.index, touch.index)
	assert_eq(restored_touch.position, touch.position)
	assert_true(restored_touch.pressed)

	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(1280, 720)
	drag.relative = Vector2(10, -4)
	drag.velocity = Vector2(90, -30)

	var drag_dict := U_InputRebindUtils.event_to_dict(drag)
	assert_eq(drag_dict.get("type"), "screen_drag")
	var restored_drag := U_InputRebindUtils.dict_to_event(drag_dict) as InputEventScreenDrag
	assert_not_null(restored_drag)
	assert_eq(restored_drag.index, drag.index)
	assert_eq(restored_drag.position, drag.position)
	assert_eq(restored_drag.relative, drag.relative)
	assert_eq(restored_drag.velocity, drag.velocity)

func test_legacy_type_names_are_supported() -> void:
	var legacy_dict := {
		"type": "InputEventKey",
		"keycode": Key.KEY_H,
		"physical_keycode": 0,
		"unicode": int("h".unicode_at(0)),
		"pressed": true
	}
	var event := U_InputRebindUtils.dict_to_event(legacy_dict)
	assert_true(event is InputEventKey)
	assert_eq((event as InputEventKey).keycode, Key.KEY_H)
