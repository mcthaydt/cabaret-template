extends RefCounted
class_name U_InputSerialization


const SAVE_PATH := "user://input_settings.json"
const BACKUP_PATH := "user://input_settings.json.backup"
const CURRENT_VERSION := "1.0.0"

static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Failed to open %s for reading" % SAVE_PATH)
		return {}

	var raw_text := file.get_as_text()
	file = null

	var result: Variant = JSON.parse_string(raw_text)
	if typeof(result) != TYPE_DICTIONARY:
		_backup_corrupted_file(raw_text)
		push_warning("Input settings file corrupted; falling back to defaults.")
		return {}

	return _sanitize_loaded_settings(result as Dictionary)

static func save_settings(settings: Dictionary) -> bool:
	if settings == null:
		return false

	var payload := _prepare_save_payload(settings)
	var json_text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open %s for writing" % SAVE_PATH)
		return false
	file.store_string(json_text)
	file.flush()
	return true

static func serialize_settings(settings: Dictionary) -> Dictionary:
	if settings == null:
		return {}
	var payload := _prepare_save_payload(settings)
	if payload.has("version"):
		payload.erase("version")
	return payload

static func deserialize_settings(data: Dictionary) -> Dictionary:
	if data == null:
		return {}
	return _sanitize_loaded_settings(data)

static func _prepare_save_payload(settings: Dictionary) -> Dictionary:
	var payload := settings.duplicate(true)
	payload["version"] = CURRENT_VERSION

	if payload.has("custom_bindings"):
		payload["custom_bindings"] = _serialize_custom_bindings(payload["custom_bindings"])

	if payload.has("custom_bindings_by_profile"):
		payload["custom_bindings_by_profile"] = _serialize_custom_bindings_by_profile(payload["custom_bindings_by_profile"])

	# Convert Vector2 fields to {x, y} dictionaries for JSON compatibility
	if payload.has("touchscreen_settings"):
		payload["touchscreen_settings"] = _serialize_touchscreen_vector2_fields(payload["touchscreen_settings"])

	return payload

static func _sanitize_loaded_settings(data: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	var version := String(data.get("version", CURRENT_VERSION))
	sanitized["version"] = version

	if data.has("active_profile_id"):
		sanitized["active_profile_id"] = String(data["active_profile_id"])

	if data.has("custom_bindings"):
		sanitized["custom_bindings"] = _sanitize_custom_bindings(data["custom_bindings"])

	if data.has("custom_bindings_by_profile"):
		sanitized["custom_bindings_by_profile"] = _sanitize_custom_bindings_by_profile(data["custom_bindings_by_profile"])

	if data.has("gamepad_settings") and data["gamepad_settings"] is Dictionary:
		sanitized["gamepad_settings"] = _sanitize_float_fields(
			data["gamepad_settings"],
			{
				"left_stick_deadzone": Vector2(0.0, 0.9),
				"right_stick_deadzone": Vector2(0.0, 0.9),
				"trigger_deadzone": Vector2(0.0, 0.9),
				"vibration_intensity": Vector2(0.0, 1.0)
			}
		)
		sanitized["gamepad_settings"]["vibration_enabled"] = bool(
			(data["gamepad_settings"] as Dictionary).get("vibration_enabled", true)
		)
		sanitized["gamepad_settings"]["invert_y_axis"] = bool(
			(data["gamepad_settings"] as Dictionary).get("invert_y_axis", false)
		)

	if data.has("mouse_settings") and data["mouse_settings"] is Dictionary:
		sanitized["mouse_settings"] = _sanitize_float_fields(
			data["mouse_settings"],
			{
				"sensitivity": Vector2(0.1, 5.0)
			}
		)
		sanitized["mouse_settings"]["invert_y_axis"] = bool(
			(data["mouse_settings"] as Dictionary).get("invert_y_axis", false)
		)

	if data.has("touchscreen_settings") and data["touchscreen_settings"] is Dictionary:
		var touch := (data["touchscreen_settings"] as Dictionary).duplicate(true)
		var deserialized := _deserialize_touchscreen_vector2_fields(touch)
		sanitized["touchscreen_settings"] = _merge_touchscreen_defaults(deserialized)
	else:
		sanitized["touchscreen_settings"] = _get_touchscreen_defaults()

	if data.has("accessibility") and data["accessibility"] is Dictionary:
		sanitized["accessibility"] = (data["accessibility"] as Dictionary).duplicate(true)

	return sanitized

static func _serialize_custom_bindings(bindings: Variant) -> Dictionary:
	var result: Dictionary = {}
	if bindings is Dictionary:
		for action in (bindings as Dictionary).keys():
			var events_variant: Variant = (bindings as Dictionary)[action]
			var serialized: Array = []
			if events_variant is Array:
				for event_data in (events_variant as Array):
					if event_data is Dictionary:
						serialized.append((event_data as Dictionary).duplicate(true))
					elif event_data is InputEvent:
						serialized.append(U_InputRebindUtils.event_to_dict(event_data))
			result[String(action)] = serialized
	return result

static func _serialize_custom_bindings_by_profile(bindings_by_profile: Variant) -> Dictionary:
	var result: Dictionary = {}
	if bindings_by_profile is Dictionary:
		for profile_id in (bindings_by_profile as Dictionary).keys():
			var profile_key := String(profile_id)
			result[profile_key] = _serialize_custom_bindings((bindings_by_profile as Dictionary)[profile_id])
	return result

static func _serialize_touchscreen_vector2_fields(touchscreen: Dictionary) -> Dictionary:
	var result := touchscreen.duplicate(true)

	# Convert custom_joystick_position Vector2 -> {x, y}
	if result.has("custom_joystick_position"):
		var pos: Variant = result["custom_joystick_position"]
		if pos is Vector2:
			result["custom_joystick_position"] = {"x": pos.x, "y": pos.y}

	# Convert custom_button_positions dictionary values Vector2 -> {x, y}
	if result.has("custom_button_positions"):
		var button_positions: Variant = result["custom_button_positions"]
		if button_positions is Dictionary:
			var converted: Dictionary = {}
			for button_name in (button_positions as Dictionary).keys():
				var normalized_name := String(button_name)
				var pos: Variant = (button_positions as Dictionary)[button_name]
				if pos is Vector2:
					converted[normalized_name] = {"x": pos.x, "y": pos.y}
				else:
					converted[normalized_name] = pos
			result["custom_button_positions"] = converted

	return result

static func _sanitize_custom_bindings(bindings: Variant) -> Dictionary:
	var cleaned: Dictionary = {}
	if bindings is Dictionary:
		for action in (bindings as Dictionary).keys():
			var serialized: Array = []
			var events_var: Variant = (bindings as Dictionary)[action]
			if events_var is Array:
				for event_entry in (events_var as Array):
					if event_entry is Dictionary:
						var event := U_InputRebindUtils.dict_to_event(event_entry)
						if event != null:
							serialized.append(U_InputRebindUtils.event_to_dict(event))
					elif event_entry is InputEvent:
						serialized.append(U_InputRebindUtils.event_to_dict(event_entry))
			if not serialized.is_empty():
				cleaned[StringName(action)] = serialized
	return cleaned

static func _sanitize_custom_bindings_by_profile(bindings: Variant) -> Dictionary:
	var cleaned: Dictionary = {}
	if bindings is Dictionary:
		for profile_id in (bindings as Dictionary).keys():
			var profile_key := String(profile_id)
			var profile_bindings := _sanitize_custom_bindings((bindings as Dictionary)[profile_id])
			if not profile_bindings.is_empty():
				cleaned[profile_key] = profile_bindings
	return cleaned

static func _sanitize_float_fields(source: Dictionary, ranges: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		var value: Variant = source[key]
		if value is float or value is int:
			var range: Vector2 = ranges.get(key, Vector2.ZERO)
			if range != Vector2.ZERO:
				var min_value := range.x
				var max_value := range.y
				result[key] = clampf(float(value), min_value, max_value)
			else:
				result[key] = float(value)
		else:
			result[key] = source[key]
	return result

static func _deserialize_touchscreen_vector2_fields(touchscreen: Dictionary) -> Dictionary:
	var result := touchscreen.duplicate(true)

	# Convert custom_joystick_position {x, y} -> Vector2 (or keep Vector2 if already converted)
	if result.has("custom_joystick_position"):
		var pos: Variant = result["custom_joystick_position"]
		if pos is Dictionary and (pos as Dictionary).has("x") and (pos as Dictionary).has("y"):
			result["custom_joystick_position"] = Vector2(
				float((pos as Dictionary)["x"]),
				float((pos as Dictionary)["y"])
			)
		elif not (pos is Vector2):
			# Invalid format, use sentinel value
			result["custom_joystick_position"] = Vector2(-1, -1)

	# Convert custom_button_positions dictionary values {x, y} -> Vector2
	if result.has("custom_button_positions"):
		var button_positions: Variant = result["custom_button_positions"]
		if button_positions is Dictionary:
			var converted: Dictionary = {}
			for button_name in (button_positions as Dictionary).keys():
				var normalized_name := _to_string_name(button_name)
				var pos: Variant = (button_positions as Dictionary)[button_name]
				if pos is Dictionary and (pos as Dictionary).has("x") and (pos as Dictionary).has("y"):
					converted[normalized_name] = Vector2(
						float((pos as Dictionary)["x"]),
						float((pos as Dictionary)["y"])
					)
				elif pos is Vector2:
					# Already Vector2, keep it
					converted[normalized_name] = pos
			result["custom_button_positions"] = converted

	return result

static func _merge_touchscreen_defaults(touchscreen: Dictionary) -> Dictionary:
	var defaults := _get_touchscreen_defaults()
	var merged := defaults.duplicate(true)
	for key in touchscreen.keys():
		var value: Variant = touchscreen[key]
		if value is Dictionary:
			merged[key] = (value as Dictionary).duplicate(true)
		elif value is Array:
			merged[key] = (value as Array).duplicate(true)
		else:
			merged[key] = value
	return merged

static func _get_touchscreen_defaults() -> Dictionary:
	var defaults := U_InputReducer.get_default_input_settings_state()
	var touchscreen_defaults: Variant = defaults.get("touchscreen_settings", {})
	if touchscreen_defaults is Dictionary:
		return (touchscreen_defaults as Dictionary).duplicate(true)
	return {}

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	return StringName(String(value))

static func _backup_corrupted_file(raw_text: String) -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("input_settings.json"):
		if dir.file_exists("input_settings.json.backup"):
			dir.remove("input_settings.json.backup")
		var rename_error := dir.rename("input_settings.json", "input_settings.json.backup")
		if rename_error != OK:
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_string(raw_text)
