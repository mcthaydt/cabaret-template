class_name U_SaveManager
extends RefCounted

## Static utility for save slot management.
##
## Provides save/load/delete operations for multi-slot save system.
## Adapted from M_SaveManager but as stateless utility.

const RS_SaveManagerSettings := preload("res://scripts/state/resources/rs_save_manager_settings.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")
const U_SaveEnvelope := preload("res://scripts/state/utils/u_save_envelope.gd")
const U_SERIALIZATION_HELPER := preload("res://scripts/state/utils/u_serialization_helper.gd")

## Default settings (can be overridden by passing settings parameter)
const DEFAULT_MANUAL_SLOT_PATTERN: String = "user://save_slot_%d.json"
const DEFAULT_AUTO_SLOT_PATH: String = "user://save_slot_0.json"
const DEFAULT_LEGACY_PATH: String = "user://savegame.json"
const DEFAULT_LEGACY_BACKUP_PATH: String = "user://savegame.json.backup"
const DEFAULT_MANUAL_SLOT_COUNT: int = 3


# ==============================================================================
# Public API - Save Operations
# ==============================================================================

## Save current state to a manual slot (1-3)
static func save_to_slot(
	slot_index: int,
	state: Dictionary,
	slice_configs: Dictionary,
	is_autosave: bool = false,
	settings: RS_SaveManagerSettings = null
) -> Error:
	var path := get_manual_slot_path(slot_index, settings)
	if path.is_empty():
		push_error("U_SaveManager.save_to_slot: Invalid slot index %d" % slot_index)
		return ERR_INVALID_PARAMETER
	return _save_to_path(path, slot_index, false, state)


## Save current state to autosave slot (slot 0)
static func save_to_auto_slot(
	state: Dictionary,
	slice_configs: Dictionary,
	settings: RS_SaveManagerSettings = null
) -> Error:
	var path := get_auto_slot_path(settings)
	if path.is_empty():
		push_error("U_SaveManager.save_to_auto_slot: Invalid autosave path")
		return ERR_INVALID_PARAMETER
	return _save_to_path(path, 0, true, state)


# ==============================================================================
# Public API - Load Operations
# ==============================================================================

## Load state from a manual slot (1-3)
## Modifies the provided state dictionary in-place
static func load_from_slot(
	slot_index: int,
	state: Dictionary,
	slice_configs: Dictionary,
	settings: RS_SaveManagerSettings = null
) -> Error:
	var path := get_manual_slot_path(slot_index, settings)
	if path.is_empty():
		push_error("U_SaveManager.load_from_slot: Invalid slot index %d" % slot_index)
		return ERR_INVALID_PARAMETER
	return _load_from_path(path, state)


## Load state from autosave slot (slot 0)
## Modifies the provided state dictionary in-place
static func load_from_auto_slot(
	state: Dictionary,
	slice_configs: Dictionary,
	settings: RS_SaveManagerSettings = null
) -> Error:
	var path := get_auto_slot_path(settings)
	if path.is_empty():
		push_error("U_SaveManager.load_from_auto_slot: Invalid autosave path")
		return ERR_INVALID_PARAMETER
	return _load_from_path(path, state)


# ==============================================================================
# Public API - Slot Management
# ==============================================================================

## Delete a manual slot (1-3)
static func delete_slot(
	slot_index: int,
	settings: RS_SaveManagerSettings = null
) -> Error:
	var path := get_manual_slot_path(slot_index, settings)
	if path.is_empty():
		push_error("U_SaveManager.delete_slot: Invalid slot index %d" % slot_index)
		return ERR_INVALID_PARAMETER

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return OK


## Get metadata for a specific slot without loading full state
static func get_slot_metadata(
	slot_index: int,
	settings: RS_SaveManagerSettings = null
) -> RS_SaveSlotMetadata:
	var path: String
	if slot_index == 0:
		path = get_auto_slot_path(settings)
	else:
		path = get_manual_slot_path(slot_index, settings)

	if path.is_empty() or not FileAccess.file_exists(path):
		return null

	var metadata := U_SaveEnvelope.try_read_metadata(path)
	if metadata.is_empty:
		return null
	return metadata


## Get all slot metadata (manual slots + autosave)
static func get_all_slots(settings: RS_SaveManagerSettings = null) -> Array[RS_SaveSlotMetadata]:
	var slots: Array[RS_SaveSlotMetadata] = []

	var slot_count := DEFAULT_MANUAL_SLOT_COUNT
	if settings != null:
		slot_count = settings.manual_slot_count

	# Manual slots (1-3)
	for i in range(1, slot_count + 1):
		var path := get_manual_slot_path(i, settings)
		var metadata := _make_empty_slot_metadata(i, false, settings)
		if FileAccess.file_exists(path):
			metadata = U_SaveEnvelope.try_read_metadata(path)
			metadata.slot_id = i
			metadata.slot_type = RS_SaveSlotMetadata.SlotType.MANUAL
			metadata.file_path = path
		slots.append(metadata)

	# Autosave slot (0)
	var auto_path := get_auto_slot_path(settings)
	var auto_md := _make_empty_slot_metadata(0, true, settings)
	if FileAccess.file_exists(auto_path):
		auto_md = U_SaveEnvelope.try_read_metadata(auto_path)
		auto_md.slot_id = 0
		auto_md.slot_type = RS_SaveSlotMetadata.SlotType.AUTO
		auto_md.file_path = auto_path
	slots.append(auto_md)

	return slots


## Get the most recent save slot (any slot type)
static func get_most_recent_slot(settings: RS_SaveManagerSettings = null) -> int:
	var slots := get_all_slots(settings)
	var best: RS_SaveSlotMetadata = null
	var best_index: int = -1

	for md in slots:
		if md == null or md.is_empty:
			continue
		if best == null:
			best = md
			best_index = md.slot_id
			continue
		if md.timestamp > best.timestamp:
			best = md
			best_index = md.slot_id

	return best_index


## Check if any save exists (any slot)
static func has_any_save(settings: RS_SaveManagerSettings = null) -> bool:
	var slots := get_all_slots(settings)
	for md in slots:
		if md != null and not md.is_empty:
			return true
	return false


# ==============================================================================
# Public API - Path Resolution
# ==============================================================================

## Get path for a manual slot (1-3)
static func get_manual_slot_path(
	slot_index: int,
	settings: RS_SaveManagerSettings = null
) -> String:
	if slot_index < 1:
		return ""

	var slot_count := DEFAULT_MANUAL_SLOT_COUNT
	var pattern := DEFAULT_MANUAL_SLOT_PATTERN

	if settings != null:
		slot_count = settings.manual_slot_count
		pattern = settings.manual_slot_pattern

	if slot_index > slot_count:
		return ""

	return pattern % slot_index


## Get path for autosave slot (slot 0)
static func get_auto_slot_path(settings: RS_SaveManagerSettings = null) -> String:
	if settings != null:
		return settings.auto_slot_path
	return DEFAULT_AUTO_SLOT_PATH


# ==============================================================================
# Public API - Legacy Migration
# ==============================================================================

## Attempt to migrate legacy savegame.json to autosave slot
## Called automatically on first run
static func try_migrate_legacy_save(settings: RS_SaveManagerSettings = null) -> Error:
	var legacy_path := DEFAULT_LEGACY_PATH
	var legacy_backup_path := DEFAULT_LEGACY_BACKUP_PATH
	var auto_path := get_auto_slot_path(settings)

	if settings != null:
		legacy_path = settings.legacy_path
		legacy_backup_path = settings.legacy_backup_path

	if legacy_path.is_empty() or legacy_backup_path.is_empty():
		return OK  # No legacy migration configured

	return U_SaveEnvelope.try_import_legacy_as_auto_slot(
		legacy_path,
		auto_path,
		legacy_backup_path
	)


# ==============================================================================
# Internal - Save/Load Implementation
# ==============================================================================

static func _save_to_path(
	path: String,
	slot_id: int,
	is_auto: bool,
	state: Dictionary
) -> Error:
	var metadata := _build_metadata_from_state(path, slot_id, is_auto, state)
	var err := U_SaveEnvelope.write_envelope(path, metadata, state)
	return err


static func _load_from_path(path: String, state: Dictionary) -> Error:
	if not FileAccess.file_exists(path):
		push_error("U_SaveManager._load_from_path: File does not exist: %s" % path)
		return ERR_FILE_NOT_FOUND

	var envelope := U_SaveEnvelope.try_read_envelope(path)
	if envelope.is_empty():
		push_error("U_SaveManager._load_from_path: Failed to read envelope from %s" % path)
		return ERR_PARSE_ERROR

	var state_variant: Variant = envelope.get("state", {})
	if not (state_variant is Dictionary):
		push_error("U_SaveManager._load_from_path: Invalid state data in envelope")
		return ERR_INVALID_DATA

	# Clear existing state and merge loaded state
	state.clear()
	state.merge(state_variant as Dictionary, true)

	return OK


static func _make_empty_slot_metadata(
	slot_id: int,
	is_auto: bool,
	settings: RS_SaveManagerSettings = null
) -> RS_SaveSlotMetadata:
	var md := RS_SaveSlotMetadata.new()
	md.slot_id = slot_id
	md.slot_type = RS_SaveSlotMetadata.SlotType.AUTO if is_auto else RS_SaveSlotMetadata.SlotType.MANUAL
	md.is_empty = true
	md.completion_percentage = -1.0
	md.file_version = U_SaveEnvelope.SAVE_FILE_VERSION

	if is_auto:
		md.file_path = get_auto_slot_path(settings)
	else:
		md.file_path = get_manual_slot_path(slot_id, settings)

	return md


static func _build_metadata_from_state(
	path: String,
	slot_id: int,
	is_auto: bool,
	state: Dictionary
) -> RS_SaveSlotMetadata:
	var md := RS_SaveSlotMetadata.new()
	md.slot_id = slot_id
	md.slot_type = RS_SaveSlotMetadata.SlotType.AUTO if is_auto else RS_SaveSlotMetadata.SlotType.MANUAL
	md.is_empty = false
	md.file_path = path
	md.file_version = U_SaveEnvelope.SAVE_FILE_VERSION
	md.timestamp = Time.get_unix_time_from_system()
	md.formatted_timestamp = _format_timestamp(md.timestamp)

	# Extract scene info
	var scene_slice: Dictionary = state.get("scene", {})
	var scene_id_variant: Variant = scene_slice.get("current_scene_id", StringName(""))
	if scene_id_variant is StringName:
		md.scene_id = scene_id_variant as StringName
	else:
		md.scene_id = StringName(String(scene_id_variant))
	md.scene_name = String(md.scene_id)

	# Extract gameplay info
	var gameplay_slice: Dictionary = state.get("gameplay", {})
	md.play_time_seconds = float(gameplay_slice.get("play_time_seconds", 0.0))
	md.player_health = float(gameplay_slice.get("player_health", 0.0))
	md.player_max_health = float(gameplay_slice.get("player_max_health", 0.0))
	md.death_count = int(gameplay_slice.get("death_count", 0))

	# Extract completed areas
	var completed_variant: Variant = gameplay_slice.get("completed_areas", [])
	if completed_variant is Array:
		var completed_strings: Array[String] = []
		for area in (completed_variant as Array):
			completed_strings.append(String(area))
		md.completed_areas = completed_strings
	else:
		md.completed_areas = []

	md.completion_percentage = -1.0  # TODO: Calculate from completed areas

	return md


static func _format_timestamp(unix_time_seconds: float) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_time_seconds))
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]
