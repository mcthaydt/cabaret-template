extends RefCounted
class_name U_AudioSerialization

const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")

const SAVE_PATH := "user://audio_settings.json"
const BACKUP_PATH := "user://audio_settings.json.backup"
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
		push_warning("Audio settings file corrupted; falling back to defaults.")
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
	var defaults := U_AUDIO_REDUCER.get_default_audio_state()
	var payload: Dictionary = {}
	payload["version"] = CURRENT_VERSION

	payload["master_volume"] = _sanitize_volume(
		settings.get("master_volume", defaults.get("master_volume", 1.0)),
		float(defaults.get("master_volume", 1.0))
	)
	payload["music_volume"] = _sanitize_volume(
		settings.get("music_volume", defaults.get("music_volume", 1.0)),
		float(defaults.get("music_volume", 1.0))
	)
	payload["sfx_volume"] = _sanitize_volume(
		settings.get("sfx_volume", defaults.get("sfx_volume", 1.0)),
		float(defaults.get("sfx_volume", 1.0))
	)
	payload["ambient_volume"] = _sanitize_volume(
		settings.get("ambient_volume", defaults.get("ambient_volume", 1.0)),
		float(defaults.get("ambient_volume", 1.0))
	)

	payload["master_muted"] = bool(settings.get("master_muted", defaults.get("master_muted", false)))
	payload["music_muted"] = bool(settings.get("music_muted", defaults.get("music_muted", false)))
	payload["sfx_muted"] = bool(settings.get("sfx_muted", defaults.get("sfx_muted", false)))
	payload["ambient_muted"] = bool(settings.get("ambient_muted", defaults.get("ambient_muted", false)))

	payload["spatial_audio_enabled"] = bool(
		settings.get("spatial_audio_enabled", defaults.get("spatial_audio_enabled", true))
	)

	return payload

static func _sanitize_loaded_settings(data: Dictionary) -> Dictionary:
	var defaults := U_AUDIO_REDUCER.get_default_audio_state()
	var sanitized: Dictionary = {}

	if data.has("master_volume"):
		sanitized["master_volume"] = _sanitize_volume(
			data.get("master_volume"),
			float(defaults.get("master_volume", 1.0))
		)
	if data.has("music_volume"):
		sanitized["music_volume"] = _sanitize_volume(
			data.get("music_volume"),
			float(defaults.get("music_volume", 1.0))
		)
	if data.has("sfx_volume"):
		sanitized["sfx_volume"] = _sanitize_volume(
			data.get("sfx_volume"),
			float(defaults.get("sfx_volume", 1.0))
		)
	if data.has("ambient_volume"):
		sanitized["ambient_volume"] = _sanitize_volume(
			data.get("ambient_volume"),
			float(defaults.get("ambient_volume", 1.0))
		)

	if data.has("master_muted"):
		sanitized["master_muted"] = bool(data.get("master_muted"))
	if data.has("music_muted"):
		sanitized["music_muted"] = bool(data.get("music_muted"))
	if data.has("sfx_muted"):
		sanitized["sfx_muted"] = bool(data.get("sfx_muted"))
	if data.has("ambient_muted"):
		sanitized["ambient_muted"] = bool(data.get("ambient_muted"))

	if data.has("spatial_audio_enabled"):
		sanitized["spatial_audio_enabled"] = bool(data.get("spatial_audio_enabled"))

	return sanitized

static func _sanitize_volume(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return fallback

static func _backup_corrupted_file(raw_text: String) -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("audio_settings.json"):
		if dir.file_exists("audio_settings.json.backup"):
			dir.remove("audio_settings.json.backup")
		var rename_error := dir.rename("audio_settings.json", "audio_settings.json.backup")
		if rename_error != OK:
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_string(raw_text)
