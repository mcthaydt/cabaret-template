extends Resource
class_name RS_InputProfile

## Input profile resource defining bindings and metadata.
##
## Schema validation (F15): profile_name must be non-empty. Loaded profiles
## (with resource_path) must have non-empty action_mappings. Each virtual_buttons
## entry must have 'action' and 'position' keys. virtual_joystick_position
## values other than (-1,-1) must have non-negative coordinates.

var _profile_name: String = "Default"

@export var profile_name: String = "Default":
	get:
		return _profile_name
	set(value):
		_profile_name = value
		if value == "":
			push_error("RS_InputProfile: profile_name must not be empty. Resource: %s" % resource_path)

@export_enum("Keyboard/Mouse:0", "Gamepad:1", "Touchscreen:2") var device_type: int = 0

var _action_mappings: Dictionary = {}

@export var action_mappings: Dictionary = {}:
	get:
		return _action_mappings
	set(value):
		_action_mappings = value
		if value.is_empty() and resource_path != "":
			push_error("RS_InputProfile: action_mappings must not be empty for loaded profiles. Resource: %s" % resource_path)

@export_multiline var description: String = "Standard WASD keyboard layout with Space to jump"
@export var is_system_profile: bool = true
@export var profile_icon: Texture2D

@export_group("Accessibility")
@export_range(0.0, 1.0) var jump_buffer_time: float = 0.1
@export var sprint_toggle_mode: bool = false
@export_range(0.0, 2.0) var interact_hold_duration: float = 0.0

@export_group("Touchscreen")

var _virtual_buttons: Array[Dictionary] = []

@export var virtual_buttons: Array[Dictionary] = []:  # [{action: StringName, position: Vector2}]
	get:
		return _virtual_buttons
	set(value):
		_virtual_buttons = value
		_validate_virtual_buttons()

var _virtual_joystick_position: Vector2 = Vector2(-1, -1)

@export var virtual_joystick_position: Vector2 = Vector2(-1, -1):  # Default position, -1,-1 = not set
	get:
		return _virtual_joystick_position
	set(value):
		_virtual_joystick_position = value
		if value != Vector2(-1, -1) and (value.x < 0.0 or value.y < 0.0):
			push_error("RS_InputProfile: virtual_joystick_position must have non-negative coordinates when set (or (-1,-1) for not-set). Resource: %s" % resource_path)

func _validate_virtual_buttons() -> void:
	for i in _virtual_buttons.size():
		var entry: Dictionary = _virtual_buttons[i]
		if not entry.has("action"):
			push_error("RS_InputProfile: virtual_buttons entry %d missing 'action' key. Resource: %s" % [i, resource_path])
		if not entry.has("position"):
			push_error("RS_InputProfile: virtual_buttons entry %d missing 'position' key. Resource: %s" % [i, resource_path])

func get_events_for_action(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not action_mappings.has(action):
		return result
	var src: Array = action_mappings[action] as Array
	for e in src:
		if e is InputEvent:
			result.append(e as InputEvent)
		elif e is Dictionary:
			var ev: InputEvent = U_InputRebindUtils.dict_to_event(e as Dictionary)
			if ev is InputEvent:
				result.append(ev)
	return result

func set_events_for_action(action: StringName, events: Array[InputEvent]) -> void:
	action_mappings[action] = events.duplicate(true)

func has_action(action: StringName) -> bool:
	if action_mappings.has(action):
		return true
	var action_key := String(action)
	return action_mappings.has(action_key)

func to_dictionary() -> Dictionary:
	var result := {
		"profile_name": profile_name,
		"device_type": device_type,
		"description": description,
		"is_system_profile": is_system_profile,
		"action_mappings": {}
	}
	for action in action_mappings.keys():
		var events_data := []
		for event in (action_mappings[action] as Array):
			if event is InputEvent:
				events_data.append(U_InputRebindUtils.event_to_dict(event))
			elif event is Dictionary:
				var parsed := U_InputRebindUtils.dict_to_event(event)
				if parsed != null:
					events_data.append(U_InputRebindUtils.event_to_dict(parsed))
		result["action_mappings"][String(action)] = events_data

	# Serialize touchscreen fields (Vector2 -> {x, y} dict for JSON compatibility)
	result["virtual_joystick_position"] = {
		"x": virtual_joystick_position.x,
		"y": virtual_joystick_position.y
	}

	# Serialize virtual buttons array (convert Vector2 positions to dicts)
	var serialized_buttons: Array = []
	for button_dict in virtual_buttons:
		var serialized_button := {}
		if button_dict.has("action"):
			serialized_button["action"] = String(button_dict["action"])
		if button_dict.has("position") and button_dict["position"] is Vector2:
			var pos: Vector2 = button_dict["position"]
			serialized_button["position"] = {"x": pos.x, "y": pos.y}
		serialized_buttons.append(serialized_button)
	result["virtual_buttons"] = serialized_buttons

	return result

func from_dictionary(data: Dictionary) -> void:
	profile_name = data.get("profile_name", "Unnamed")
	device_type = int(data.get("device_type", 0))
	description = data.get("description", "")
	is_system_profile = bool(data.get("is_system_profile", false))
	action_mappings.clear()
	var mappings: Dictionary = data.get("action_mappings", {})
	for action in mappings.keys():
		var events := []
		for event_data in (mappings[action] as Array):
			var event := U_InputRebindUtils.dict_to_event(event_data)
			if event != null:
				events.append(event)
		if not events.is_empty():
			action_mappings[StringName(action)] = events

	# Deserialize touchscreen fields ({x, y} dict -> Vector2)
	if data.has("virtual_joystick_position"):
		var pos_dict: Variant = data["virtual_joystick_position"]
		if pos_dict is Dictionary:
			virtual_joystick_position = Vector2(
				float(pos_dict.get("x", -1.0)),
				float(pos_dict.get("y", -1.0))
			)
		elif pos_dict is Vector2:
			# Support direct Vector2 for backward compatibility
			virtual_joystick_position = pos_dict

	# Deserialize virtual buttons array (convert position dicts to Vector2)
	if data.has("virtual_buttons"):
		var buttons_variant: Variant = data["virtual_buttons"]
		if buttons_variant is Array:
			virtual_buttons.clear()
			for button_data in buttons_variant:
				if button_data is Dictionary:
					var button_dict := {}
					if button_data.has("action"):
						button_dict["action"] = StringName(button_data["action"])
					if button_data.has("position"):
						var pos_variant: Variant = button_data["position"]
						if pos_variant is Dictionary:
							button_dict["position"] = Vector2(
								float(pos_variant.get("x", 0.0)),
								float(pos_variant.get("y", 0.0))
							)
						elif pos_variant is Vector2:
							# Support direct Vector2 for backward compatibility
							button_dict["position"] = pos_variant
					virtual_buttons.append(button_dict)
