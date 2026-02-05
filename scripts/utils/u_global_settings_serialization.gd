extends RefCounted
class_name U_GlobalSettingsSerialization

const U_AUDIO_SERIALIZATION := preload("res://scripts/utils/u_audio_serialization.gd")
const U_INPUT_SERIALIZATION := preload("res://scripts/utils/input/u_input_serialization.gd")

const SAVE_PATH := "user://global_settings.json"
const BACKUP_PATH := "user://global_settings.json.backup"
const CURRENT_VERSION := "1.0.0"

const INPUT_SETTINGS_ACTIONS := [
	"input/profile_switched",
	"input/rebind_action",
	"input/reset_bindings",
	"input/update_gamepad_deadzone",
	"input/toggle_vibration",
	"input/set_vibration_intensity",
	"input/update_mouse_sensitivity",
	"input/update_accessibility",
	"input/load_input_settings",
	"input/remove_action_bindings",
	"input/remove_event_from_action",
	"input/update_touchscreen_settings",
	"input/save_virtual_control_position",
]

const GAMEPLAY_PREF_ACTIONS := [
	"gameplay/set_show_landing_indicator",
	"gameplay/set_particle_settings",
	"gameplay/set_audio_settings",
	"gameplay/TOGGLE_LANDING_INDICATOR",
	"gameplay/UPDATE_PARTICLE_SETTINGS",
	"gameplay/UPDATE_AUDIO_SETTINGS",
]

static func load_settings() -> Dictionary:
	var result := load_settings_with_meta()
	var settings: Variant = result.get("settings", {})
	if settings is Dictionary:
		return settings as Dictionary
	return {}

static func load_settings_with_meta() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		return {
			"settings": _load_global_file(),
			"migrated": false,
		}

	var legacy := _load_legacy_settings()
	if legacy.is_empty():
		return {
			"settings": {},
			"migrated": false,
		}

	return {
		"settings": legacy,
		"migrated": true,
	}

static func save_settings(settings: Dictionary) -> bool:
	if settings == null:
		return false

	var existing := load_settings()
	var merged := _merge_settings(existing, settings)
	if merged.is_empty():
		return false

	var payload := _prepare_save_payload(merged)
	var json_text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open %s for writing" % SAVE_PATH)
		return false
	file.store_string(json_text)
	file.flush()
	return true

static func build_settings_from_state(state: Dictionary) -> Dictionary:
	var settings: Dictionary = {}
	if state == null:
		return settings

	var display_slice := _get_slice_dict(state, StringName("display"))
	if not display_slice.is_empty():
		settings["display"] = display_slice.duplicate(true)

	var audio_slice := _get_slice_dict(state, StringName("audio"))
	if not audio_slice.is_empty():
		settings["audio"] = audio_slice.duplicate(true)

	var vfx_slice := _get_slice_dict(state, StringName("vfx"))
	if not vfx_slice.is_empty():
		settings["vfx"] = vfx_slice.duplicate(true)

	var settings_slice := _get_slice_dict(state, StringName("settings"))
	if not settings_slice.is_empty():
		var input_variant: Variant = settings_slice.get("input_settings", {})
		if input_variant is Dictionary:
			settings["input_settings"] = (input_variant as Dictionary).duplicate(true)

	var gameplay_slice := _get_slice_dict(state, StringName("gameplay"))
	if not gameplay_slice.is_empty():
		var gameplay_prefs: Dictionary = {}
		if gameplay_slice.has("show_landing_indicator"):
			gameplay_prefs["show_landing_indicator"] = bool(gameplay_slice.get("show_landing_indicator", true))
		if gameplay_slice.has("particle_settings") and gameplay_slice["particle_settings"] is Dictionary:
			gameplay_prefs["particle_settings"] = (gameplay_slice["particle_settings"] as Dictionary).duplicate(true)
		if gameplay_slice.has("audio_settings") and gameplay_slice["audio_settings"] is Dictionary:
			gameplay_prefs["audio_settings"] = (gameplay_slice["audio_settings"] as Dictionary).duplicate(true)
		if not gameplay_prefs.is_empty():
			settings["gameplay_preferences"] = gameplay_prefs

	return settings

static func is_global_settings_action(action_type: Variant) -> bool:
	var action_name := ""
	if action_type is StringName:
		action_name = String(action_type)
	elif action_type is String:
		action_name = action_type
	else:
		action_name = str(action_type)
	if action_name.begins_with("display/"):
		return true
	if action_name.begins_with("audio/"):
		return true
	if action_name.begins_with("vfx/"):
		return true
	if INPUT_SETTINGS_ACTIONS.has(action_name):
		return true
	return GAMEPLAY_PREF_ACTIONS.has(action_name)

static func _load_global_file() -> Dictionary:
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
		push_warning("Global settings file corrupted; falling back to defaults.")
		return {}

	return _sanitize_loaded_settings(result as Dictionary)

static func _load_legacy_settings() -> Dictionary:
	var legacy: Dictionary = {}
	var audio_settings := U_AUDIO_SERIALIZATION.load_settings()
	if not audio_settings.is_empty():
		legacy["audio"] = audio_settings

	var input_settings := U_INPUT_SERIALIZATION.load_settings()
	if not input_settings.is_empty():
		legacy["input_settings"] = input_settings

	return legacy

static func _prepare_save_payload(settings: Dictionary) -> Dictionary:
	var payload: Dictionary = {
		"version": CURRENT_VERSION
	}

	if settings.has("display") and settings["display"] is Dictionary:
		payload["display"] = _deep_copy(settings["display"])

	if settings.has("audio") and settings["audio"] is Dictionary:
		payload["audio"] = U_AUDIO_SERIALIZATION.serialize_settings(settings["audio"])

	if settings.has("vfx") and settings["vfx"] is Dictionary:
		payload["vfx"] = _deep_copy(settings["vfx"])

	if settings.has("input_settings") and settings["input_settings"] is Dictionary:
		payload["input_settings"] = U_INPUT_SERIALIZATION.serialize_settings(settings["input_settings"])

	if settings.has("gameplay_preferences") and settings["gameplay_preferences"] is Dictionary:
		payload["gameplay_preferences"] = _deep_copy(settings["gameplay_preferences"])

	return payload

static func _sanitize_loaded_settings(data: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	if data.has("display") and data["display"] is Dictionary:
		sanitized["display"] = _deep_copy(data["display"])
	if data.has("audio") and data["audio"] is Dictionary:
		sanitized["audio"] = U_AUDIO_SERIALIZATION.deserialize_settings(data["audio"])
	if data.has("vfx") and data["vfx"] is Dictionary:
		sanitized["vfx"] = _deep_copy(data["vfx"])
	if data.has("input_settings") and data["input_settings"] is Dictionary:
		sanitized["input_settings"] = U_INPUT_SERIALIZATION.deserialize_settings(data["input_settings"])
	if data.has("gameplay_preferences") and data["gameplay_preferences"] is Dictionary:
		sanitized["gameplay_preferences"] = _sanitize_gameplay_preferences(data["gameplay_preferences"])
	return sanitized

static func _sanitize_gameplay_preferences(source: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for key in source.keys():
		if key == "show_landing_indicator":
			sanitized[key] = bool(source.get(key, true))
			continue
		var value: Variant = source[key]
		sanitized[key] = _deep_copy(value)
	return sanitized

static func _merge_settings(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	for key in overrides.keys():
		merged[key] = _deep_copy(overrides[key])
	return merged

static func _get_slice_dict(state: Dictionary, slice_name: StringName) -> Dictionary:
	var value: Variant = state.get(slice_name, null)
	if value is Dictionary:
		return value as Dictionary
	var fallback: Variant = state.get(String(slice_name), {})
	if fallback is Dictionary:
		return fallback as Dictionary
	return {}

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

static func _backup_corrupted_file(raw_text: String) -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("global_settings.json"):
		if dir.file_exists("global_settings.json.backup"):
			dir.remove("global_settings.json.backup")
		var rename_error := dir.rename("global_settings.json", "global_settings.json.backup")
		if rename_error != OK:
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_string(raw_text)
