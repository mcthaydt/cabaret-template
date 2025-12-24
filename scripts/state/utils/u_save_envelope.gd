class_name U_SaveEnvelope
extends RefCounted

## Utility for reading/writing save envelopes.
##
## Envelope schema (V1):
##   { "version": int, "metadata": Dictionary, "state": Dictionary }

const SAVE_FILE_VERSION: int = 1

const U_SERIALIZATION_HELPER := preload("res://scripts/state/utils/u_serialization_helper.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")

static func build_envelope(metadata: RS_SaveSlotMetadata, state: Dictionary, version: int = SAVE_FILE_VERSION) -> Dictionary:
	var metadata_dict: Dictionary = {}
	if metadata != null:
		metadata_dict = metadata.to_dictionary()

	return {
		"version": version,
		"metadata": metadata_dict,
		"state": U_SERIALIZATION_HELPER.godot_to_json(state),
	}

static func write_envelope(filepath: String, metadata: RS_SaveSlotMetadata, state: Dictionary, version: int = SAVE_FILE_VERSION) -> Error:
	if filepath.is_empty():
		push_error("U_SaveEnvelope.write_envelope: Empty filepath")
		return ERR_INVALID_PARAMETER

	var envelope := build_envelope(metadata, state, version)
	var json_string := JSON.stringify(envelope, "\t")

	_ensure_base_dir_for_file(filepath)

	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("U_SaveEnvelope.write_envelope: Failed to open file for writing: ", open_error)
		return open_error

	file.store_string(json_string)
	file.close()
	return OK

static func try_read_envelope(filepath: String) -> Dictionary:
	if filepath.is_empty():
		push_error("U_SaveEnvelope.try_read_envelope: Empty filepath")
		return {}

	if not FileAccess.file_exists(filepath):
		return {}

	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("U_SaveEnvelope.try_read_envelope: Failed to open file for reading: ", open_error)
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_err: Error = json.parse(json_string)
	if parse_err != OK:
		return {}

	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return {}

	var envelope := parsed as Dictionary

	var version_variant: Variant = envelope.get("version", null)
	if not (version_variant is int or version_variant is float):
		return {}
	var version: int = int(version_variant)
	if version != SAVE_FILE_VERSION:
		return {}

	var metadata_variant: Variant = envelope.get("metadata", null)
	var state_variant: Variant = envelope.get("state", null)
	if not (metadata_variant is Dictionary) or not (state_variant is Dictionary):
		return {}

	var metadata_dict := metadata_variant as Dictionary
	var state_dict := state_variant as Dictionary

	return {
		"version": version,
		"metadata": metadata_dict,
		"state": U_SERIALIZATION_HELPER.json_to_godot(state_dict),
	}

static func try_read_metadata(filepath: String) -> RS_SaveSlotMetadata:
	var metadata := RS_SaveSlotMetadata.new()
	metadata.is_empty = true
	metadata.file_path = filepath
	metadata.completion_percentage = -1.0

	var envelope := try_read_envelope(filepath)
	if envelope.is_empty():
		return metadata

	var metadata_variant: Variant = envelope.get("metadata", {})
	if metadata_variant is Dictionary:
		metadata.from_dictionary(metadata_variant as Dictionary)

	metadata.file_path = filepath
	metadata.file_version = int(envelope.get("version", SAVE_FILE_VERSION))

	return metadata

static func try_import_legacy_as_auto_slot(legacy_path: String, auto_path: String, legacy_backup_path: String) -> Error:
	if legacy_path.is_empty() or auto_path.is_empty() or legacy_backup_path.is_empty():
		push_error("U_SaveEnvelope.try_import_legacy_as_auto_slot: Empty filepath")
		return ERR_INVALID_PARAMETER

	if FileAccess.file_exists(auto_path):
		return OK

	if not FileAccess.file_exists(legacy_path):
		return OK

	var legacy_file := FileAccess.open(legacy_path, FileAccess.READ)
	if legacy_file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("U_SaveEnvelope.try_import_legacy_as_auto_slot: Failed to open legacy file: ", open_error)
		return open_error

	var legacy_text := legacy_file.get_as_text()
	legacy_file.close()

	var json := JSON.new()
	var parse_err: Error = json.parse(legacy_text)
	if parse_err != OK:
		push_error("U_SaveEnvelope.try_import_legacy_as_auto_slot: Invalid legacy JSON")
		return ERR_PARSE_ERROR

	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		push_error("U_SaveEnvelope.try_import_legacy_as_auto_slot: Invalid legacy JSON")
		return ERR_PARSE_ERROR

	var legacy_state := parsed as Dictionary

	# Validate that the legacy state has a valid scene slice with scene_id
	# If not, don't migrate (this is likely a settings-only or invalid save)
	var scene_slice: Dictionary = legacy_state.get("scene", {})
	var scene_id: Variant = scene_slice.get("current_scene_id", "")

	if scene_id == "" or scene_id == StringName(""):
		# Legacy save has no valid scene - don't migrate
		# Just rename it to backup and return OK
		print("U_SaveEnvelope: Legacy save has no valid scene_id, skipping migration")
		var rename_err := _rename_file(legacy_path, legacy_backup_path)
		return rename_err if rename_err != OK else OK

	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id = 0  # Autosave is slot 0, not -1
	metadata.slot_type = RS_SaveSlotMetadata.SlotType.AUTO
	metadata.is_empty = false
	metadata.file_path = auto_path
	metadata.file_version = SAVE_FILE_VERSION
	metadata.completion_percentage = -1.0
	metadata.scene_id = StringName(str(scene_id))
	metadata.scene_name = str(scene_id)  # Use scene_id as fallback for scene name

	# Extract gameplay data for metadata if available
	var gameplay_slice: Dictionary = legacy_state.get("gameplay", {})
	if not gameplay_slice.is_empty():
		metadata.play_time_seconds = gameplay_slice.get("play_time_seconds", 0.0)
		metadata.player_health = gameplay_slice.get("player_health", 0.0)
		metadata.player_max_health = gameplay_slice.get("player_max_health", 100.0)
		metadata.death_count = gameplay_slice.get("death_count", 0)

	var write_err := write_envelope(auto_path, metadata, legacy_state, SAVE_FILE_VERSION)
	if write_err != OK:
		return write_err

	var rename_err := _rename_file(legacy_path, legacy_backup_path)
	if rename_err != OK:
		return rename_err

	return OK

static func _ensure_base_dir_for_file(filepath: String) -> void:
	var base_dir := filepath.get_base_dir()
	if base_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(base_dir)

static func _rename_file(from_path: String, to_path: String) -> Error:
	var from_dir := from_path.get_base_dir()
	var to_dir := to_path.get_base_dir()
	if not to_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(to_dir)

	if from_dir.is_empty():
		return ERR_INVALID_PARAMETER

	var dir := DirAccess.open(from_dir)
	if dir == null:
		return ERR_CANT_OPEN

	var from_name := from_path.get_file()
	var to_name := to_path.get_file()

	if FileAccess.file_exists(to_path):
		DirAccess.remove_absolute(to_path)

	return dir.rename(from_name, to_name)
