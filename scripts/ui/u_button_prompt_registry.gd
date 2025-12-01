extends RefCounted
class_name U_ButtonPromptRegistry

const DEVICE_KEYBOARD_MOUSE := 0
const DEVICE_GAMEPAD := 1
const DEVICE_TOUCHSCREEN := 2

static var _prompt_registry: Dictionary = {}
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialize_registry()
	_initialized = true

static func _initialize_registry() -> void:
	_prompt_registry.clear()
	var keyboard_base := "res://resources/button_prompts/keyboard/"
	var gamepad_base := "res://resources/button_prompts/gamepad/"

	var mobile_base := "res://resources/button_prompts/mobile/"

	_assign_prompt(StringName("ui_accept"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_space.png", "Enter")
	_assign_prompt(StringName("ui_accept"), DEVICE_GAMEPAD, gamepad_base + "button_south.png", "A")
	_assign_prompt(StringName("ui_accept"), DEVICE_TOUCHSCREEN, mobile_base + "button_background.png", "Accept")

	_assign_prompt(StringName("ui_cancel"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_escape.png", "Esc")
	_assign_prompt(StringName("ui_cancel"), DEVICE_GAMEPAD, gamepad_base + "button_east.png", "B")
	_assign_prompt(StringName("ui_cancel"), DEVICE_TOUCHSCREEN, mobile_base + "button_background.png", "Back")

	_assign_prompt(StringName("ui_pause"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_escape.png", "Esc")
	_assign_prompt(StringName("ui_pause"), DEVICE_GAMEPAD, gamepad_base + "button_start.png", "Start")
	_assign_prompt(StringName("ui_pause"), DEVICE_TOUCHSCREEN, mobile_base + "button_background.png", "Pause")

	_assign_prompt(StringName("interact"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_e.png", "E")
	_assign_prompt(StringName("interact"), DEVICE_GAMEPAD, gamepad_base + "button_west.png", "West")
	_assign_prompt(StringName("interact"), DEVICE_TOUCHSCREEN, mobile_base + "button_background.png", "Interact")

	_assign_prompt(StringName("jump"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_space.png")
	_assign_prompt(StringName("jump"), DEVICE_GAMEPAD, gamepad_base + "button_south.png")

	_assign_prompt(StringName("sprint"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_shift.png")
	_assign_prompt(StringName("sprint"), DEVICE_GAMEPAD, gamepad_base + "button_ls.png", "L3")

	_assign_prompt(StringName("pause"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_escape.png")
	_assign_prompt(StringName("pause"), DEVICE_GAMEPAD, gamepad_base + "button_start.png")

	_assign_prompt(StringName("move_forward"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_w.png")
	_assign_prompt(StringName("move_forward"), DEVICE_GAMEPAD, gamepad_base + "dpad_up.png")

	_assign_prompt(StringName("move_backward"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_s.png")
	_assign_prompt(StringName("move_backward"), DEVICE_GAMEPAD, gamepad_base + "dpad_down.png")

	_assign_prompt(StringName("move_left"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_a.png")
	_assign_prompt(StringName("move_left"), DEVICE_GAMEPAD, gamepad_base + "dpad_left.png")

	_assign_prompt(StringName("move_right"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_d.png")
	_assign_prompt(StringName("move_right"), DEVICE_GAMEPAD, gamepad_base + "dpad_right.png")

	# UI navigation - use d-pad graphics for both keyboard and gamepad
	# (keyboard arrow keys will show gamepad-style directional icons)
	_assign_prompt(StringName("ui_up"), DEVICE_KEYBOARD_MOUSE, gamepad_base + "dpad_up.png", "↑")
	_assign_prompt(StringName("ui_up"), DEVICE_GAMEPAD, gamepad_base + "dpad_up.png")
	_assign_prompt(StringName("ui_down"), DEVICE_KEYBOARD_MOUSE, gamepad_base + "dpad_down.png", "↓")
	_assign_prompt(StringName("ui_down"), DEVICE_GAMEPAD, gamepad_base + "dpad_down.png")
	_assign_prompt(StringName("ui_left"), DEVICE_KEYBOARD_MOUSE, gamepad_base + "dpad_left.png", "←")
	_assign_prompt(StringName("ui_left"), DEVICE_GAMEPAD, gamepad_base + "dpad_left.png")
	_assign_prompt(StringName("ui_right"), DEVICE_KEYBOARD_MOUSE, gamepad_base + "dpad_right.png", "→")
	_assign_prompt(StringName("ui_right"), DEVICE_GAMEPAD, gamepad_base + "dpad_right.png")

	_assign_prompt(StringName("toggle_inventory"), DEVICE_GAMEPAD, gamepad_base + "button_select.png")
	_assign_prompt(StringName("toggle_inventory"), DEVICE_KEYBOARD_MOUSE, keyboard_base + "key_e.png")

static func register_prompt(
	action: StringName,
	device: int,
	texture_path: String,
	label: String = ""
) -> void:
	_ensure_initialized()
	_assign_prompt(action, device, texture_path, label)

static func get_prompt(action: StringName, device: int) -> Texture2D:
	_ensure_initialized()
	var entry := _get_device_entry(action, device)
	if entry.is_empty():
		return null

	# Check cache first
	var cached_texture: Variant = entry.get("texture", null)
	if cached_texture != null and cached_texture is Texture2D:
		return cached_texture as Texture2D

	# Load texture from path
	var texture_path: String = entry.get("path", "")
	if texture_path.is_empty():
		return null

	# Check file exists before loading to avoid errors
	if not ResourceLoader.exists(texture_path):
		return null

	var texture: Texture2D = load(texture_path)
	if texture == null:
		return null  # Graceful degradation

	# Cache for future calls
	entry["texture"] = texture
	_set_device_entry(action, device, entry)
	return texture

static func get_prompt_text(action: StringName, device: int) -> String:
	_ensure_initialized()
	var action_label := _get_label_for_action(action, device)
	var fallback_label := _fallback_label_from_entry(action, device)
	if not fallback_label.is_empty():
		action_label = fallback_label
	if device == DEVICE_TOUCHSCREEN:
		if action_label.is_empty():
			action_label = _format_action_name(action)
		return "Tap %s" % action_label
	if action_label.is_empty():
		action_label = _format_action_name(action)
	if action_label.is_empty():
		return ""
	return "Press [%s]" % action_label

static func get_binding_label(action: StringName, device: int) -> String:
	_ensure_initialized()
	var label := _get_label_for_action(action, device)
	if label.is_empty():
		label = _fallback_label_from_entry(action, device)
	return label

static func _fallback_label_from_entry(action: StringName, device: int) -> String:
	var entry := _get_device_entry(action, device)
	if entry.is_empty():
		return ""
	var label: String = entry.get("label", "")
	if label.is_empty():
		return ""
	return label

static func _get_label_for_action(action: StringName, device: int) -> String:
	var action_name := String(action)
	if not InputMap.has_action(action_name):
		return ""
	var events := InputMap.action_get_events(action_name)
	match device:
		DEVICE_KEYBOARD_MOUSE:
			return _label_from_keyboard_events(events)
		DEVICE_GAMEPAD:
			return _label_from_gamepad_events(events)
		DEVICE_TOUCHSCREEN:
			return ""
		_:
			return ""

static func _label_from_keyboard_events(events: Array) -> String:
	for event in events:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.echo:
				continue
			var keycode := key_event.physical_keycode
			if keycode == 0:
				keycode = key_event.keycode
			if keycode != 0:
				return OS.get_keycode_string(keycode)
		elif event is InputEventMouseButton:
			return _mouse_button_to_label((event as InputEventMouseButton).button_index)
	return ""

static func _label_from_gamepad_events(events: Array) -> String:
	for event in events:
		if event is InputEventJoypadButton:
			return _gamepad_button_to_label((event as InputEventJoypadButton).button_index)
		elif event is InputEventJoypadMotion:
			return _gamepad_axis_to_label((event as InputEventJoypadMotion).axis)
	return ""

static func _mouse_button_to_label(button_index: int) -> String:
	match button_index:
		1:
			return "Mouse L"
		2:
			return "Mouse R"
		3:
			return "Mouse M"
		_:
			return "Mouse %d" % button_index

static func _gamepad_button_to_label(button_index: int) -> String:
	match button_index:
		0:
			return "South"
		1:
			return "East"
		2:
			return "West"
		3:
			return "North"
		4:
			return "L1"
		5:
			return "R1"
		6:
			return "L2"
		7:
			return "R2"
		8:
			return "Select"
		9:
			return "Start"
		10:
			return "L3"
		11:
			return "R3"
		12:
			return "D-Pad Up"
		13:
			return "D-Pad Down"
		14:
			return "D-Pad Left"
		15:
			return "D-Pad Right"
		16:
			return "Guide"
		_:
			return "Button %d" % button_index

static func _gamepad_axis_to_label(axis: int) -> String:
	match axis:
		0, 1:
			return "Left Stick"
		2, 3:
			return "Right Stick"
		4:
			return "LT"
		5:
			return "RT"
		_:
			return "Axis %d" % axis

static func _derive_label_from_path(texture_path: String) -> String:
	if texture_path.is_empty():
		return ""
	var filename := texture_path.get_file()
	if filename.is_empty():
		return ""
	var basename := filename.get_basename()
	if basename.is_empty():
		return ""
	var cleaned := basename
	var prefixes := ["key_", "button_", "btn_", "icon_", "kb_", "mouse_"]
	for prefix in prefixes:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length())
			break

	if cleaned == "ls":
		return "L3"
	if cleaned == "rs":
		return "R3"
	if cleaned.begins_with("dpad_"):
		var dir := cleaned.substr("dpad_".length())
		if dir.is_empty():
			return "D-Pad"
		return "D-Pad %s" % dir.capitalize()

	var tokens := cleaned.split("_")
	if tokens.is_empty():
		return cleaned.capitalize()
	var formatted := []
	for token in tokens:
		if token.is_empty():
			continue
		if token.length() == 1:
			formatted.append(token.to_upper())
		else:
			formatted.append(token.capitalize())
	if formatted.is_empty():
		return cleaned.capitalize()
	return " ".join(formatted)

static func _format_action_name(action: StringName) -> String:
	var text := String(action)
	if text.is_empty():
		return ""
	var tokens := text.split("_")
	var formatted := []
	for token in tokens:
		if token.is_empty():
			continue
		formatted.append(token.capitalize())
	return " ".join(formatted)

static func _normalize_action_key(action: StringName) -> StringName:
	if typeof(action) == TYPE_STRING_NAME:
		return action
	if typeof(action) == TYPE_STRING:
		return StringName(action)
	return StringName(String(action))

static func _get_device_entry(action: StringName, device: int) -> Dictionary:
	var action_key := _normalize_action_key(action)
	if not _prompt_registry.has(action_key):
		return {}
	var device_map_variant: Variant = _prompt_registry.get(action_key, {})
	if not (device_map_variant is Dictionary):
		return {}
	return (device_map_variant as Dictionary).get(device, {})

static func _set_device_entry(action: StringName, device: int, entry: Dictionary) -> void:
	var action_key := _normalize_action_key(action)
	var device_map_variant: Variant = _prompt_registry.get(action_key, {})
	var device_map: Dictionary = {}
	if device_map_variant is Dictionary:
		device_map = (device_map_variant as Dictionary).duplicate(true)
	device_map[device] = entry.duplicate(true)
	_prompt_registry[action_key] = device_map

static func _assign_prompt(
	action: StringName,
	device: int,
	texture_path: String,
	label: String = ""
) -> void:
	if texture_path.is_empty():
		return
	var action_key := _normalize_action_key(action)
	var device_prompts_variant: Variant = _prompt_registry.get(action_key, {})
	var device_prompts: Dictionary = {}
	if device_prompts_variant is Dictionary:
		device_prompts = (device_prompts_variant as Dictionary).duplicate(true)
	var prompt_label := label
	if prompt_label.is_empty():
		prompt_label = _derive_label_from_path(texture_path)
	var entry := {
		"path": texture_path,
		"texture": null,
		"label": prompt_label
	}
	device_prompts[device] = entry
	_prompt_registry[action_key] = device_prompts

static func _clear_for_tests() -> void:
	_prompt_registry.clear()
	_initialized = false
