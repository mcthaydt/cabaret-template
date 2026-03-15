extends RefCounted
class_name U_InputSelectors

## Selectors for gameplay input + input settings slices.

static func get_active_device(state: Dictionary) -> int:
	return get_active_device_type(state)

static func get_active_device_type(state: Dictionary) -> int:
	var input_state := _get_input_state(state)
	return int(input_state.get("active_device_type", input_state.get("active_device", 0)))

static func get_active_gamepad_id(state: Dictionary) -> int:
	var input_state := _get_input_state(state)
	return int(input_state.get("active_gamepad_id", input_state.get("gamepad_device_id", -1)))

static func get_move_input(state: Dictionary) -> Vector2:
	var value: Variant = _get_input_state(state).get("move_input", Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO

static func get_look_input(state: Dictionary) -> Vector2:
	var value: Variant = _get_input_state(state).get("look_input", Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO

static func is_aim_pressed(state: Dictionary) -> bool:
	return bool(_get_input_state(state).get("aim_pressed", false))

static func is_camera_center_just_pressed(state: Dictionary) -> bool:
	return bool(_get_input_state(state).get("camera_center_just_pressed", false))

static func is_jump_pressed(state: Dictionary) -> bool:
	return bool(_get_input_state(state).get("jump_pressed", false))

static func is_sprint_pressed(state: Dictionary) -> bool:
	return bool(_get_input_state(state).get("sprint_pressed", false))

static func is_gamepad_connected(state: Dictionary) -> bool:
	return bool(_get_input_state(state).get("gamepad_connected", false))

static func get_gamepad_device_id(state: Dictionary) -> int:
	return get_active_gamepad_id(state)

static func get_active_profile_id(state: Dictionary) -> String:
	var settings: Dictionary = _get_input_settings_state(state)
	return String(settings.get("active_profile_id", "default"))

static func get_gamepad_settings(state: Dictionary) -> Dictionary:
	var settings: Variant = _get_input_settings_state(state).get("gamepad_settings", {})
	if settings is Dictionary:
		return (settings as Dictionary).duplicate(true)
	return {}

static func get_mouse_settings(state: Dictionary) -> Dictionary:
	var settings: Variant = _get_input_settings_state(state).get("mouse_settings", {})
	if settings is Dictionary:
		return (settings as Dictionary).duplicate(true)
	return {}

static func get_touchscreen_settings(state: Dictionary) -> Dictionary:
	var settings: Variant = _get_input_settings_state(state).get("touchscreen_settings", {})
	if settings is Dictionary:
		return (settings as Dictionary).duplicate(true)
	return {}

## Get custom position for a virtual control (joystick or button).
## Returns null if not customized or if sentinel value Vector2(-1, -1).
## Caller should fall back to profile default when null.
static func get_virtual_control_position(state: Dictionary, control_name: String) -> Variant:
	var touchscreen_settings: Dictionary = _get_input_settings_state(state).get("touchscreen_settings", {})

	if control_name == "virtual_joystick":
		var position: Variant = touchscreen_settings.get("custom_joystick_position")
		if position is Vector2:
			# Check for sentinel value (-1, -1) = use profile default
			if position == Vector2(-1, -1):
				return null
			return position
		return null
	else:
		# Button position
		var custom_positions: Variant = touchscreen_settings.get("custom_button_positions", {})
		if custom_positions is Dictionary:
			var position: Variant = (custom_positions as Dictionary).get(control_name)
			if position == null:
				var control_name_sn := StringName(control_name)
				if (custom_positions as Dictionary).has(control_name_sn):
					position = (custom_positions as Dictionary).get(control_name_sn)
			if position is Vector2:
				return position
		return null

static func _get_input_state(state: Dictionary) -> Dictionary:
	var direct_input: Variant = state.get("input")
	if direct_input is Dictionary:
		return direct_input as Dictionary
	return _get_gameplay_input_state(state)

static func _get_gameplay_input_state(state: Dictionary) -> Dictionary:
	var gameplay: Variant = state.get("gameplay", {})
	if gameplay is Dictionary and (gameplay as Dictionary).has("input") and (gameplay as Dictionary)["input"] is Dictionary:
		return (gameplay as Dictionary)["input"] as Dictionary
	return {}

static func _get_input_settings_state(state: Dictionary) -> Dictionary:
	var settings: Variant = state.get("settings", {})
	if not (settings is Dictionary and (settings as Dictionary).has("input_settings") and (settings as Dictionary)["input_settings"] is Dictionary):
		return {}
	return (settings as Dictionary)["input_settings"] as Dictionary
