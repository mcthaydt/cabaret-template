extends RefCounted
class_name U_InputEventDisplay

## Helpers for converting InputEvents into user-facing labels and glyphs.
##
## Used by rebinding UIs and button prompt widgets to present readable
## descriptions and associated textures for bindings.

static func format_event_label(event: InputEvent) -> String:
	if event == null:
		return ""

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var axis := motion.axis
		var value := motion.axis_value
		if axis == 4:
			return "Left Trigger"
		elif axis == 5:
			return "Right Trigger"
		if axis == JOY_AXIS_LEFT_X:
			if value < 0.0:
				return "Left Joystick Left"
			elif value > 0.0:
				return "Left Joystick Right"
		elif axis == JOY_AXIS_LEFT_Y:
			if value < 0.0:
				return "Left Joystick Up"
			elif value > 0.0:
				return "Left Joystick Down"
		elif axis == JOY_AXIS_RIGHT_X:
			if value < 0.0:
				return "Right Joystick Left"
			elif value > 0.0:
				return "Right Joystick Right"
		elif axis == JOY_AXIS_RIGHT_Y:
			if value < 0.0:
				return "Right Joystick Up"
			elif value > 0.0:
				return "Right Joystick Down"
		# Fallback to Godot's default text when direction cannot be determined.
		return motion.as_text()

	if event is InputEventKey:
		return (event as InputEventKey).as_text()
	if event is InputEventJoypadButton:
		return _format_joypad_button_label((event as InputEventJoypadButton).button_index)
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).as_text()
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).as_text()
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).as_text()
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).as_text()

	return event.as_text()

static func _format_joypad_button_label(index: int) -> String:
	match index:
		JOY_BUTTON_A:
			return "Bottom Action"
		JOY_BUTTON_B:
			return "Right Action"
		JOY_BUTTON_X:
			return "Left Action"
		JOY_BUTTON_Y:
			return "Top Action"
		JOY_BUTTON_LEFT_SHOULDER:
			return "Left Bumper"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "Right Bumper"
		JOY_BUTTON_LEFT_STICK:
			return "Left Stick Held"
		JOY_BUTTON_RIGHT_STICK:
			return "Right Stick Click"
		JOY_BUTTON_BACK:
			return "Select/Back"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_GUIDE:
			return "Guide"
		JOY_BUTTON_DPAD_UP:
			return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Pad Right"
		_:
			return "Button %d" % index

## Returns a texture icon for the given InputEvent, or null if no icon exists.
## Used by UI components to display visual representations of key bindings.
static func get_texture_for_event(event: InputEvent) -> Texture2D:
	if event == null:
		return null

	if event is InputEventKey:
		var key_event := event as InputEventKey
		var keycode := key_event.physical_keycode
		if keycode == 0:
			keycode = key_event.keycode
		var key_name := ""
		var folder := "keyboard"
		match keycode:
			KEY_W:
				key_name = "key_w"
			KEY_A:
				key_name = "key_a"
			KEY_S:
				key_name = "key_s"
			KEY_D:
				key_name = "key_d"
			KEY_E:
				key_name = "key_e"
			KEY_SPACE:
				key_name = "key_space"
			KEY_SHIFT:
				key_name = "key_shift"
			KEY_ESCAPE:
				key_name = "key_escape"
			KEY_UP:
				key_name = "dpad_up"
				folder = "gamepad"
			KEY_DOWN:
				key_name = "dpad_down"
				folder = "gamepad"
			KEY_LEFT:
				key_name = "dpad_left"
				folder = "gamepad"
			KEY_RIGHT:
				key_name = "dpad_right"
				folder = "gamepad"
		if not key_name.is_empty():
			var path := "res://assets/button_prompts/%s/%s.png" % [folder, key_name]
			if ResourceLoader.exists(path):
				return load(path)

	elif event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		var button_name := ""
		match joy_button.button_index:
			JOY_BUTTON_A:
				button_name = "face_buttons_south"
			JOY_BUTTON_B:
				button_name = "face_buttons_east"
			JOY_BUTTON_X:
				button_name = "face_buttons_west"
			JOY_BUTTON_Y:
				button_name = "face_buttons_north"
			JOY_BUTTON_LEFT_SHOULDER:
				button_name = "button_lb"
			JOY_BUTTON_RIGHT_SHOULDER:
				button_name = "button_rb"
			JOY_BUTTON_LEFT_STICK:
				button_name = "button_ls"
			JOY_BUTTON_RIGHT_STICK:
				button_name = "button_rs"
			JOY_BUTTON_START:
				button_name = "button_start"
			JOY_BUTTON_BACK:
				button_name = "button_select"
			JOY_BUTTON_DPAD_UP:
				button_name = "dpad_up"
			JOY_BUTTON_DPAD_DOWN:
				button_name = "dpad_down"
			JOY_BUTTON_DPAD_LEFT:
				button_name = "dpad_left"
			JOY_BUTTON_DPAD_RIGHT:
				button_name = "dpad_right"

		if not button_name.is_empty():
			var path := "res://assets/button_prompts/gamepad/%s.png" % button_name
			if ResourceLoader.exists(path):
				return load(path)

	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var axis := motion.axis
		var value := motion.axis_value
		var stick_name := ""

		match axis:
			JOY_AXIS_LEFT_X:
				if value < 0.0:
					stick_name = "ls_left"
				elif value > 0.0:
					stick_name = "ls_right"
			JOY_AXIS_LEFT_Y:
				if value < 0.0:
					stick_name = "ls_up"
				elif value > 0.0:
					stick_name = "ls_down"
			JOY_AXIS_RIGHT_X:
				if value < 0.0:
					stick_name = "rs_left"
				elif value > 0.0:
					stick_name = "rs_right"
			JOY_AXIS_RIGHT_Y:
				if value < 0.0:
					stick_name = "rs_up"
				elif value > 0.0:
					stick_name = "rs_down"

		if not stick_name.is_empty():
			var path := "res://assets/button_prompts/gamepad/%s.png" % stick_name
			if ResourceLoader.exists(path):
				return load(path)

	return null
