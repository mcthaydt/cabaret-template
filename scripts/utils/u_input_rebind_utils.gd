extends RefCounted
class_name U_InputRebindUtils

const RS_RebindSettings := preload("res://scripts/ecs/resources/rs_rebind_settings.gd")
const RS_InputProfile := preload("res://scripts/ecs/resources/rs_input_profile.gd")

class ValidationResult extends RefCounted:
	var valid: bool = true
	var error: String = ""
	var conflict_action: StringName = StringName()

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

static func validate_rebind(
	action: StringName,
	event: InputEvent,
	settings: RS_RebindSettings,
	replace_existing: bool = true,
	profile: RS_InputProfile = null,
	excluded_actions: Array = []
) -> ValidationResult:
	var result := ValidationResult.new()
	if action == StringName():
		result.valid = false
		result.error = "Action name is required."
		return result

	if event == null:
		result.valid = false
		result.error = "Input event is required."
		return result

	if settings == null:
		settings = RS_RebindSettings.new()

	if is_reserved_action(action, settings):
		result.valid = false
		result.error = "Cannot rebind reserved action."
		return result

	var conflict := get_conflicting_action(event, profile, action, excluded_actions)
	if conflict != StringName() and conflict != action:
		if is_reserved_action(conflict, settings):
			result.valid = false
			result.error = "Cannot reassign input from reserved action."
			return result

		if settings.allow_conflicts:
			result.conflict_action = StringName()
		elif settings.require_confirmation:
			result.conflict_action = conflict
		else:
			result.valid = false
			result.error = "Input already bound to %s." % String(conflict)

	if settings.max_events_per_action > 0 and not replace_existing:
		var existing_events := InputMap.action_get_events(action)
		var already_present := false
		for existing in existing_events:
			if _events_match(existing, event):
				already_present = true
				break
		if not already_present and existing_events.size() >= settings.max_events_per_action:
			result.valid = false
			result.error = "Maximum bindings reached for action."
			return result

	return result

static func rebind_action(
	action: StringName,
	event: InputEvent,
	profile: RS_InputProfile = null,
	conflict_action: StringName = StringName(),
	replace_existing: bool = true
) -> bool:
	if action == StringName() or event == null:
		return false

	if not InputMap.has_action(action):
		return false

	var event_copy := event.duplicate(true)

	if conflict_action != StringName() and InputMap.has_action(conflict_action):
		_remove_event_from_action(conflict_action, event_copy)
		if profile:
			var conflict_events := profile.get_events_for_action(conflict_action)
			var filtered: Array[InputEvent] = []
			for existing in conflict_events:
				if not _events_match(existing, event_copy):
					filtered.append(existing.duplicate(true))
			profile.set_events_for_action(conflict_action, filtered)

	if replace_existing:
		InputMap.action_erase_events(action)
	else:
		_remove_event_from_action(action, event_copy)
	InputMap.action_add_event(action, event_copy)

	if profile:
		var new_events: Array[InputEvent] = []
		if not replace_existing:
			for existing_event in profile.get_events_for_action(action):
				if existing_event is InputEvent and not _events_match(existing_event, event_copy):
					new_events.append(existing_event.duplicate(true))
		new_events.append(event_copy.duplicate(true))
		profile.set_events_for_action(action, new_events)

	return true

static func get_conflicting_action(
	event: InputEvent,
	profile: RS_InputProfile = null,
	ignore_action: StringName = StringName(),
	excluded_actions: Array = []
) -> StringName:
	if event == null:
		return StringName()

	var prioritized_matches: Array[StringName] = []
	var fallback_matches: Array[StringName] = []
	var actions := InputMap.get_actions()
	for i in range(actions.size() - 1, -1, -1):
		var action := actions[i]
		var action_name := StringName(action)
		if action_name == ignore_action:
			continue
		# Skip excluded actions (like built-in ui_ actions not shown in rebinding menu)
		var action_str := String(action_name)
		if action_str in excluded_actions:
			continue
		for existing_event in InputMap.action_get_events(action_name):
			if _events_match(existing_event, event):
				if profile != null and profile.has_action(action_name):
					return action_name
				if action_str.begins_with("ui_") or action_str.begins_with("editor"):
					fallback_matches.append(action_name)
				else:
					prioritized_matches.append(action_name)
				break

	if not prioritized_matches.is_empty():
		return prioritized_matches[0]
	if not fallback_matches.is_empty():
		return fallback_matches[0]
	return StringName()

static func is_reserved_action(action: StringName, settings: RS_RebindSettings) -> bool:
	if settings == null:
		return false
	return settings.is_reserved(action)

static func event_to_dict(event: InputEvent) -> Dictionary:
	if event == null:
		return {}
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": (event as InputEventKey).keycode,
			"physical_keycode": (event as InputEventKey).physical_keycode,
			"unicode": (event as InputEventKey).unicode,
			"pressed": (event as InputEventKey).pressed,
			"echo": (event as InputEventKey).echo,
			"alt": (event as InputEventKey).alt_pressed,
			"shift": (event as InputEventKey).shift_pressed,
			"ctrl": (event as InputEventKey).ctrl_pressed,
			"meta": (event as InputEventKey).meta_pressed
		}
	elif event is InputEventMouseButton:
		return {
			"type": "mouse_button",
			"button_index": (event as InputEventMouseButton).button_index,
			"pressed": (event as InputEventMouseButton).pressed,
			"double_click": (event as InputEventMouseButton).double_click,
			"position": (event as InputEventMouseButton).position,
			"global_position": (event as InputEventMouseButton).global_position
		}
	elif event is InputEventJoypadButton:
		return {
			"type": "joypad_button",
			"button_index": (event as InputEventJoypadButton).button_index,
			"pressed": (event as InputEventJoypadButton).pressed,
			"pressure": (event as InputEventJoypadButton).pressure
		}
	elif event is InputEventJoypadMotion:
		return {
			"type": "joypad_motion",
			"axis": (event as InputEventJoypadMotion).axis,
			"axis_value": (event as InputEventJoypadMotion).axis_value
		}
	elif event is InputEventScreenTouch:
		return {
			"type": "screen_touch",
			"index": (event as InputEventScreenTouch).index,
			"position": (event as InputEventScreenTouch).position,
			"pressed": (event as InputEventScreenTouch).pressed
		}
	elif event is InputEventScreenDrag:
		return {
			"type": "screen_drag",
			"index": (event as InputEventScreenDrag).index,
			"position": (event as InputEventScreenDrag).position,
			"relative": (event as InputEventScreenDrag).relative,
			"velocity": (event as InputEventScreenDrag).velocity
		}
	push_warning("Unsupported InputEvent type: %s" % event.get_class())
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

			e_key.keycode = keycode_val
			e_key.physical_keycode = physical_keycode_val
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
			e_mouse.button_index = int(data.get("button_index", 0))
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
			e_button.button_index = int(data.get("button_index", 0))
			e_button.pressed = bool(data.get("pressed", false))
			e_button.pressure = float(data.get("pressure", 0.0))
			return e_button
		"joypad_motion", "InputEventJoypadMotion":
			var e_motion := InputEventJoypadMotion.new()
			e_motion.axis = int(data.get("axis", 0))
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
			push_warning("Unknown event type: %s" % event_type)
	return null

static func _remove_event_from_action(action: StringName, event: InputEvent) -> void:
	var retained: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if not _events_match(existing, event):
			retained.append(existing)

	InputMap.action_erase_events(action)
	for retained_event in retained:
		InputMap.action_add_event(action, retained_event)

static func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var key_a := a as InputEventKey
		var key_b := b as InputEventKey
		# Prefer physical keycode when available since project uses physical-only defaults.
		var phys_a := key_a.physical_keycode
		var phys_b := key_b.physical_keycode
		var code_a := key_a.keycode
		var code_b := key_b.keycode
		if phys_a != 0 or phys_b != 0:
			if phys_a != 0 and phys_b != 0 and phys_a == phys_b:
				return true
			if phys_a != 0 and code_b != 0 and phys_a == code_b:
				return true
			if phys_b != 0 and code_a != 0 and phys_b == code_a:
				return true
		if code_a != 0 and code_b != 0:
			return key_a.keycode == key_b.keycode
	return a.is_match(b) and b.is_match(a)
