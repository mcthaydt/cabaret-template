@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_SaveManager

## Save Manager - Coordinates save/load timing, slot management, and disk IO
##
## Responsibilities:
## - Manage save slots (autosave + 3 manual slots)
## - Coordinate save/load operations with atomic writes
## - Handle migrations and versioning
## - Emit save/load events for UI integration
## - Block autosaves during critical operations (death, loading)
##
## Discovery: Add to "save_manager" group, discoverable via ServiceLocator
##
## Dependencies:
## - M_StateStore: State access and dispatch
## - M_SceneManager: Scene transitions during load

const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")

## Save file format version
const SAVE_VERSION := 1

## Slot IDs
const SLOT_AUTOSAVE := StringName("autosave")
const SLOT_01 := StringName("slot_01")
const SLOT_02 := StringName("slot_02")
const SLOT_03 := StringName("slot_03")

## All available slots (autosave + 3 manual slots)
const ALL_SLOTS: Array[StringName] = [SLOT_AUTOSAVE, SLOT_01, SLOT_02, SLOT_03]

## Save directory
const SAVE_DIR := "user://saves/"

## Internal references
var _state_store: I_StateStore = null
var _scene_manager: Node = null  # M_SceneManager

## Lock flags to prevent concurrent operations
var _is_saving: bool = false
var _is_loading: bool = false

func _ready() -> void:
	# Add to save_manager group for discovery
	add_to_group("save_manager")

	# Register with ServiceLocator
	U_ServiceLocator.register(StringName("save_manager"), self)

	# Wait for ServiceLocator to initialize other services
	await get_tree().process_frame

	# Discover dependencies via ServiceLocator
	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if not _state_store:
		push_error("M_SaveManager: No M_StateStore registered with ServiceLocator")
		return

	_scene_manager = U_ServiceLocator.try_get_service(StringName("scene_manager"))
	if not _scene_manager:
		push_warning("M_SaveManager: No M_SceneManager registered with ServiceLocator")

	# Initialize save system
	_initialize_save_system()

## Initialize save directory and cleanup orphaned files
func _initialize_save_system() -> void:
	var file_io := M_SaveFileIO.new()

	# Ensure save directory exists
	file_io.ensure_save_directory()

	# Clean up orphaned .tmp files from previous crashes
	file_io.cleanup_tmp_files(SAVE_DIR)

## Get state store reference (for testing)
func _get_state_store() -> I_StateStore:
	return _state_store

## Get scene manager reference (for testing)
func _get_scene_manager() -> Node:
	return _scene_manager

## Check if save operation is locked (for testing)
func _is_saving_locked() -> bool:
	return _is_saving

## Check if load operation is locked (for testing)
func _is_loading_locked() -> bool:
	return _is_loading

## ============================================================================
## Public API - Slot Registry
## ============================================================================

## Get all slot IDs
func get_all_slot_ids() -> Array:
	return ALL_SLOTS.duplicate()

## Check if a slot has a valid save file
func slot_exists(slot_id: StringName) -> bool:
	var file_path := _get_slot_file_path(slot_id)
	return FileAccess.file_exists(file_path)

## Get metadata for a specific slot
func get_slot_metadata(slot_id: StringName) -> Dictionary:
	if not slot_exists(slot_id):
		return {}

	# For now, return empty - will be implemented in Phase 3 when we add file I/O
	# This needs to read the header from the save file
	return {}

## Get metadata for all slots (for UI display)
func get_all_slot_metadata() -> Array[Dictionary]:
	var all_metadata: Array[Dictionary] = []

	for slot_id in ALL_SLOTS:
		var metadata := get_slot_metadata(slot_id)
		if metadata.is_empty():
			# Create empty slot metadata
			metadata = {
				"slot_id": slot_id,
				"exists": false
			}
		else:
			metadata["exists"] = true

		all_metadata.append(metadata)

	return all_metadata

## ============================================================================
## Internal - Metadata Building
## ============================================================================

## Build metadata header from current state
func _build_metadata(slot_id: StringName) -> Dictionary:
	if not _state_store:
		push_error("M_SaveManager: Cannot build metadata without state store")
		return {}

	var state := _state_store.get_state()
	var gameplay: Dictionary = state.get("gameplay", {})
	var scene: Dictionary = state.get("scene", {})

	# Extract fields from state
	var playtime_seconds: int = gameplay.get("playtime_seconds", 0)
	var current_scene_id: String = scene.get("current_scene_id", "")
	var last_checkpoint: String = gameplay.get("last_checkpoint", "")
	var target_spawn_point: String = gameplay.get("target_spawn_point", "")

	# Derive area_name from scene registry
	var area_name := _get_area_name_from_scene(current_scene_id)

	# Generate ISO 8601 timestamp
	var timestamp := _get_iso8601_timestamp()

	# Build header
	var metadata := {
		"save_version": SAVE_VERSION,
		"timestamp": timestamp,
		"build_id": _get_build_id(),
		"playtime_seconds": playtime_seconds,
		"current_scene_id": current_scene_id,
		"last_checkpoint": last_checkpoint,
		"target_spawn_point": target_spawn_point,
		"area_name": area_name,
		"slot_id": slot_id,
		"thumbnail_path": ""  # Deferred feature
	}

	return metadata

## Get file path for a slot
func _get_slot_file_path(slot_id: StringName) -> String:
	return SAVE_DIR + String(slot_id) + ".json"

## Get current timestamp in ISO 8601 format
func _get_iso8601_timestamp() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second
	]

## Get build ID (version identifier)
func _get_build_id() -> String:
	# Try to get version from project settings
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	if version.is_empty():
		# Fallback: use application name + "dev"
		var app_name: String = ProjectSettings.get_setting("application/config/name", "Unknown")
		return app_name + " (dev)"
	return version

## Get human-readable area name from scene ID
func _get_area_name_from_scene(scene_id: String) -> String:
	if scene_id.is_empty():
		return "Unknown"

	# Try to get display name from scene registry
	var scene_info: Dictionary = U_SceneRegistry.get_scene(StringName(scene_id))
	if scene_info and scene_info.has("display_name"):
		return scene_info["display_name"]

	# Fallback: Format the scene_id into a readable name
	# "gameplay_base" -> "Gameplay Base"
	var formatted := scene_id.replace("_", " ")
	var words := formatted.split(" ")
	var capitalized_words: Array[String] = []

	for word in words:
		if word.length() > 0:
			capitalized_words.append(word.capitalize())

	return " ".join(capitalized_words)
