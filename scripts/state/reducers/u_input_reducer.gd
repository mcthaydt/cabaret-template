extends RefCounted
class_name U_InputReducer

const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")

const DEFAULT_GAMEPLAY_INPUT_STATE := {
	"active_device": 0,
	"last_input_time": 0.0,
	"gamepad_connected": false,
	"gamepad_device_id": -1,
	"touchscreen_enabled": false,
	"move_input": Vector2.ZERO,
	"look_input": Vector2.ZERO,
	"jump_pressed": false,
	"jump_just_pressed": false,
	"sprint_pressed": false,
}

const DEFAULT_INPUT_SETTINGS_STATE := {
	"active_profile_id": "default",
	"custom_bindings": {},
	"custom_bindings_by_profile": {},
	"gamepad_settings": {
		"left_stick_deadzone": 0.2,
		"right_stick_deadzone": 0.2,
		"trigger_deadzone": 0.1,
		"vibration_enabled": true,
		"vibration_intensity": 1.0,
		"invert_y_axis": false,
		"right_stick_sensitivity": 1.0,
		"deadzone_curve": 0,
	},
	"mouse_settings": {
		"sensitivity": 1.0,
		"invert_y_axis": false,
	},
	"touchscreen_settings": {
		"virtual_joystick_size": 1.0,
		"virtual_joystick_opacity": 0.7,
		"button_layout": "default",
		"button_size": 1.0,
		"joystick_deadzone": 0.15,
		"button_opacity": 0.8,
		"custom_joystick_position": Vector2(-1, -1),
		"custom_button_positions": {},
		"custom_button_sizes": {},
		"custom_button_opacities": {},
	},
	"accessibility": {
		"jump_buffer_time": 0.1,
		"sprint_toggle_mode": false,
		"interact_hold_duration": 0.0,
	},
}

static func get_default_gameplay_input_state() -> Dictionary:
	return DEFAULT_GAMEPLAY_INPUT_STATE.duplicate(true)

static func get_default_input_settings_state() -> Dictionary:
	return DEFAULT_INPUT_SETTINGS_STATE.duplicate(true)

static func reduce_gameplay_input(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_GAMEPLAY_INPUT_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_InputActions.ACTION_PROFILE_SWITCHED:
			# Clear transient input so movement/looking/sprinting stop when profiles change.
			return _with_values(current, {
				"move_input": Vector2.ZERO,
				"look_input": Vector2.ZERO,
				"jump_pressed": false,
				"jump_just_pressed": false,
				"sprint_pressed": false,
			})

		U_InputActions.ACTION_UPDATE_MOVE_INPUT:
			var payload: Dictionary = action.get("payload", {})
			return _with_values(current, {
				"move_input": payload.get("move_vector", Vector2.ZERO)
			})

		U_InputActions.ACTION_UPDATE_LOOK_INPUT:
			var look_payload: Dictionary = action.get("payload", {})
			return _with_values(current, {
				"look_input": look_payload.get("look_delta", Vector2.ZERO)
			})

		U_InputActions.ACTION_UPDATE_JUMP_STATE:
			var jump_payload: Dictionary = action.get("payload", {})
			return _with_values(current, {
				"jump_pressed": jump_payload.get("pressed", false),
				"jump_just_pressed": jump_payload.get("just_pressed", false)
			})

		U_InputActions.ACTION_UPDATE_SPRINT_STATE:
			var sprint_payload: Dictionary = action.get("payload", {})
			return _with_values(current, {
				"sprint_pressed": sprint_payload.get("pressed", false)
			})

		U_InputActions.ACTION_DEVICE_CHANGED:
			var device_payload: Dictionary = action.get("payload", {})
			return _with_values(current, {
				"active_device": int(device_payload.get("device_type", 0)),
				"gamepad_device_id": int(device_payload.get("device_id", -1))
			})

		U_InputActions.ACTION_GAMEPAD_CONNECTED:
			var connected_payload: Dictionary = action.get("payload", {})
			return _with_values(current, {
				"gamepad_connected": true,
				"gamepad_device_id": int(connected_payload.get("device_id", -1))
			})

		U_InputActions.ACTION_GAMEPAD_DISCONNECTED:
			return _with_values(current, {
				"gamepad_connected": false,
				"gamepad_device_id": -1
			})

		_:
			return null

static func reduce_input_settings(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_INPUT_SETTINGS_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_InputActions.ACTION_PROFILE_SWITCHED:
			var payload: Dictionary = action.get("payload", {})
			var profile_id := String(payload.get("profile_id", "default"))
			var all_bindings: Dictionary = _duplicate_dict(current.get("custom_bindings_by_profile", {}))
			var profile_bindings: Dictionary = {}
			var bindings_variant: Variant = all_bindings.get(profile_id, {})
			if bindings_variant is Dictionary:
				profile_bindings = (bindings_variant as Dictionary).duplicate(true)
			return _with_values(current, {
				"active_profile_id": profile_id,
				"custom_bindings": profile_bindings
			})

		U_InputActions.ACTION_REBIND_ACTION:
			var rebind_payload: Dictionary = action.get("payload", {})
			var action_name: StringName = rebind_payload.get("action", StringName(""))
			if action_name == StringName(""):
				return current
			var mode := String(rebind_payload.get("mode", U_InputActions.REBIND_MODE_REPLACE))
			var bindings: Dictionary = _duplicate_dict(current.get("custom_bindings", {}))
			var existing: Array = _duplicate_event_array(bindings.get(action_name, []))
			var event_dict := _normalize_event_dict(rebind_payload.get("event", {}))
			var event_list: Array = _normalize_event_array(rebind_payload.get("events", []))

			var final_events: Array
			if not event_list.is_empty():
				final_events = event_list
			else:
				final_events = existing
				if mode == U_InputActions.REBIND_MODE_REPLACE:
					# Device-type aware replace: only replace events of the same device type
					if not event_dict.is_empty():
						var new_device_type := _get_event_device_type(event_dict)
						# Keep events from OTHER device types
						var preserved_events: Array = []
						for existing_event in final_events:
							var existing_device_type := _get_event_device_type(existing_event)
							if existing_device_type != new_device_type:
								preserved_events.append(existing_event)
						# Start with preserved events, then add the new event
						final_events = preserved_events
						final_events.append(event_dict)
					else:
						final_events.clear()
				elif mode == U_InputActions.REBIND_MODE_ADD:
					if not event_dict.is_empty() and not _array_contains_event(final_events, event_dict):
						final_events.append(event_dict)

			if final_events.is_empty():
				bindings.erase(action_name)
			else:
				# Remove conflicting events from other custom bindings.
				for ev_dict in final_events:
					var conflict_action := _find_conflict(bindings, ev_dict, action_name)
					if conflict_action != StringName():
						var updated_conflict := _remove_matching_event(_duplicate_event_array(bindings.get(conflict_action, [])), ev_dict)
						if updated_conflict.is_empty():
							bindings.erase(conflict_action)
						else:
							bindings[conflict_action] = updated_conflict
				bindings[action_name] = final_events

			var profile_id := String(current.get("active_profile_id", "default"))
			var all_bindings: Dictionary = _duplicate_dict(current.get("custom_bindings_by_profile", {}))
			if bindings.is_empty():
				all_bindings.erase(profile_id)
			else:
				all_bindings[profile_id] = bindings

			return _with_values(current, {
				"custom_bindings": bindings,
				"custom_bindings_by_profile": all_bindings
			})

		U_InputActions.ACTION_RESET_BINDINGS:
			return _with_values(current, {
				"custom_bindings": {},
				"custom_bindings_by_profile": {}
			})

		U_InputActions.ACTION_UPDATE_GAMEPAD_DEADZONE:
			var deadzone_payload: Dictionary = action.get("payload", {})
			var stick: String = String(deadzone_payload.get("stick", ""))
			var value: float = clampf(float(deadzone_payload.get("deadzone", 0.0)), 0.0, 1.0)
			var pad_settings: Dictionary = _duplicate_dict(current.get("gamepad_settings", {}))
			match stick.to_lower():
				"left":
					pad_settings["left_stick_deadzone"] = value
				"right":
					pad_settings["right_stick_deadzone"] = value
			return _with_values(current, {"gamepad_settings": pad_settings})

		U_InputActions.ACTION_TOGGLE_VIBRATION:
			var toggle_payload: Dictionary = action.get("payload", {})
			var pad_toggle: Dictionary = _duplicate_dict(current.get("gamepad_settings", {}))
			pad_toggle["vibration_enabled"] = bool(toggle_payload.get("enabled", true))
			return _with_values(current, {"gamepad_settings": pad_toggle})

		U_InputActions.ACTION_SET_VIBRATION_INTENSITY:
			var intensity_payload: Dictionary = action.get("payload", {})
			var pad_intensity: Dictionary = _duplicate_dict(current.get("gamepad_settings", {}))
			pad_intensity["vibration_intensity"] = clampf(float(intensity_payload.get("intensity", 1.0)), 0.0, 1.0)
			return _with_values(current, {"gamepad_settings": pad_intensity})

		U_InputActions.ACTION_UPDATE_MOUSE_SENSITIVITY:
			var mouse_payload: Dictionary = action.get("payload", {})
			var mouse_settings: Dictionary = _duplicate_dict(current.get("mouse_settings", {}))
			mouse_settings["sensitivity"] = float(mouse_payload.get("sensitivity", 1.0))
			return _with_values(current, {"mouse_settings": mouse_settings})

		U_InputActions.ACTION_UPDATE_ACCESSIBILITY:
			var accessibility_payload: Dictionary = action.get("payload", {})
			var field: String = String(accessibility_payload.get("field", ""))
			if field.is_empty():
				return current
			var accessibility: Dictionary = _duplicate_dict(current.get("accessibility", {}))
			accessibility[field] = accessibility_payload.get("value")
			return _with_values(current, {"accessibility": accessibility})

		U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS:
			var touchscreen_payload: Dictionary = action.get("payload", {})
			var settings_updates: Dictionary = touchscreen_payload.get("settings", {})
			if settings_updates.is_empty():
				return current
			var touchscreen_settings: Dictionary = _duplicate_dict(current.get("touchscreen_settings", {}))
			touchscreen_settings.merge(settings_updates, true)
			return _with_values(current, {"touchscreen_settings": touchscreen_settings})

		U_InputActions.ACTION_SAVE_VIRTUAL_CONTROL_POSITION:
			var position_payload: Dictionary = action.get("payload", {})
			var control_name: String = String(position_payload.get("control_name", ""))
			var position: Variant = position_payload.get("position", Vector2.ZERO)
			if control_name.is_empty() or not (position is Vector2):
				return current
			var touchscreen_settings: Dictionary = _duplicate_dict(current.get("touchscreen_settings", {}))
			if control_name == "virtual_joystick":
				touchscreen_settings["custom_joystick_position"] = position
			else:
				var custom_positions: Dictionary = _duplicate_dict(touchscreen_settings.get("custom_button_positions", {}))
				custom_positions[control_name] = position
				touchscreen_settings["custom_button_positions"] = custom_positions
			return _with_values(current, {"touchscreen_settings": touchscreen_settings})

		U_InputActions.ACTION_LOAD_INPUT_SETTINGS:
			var load_payload: Dictionary = action.get("payload", {})
			var updates: Dictionary = {}

			if load_payload.has("active_profile_id"):
				updates["active_profile_id"] = String(load_payload.get("active_profile_id", "default"))

			if load_payload.has("custom_bindings_by_profile"):
				updates["custom_bindings_by_profile"] = _normalize_custom_bindings_by_profile(load_payload["custom_bindings_by_profile"])

			if load_payload.has("custom_bindings"):
				updates["custom_bindings"] = _normalize_custom_bindings(load_payload["custom_bindings"])

			if load_payload.has("gamepad_settings") and load_payload["gamepad_settings"] is Dictionary:
				updates["gamepad_settings"] = _duplicate_dict(load_payload["gamepad_settings"])

			if load_payload.has("mouse_settings") and load_payload["mouse_settings"] is Dictionary:
				updates["mouse_settings"] = _duplicate_dict(load_payload["mouse_settings"])

			if load_payload.has("touchscreen_settings") and load_payload["touchscreen_settings"] is Dictionary:
				updates["touchscreen_settings"] = _duplicate_dict(load_payload["touchscreen_settings"])

			if load_payload.has("accessibility") and load_payload["accessibility"] is Dictionary:
				updates["accessibility"] = _duplicate_dict(load_payload["accessibility"])

			# Keep `custom_bindings` in sync with the active profile when loading.
			var loaded_profile_id: String = String(updates.get("active_profile_id", current.get("active_profile_id", "default")))
			if updates.has("custom_bindings_by_profile"):
				var all_loaded: Dictionary = _duplicate_dict(updates.get("custom_bindings_by_profile", {}))
				var view_variant: Variant = all_loaded.get(loaded_profile_id, {})
				var view_bindings: Dictionary = {}
				if view_variant is Dictionary:
					view_bindings = (view_variant as Dictionary).duplicate(true)
				updates["custom_bindings"] = view_bindings
			elif updates.has("custom_bindings"):
				# Legacy payload: treat custom_bindings as belonging to the loaded active profile.
				var legacy_bindings: Dictionary = _duplicate_dict(updates.get("custom_bindings", {}))
				var by_profile: Dictionary = {}
				if not legacy_bindings.is_empty():
					by_profile[loaded_profile_id] = legacy_bindings
				updates["custom_bindings_by_profile"] = by_profile

			if updates.is_empty():
				return current
			return _with_values(current, updates)

		U_InputActions.ACTION_REMOVE_ACTION_BINDINGS:
			var clear_payload: Dictionary = action.get("payload", {})
			var clear_action_name: StringName = clear_payload.get("action", StringName())
			if clear_action_name == StringName():
				return current
			var current_bindings: Dictionary = _duplicate_dict(current.get("custom_bindings", {}))
			if current_bindings.has(clear_action_name):
				current_bindings.erase(clear_action_name)
				var profile_id := String(current.get("active_profile_id", "default"))
				var all_bindings: Dictionary = _duplicate_dict(current.get("custom_bindings_by_profile", {}))
				if current_bindings.is_empty():
					all_bindings.erase(profile_id)
				else:
					all_bindings[profile_id] = current_bindings
				return _with_values(current, {
					"custom_bindings": current_bindings,
					"custom_bindings_by_profile": all_bindings
				})
			return current

		U_InputActions.ACTION_REMOVE_EVENT_FROM_ACTION:
			var remove_payload: Dictionary = action.get("payload", {})
			var target_action: StringName = remove_payload.get("action", StringName())
			var event_variant: Variant = remove_payload.get("event")
			if target_action == StringName() or not (event_variant is Dictionary):
				return current
			var bindings_dict: Dictionary = _duplicate_dict(current.get("custom_bindings", {}))
			if not bindings_dict.has(target_action):
				return current
			var events_array: Array = (bindings_dict[target_action] as Array).duplicate(true)
			var filtered: Array = []
			for entry in events_array:
				if entry is Dictionary and not _event_dicts_equal(entry, event_variant):
					filtered.append(entry.duplicate(true))
			if filtered.is_empty():
				bindings_dict.erase(target_action)
			else:
				bindings_dict[target_action] = filtered
			var profile_id := String(current.get("active_profile_id", "default"))
			var all_bindings: Dictionary = _duplicate_dict(current.get("custom_bindings_by_profile", {}))
			if bindings_dict.is_empty():
				all_bindings.erase(profile_id)
			else:
				all_bindings[profile_id] = bindings_dict
			return _with_values(current, {
				"custom_bindings": bindings_dict,
				"custom_bindings_by_profile": all_bindings
			})

		_:
			return null

static func _merge_with_defaults(defaults: Dictionary, state: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	if state == null:
		return merged
	for key in state.keys():
		merged[key] = _deep_copy(state[key])
	return merged

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	for key in updates.keys():
		next[key] = _deep_copy(updates[key])
	return next

static func _duplicate_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

static func _array_contains_event(events: Array, event_dict: Dictionary) -> bool:
	for entry in events:
		if entry is Dictionary and _event_dicts_equal(entry as Dictionary, event_dict):
			return true
	return false

static func _duplicate_event_array(source: Variant) -> Array:
	var duplicated: Array = []
	if source is Array:
		for entry in (source as Array):
			if entry is Dictionary:
				duplicated.append((entry as Dictionary).duplicate(true))
	return duplicated

static func _normalize_event_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func _normalize_event_array(value: Variant) -> Array:
	var normalized: Array = []
	if value is Array:
		for entry in (value as Array):
			if entry is Dictionary:
				normalized.append((entry as Dictionary).duplicate(true))
	return normalized

static func _remove_matching_event(events: Array, target: Dictionary) -> Array:
	if target.is_empty():
		return events
	var filtered: Array = []
	for entry in events:
		if entry is Dictionary and _event_dicts_equal(entry, target):
			continue
		if entry is Dictionary:
			filtered.append((entry as Dictionary).duplicate(true))
	return filtered

static func _find_conflict(bindings: Dictionary, event_dict: Dictionary, exclude_action: StringName) -> StringName:
	if event_dict.is_empty():
		return StringName()
	for key in bindings.keys():
		var action_name := key as StringName
		if action_name == exclude_action:
			continue
		var events_variant: Variant = bindings[key]
		if not (events_variant is Array):
			continue
		for entry in (events_variant as Array):
			if entry is Dictionary and _event_dicts_equal(entry as Dictionary, event_dict):
				return action_name
	return StringName()

static func _event_dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
		if a[key] != b[key]:
			return false
	return true

static func _normalize_custom_bindings(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if value is Dictionary:
		for action in (value as Dictionary).keys():
			var events_variant: Variant = (value as Dictionary)[action]
			if events_variant is Array:
				var serialized: Array = []
				for entry in events_variant:
					if entry is Dictionary:
						var event := U_InputRebindUtils.dict_to_event(entry)
						if event != null:
							serialized.append(U_InputRebindUtils.event_to_dict(event))
					elif entry is InputEvent:
						serialized.append(U_InputRebindUtils.event_to_dict(entry))
				if not serialized.is_empty():
					normalized[StringName(action)] = serialized
	return normalized

static func _normalize_custom_bindings_by_profile(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if value is Dictionary:
		for profile_key in (value as Dictionary).keys():
			var profile_id := String(profile_key)
			var bindings_variant: Variant = (value as Dictionary)[profile_key]
			var profile_bindings := _normalize_custom_bindings(bindings_variant)
			if not profile_bindings.is_empty():
				normalized[profile_id] = profile_bindings
	return normalized

## Returns device type category for an event dictionary.
## Returns: "keyboard", "mouse", "gamepad", or "unknown"
static func _get_event_device_type(event_dict: Dictionary) -> String:
	var event_type := String(event_dict.get("type", ""))

	if event_type == "key" or event_type == "InputEventKey":
		return "keyboard"
	elif event_type == "mouse_button" or event_type == "InputEventMouseButton":
		return "mouse"
	elif event_type == "joypad_button" or event_type == "joypad_motion" or \
			event_type == "InputEventJoypadButton" or event_type == "InputEventJoypadMotion":
		return "gamepad"
	elif event_type == "screen_touch" or event_type == "screen_drag" or \
			event_type == "InputEventScreenTouch" or event_type == "InputEventScreenDrag":
		return "touch"
	else:
		return "unknown"
