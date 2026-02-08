@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_save_manager.gd"
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
## Discovery: Registered with ServiceLocator
##
## Dependencies:
## - M_StateStore: State access and dispatch
## - M_SceneManager: Scene transitions during load

const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")
const I_SCENE_MANAGER := preload("res://scripts/interfaces/i_scene_manager.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_SAVE_FILE_IO := preload("res://scripts/managers/helpers/u_save_file_io.gd")
const U_SAVE_MIGRATION_ENGINE := preload("res://scripts/managers/helpers/u_save_migration_engine.gd")
const U_SCREENSHOT_CAPTURE := preload("res://scripts/managers/helpers/u_screenshot_capture.gd")
const U_SAVE_VALIDATOR := preload("res://scripts/utils/u_save_validator.gd")

## Save file format version
const SAVE_VERSION := 1

## Slot IDs
const SLOT_AUTOSAVE := StringName("autosave")
const SLOT_01 := StringName("slot_01")
const SLOT_02 := StringName("slot_02")
const SLOT_03 := StringName("slot_03")

## All available slots (autosave + 3 manual slots)
const ALL_SLOTS: Array[StringName] = [SLOT_AUTOSAVE, SLOT_01, SLOT_02, SLOT_03]

## Save directory (configurable for testing)
var _save_dir: String = "user://saves/"

## Internal references
var _state_store: I_StateStore = null
var _scene_manager: Node = null  # M_SceneManager
var _autosave_scheduler: Node = null  # U_AutosaveScheduler
var _screenshot_capture: U_ScreenshotCapture = null

## Lock flags to prevent concurrent operations
var _is_saving: bool = false
var _is_loading: bool = false

## Tracks which scene we're loading to (for transition completion verification)
var _loading_target_scene: StringName = StringName("")

## Store subscription unsubscribe callback (for transition completion)
var _transition_complete_unsubscribe: Callable

func _ready() -> void:
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

	# Initialize autosave scheduler
	_initialize_autosave_scheduler()

## Set save directory (for testing)
## IMPORTANT: Must be called BEFORE adding manager to tree
func set_save_directory(path: String) -> void:
	_save_dir = path
	if not _save_dir.ends_with("/"):
		_save_dir += "/"

## Initialize save directory and cleanup orphaned files
func _initialize_save_system() -> void:
	var file_io := U_SAVE_FILE_IO.new()

	# Ensure production save directory exists (legacy behavior)
	file_io.ensure_save_directory()

	# Ensure configured save directory exists (tests/custom dirs)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(_save_dir)
	if dir_error != OK:
		push_error("M_SaveManager: Failed to create save directory: %s (error %d)" % [_save_dir, dir_error])

	# Clean up orphaned .tmp files from previous crashes
	file_io.cleanup_tmp_files(_save_dir)

	# Clean up orphaned thumbnail files (no matching .json save)
	_cleanup_orphaned_thumbnails()

	# Import legacy save file if it exists (one-time migration)
	# NOTE: Legacy saves are always located at user://savegame.json, so only perform
	# migration when using the production save directory (prevents tests/custom dirs
	# from deleting a real legacy save file).
	if _save_dir == "user://saves/":
		_import_legacy_save_if_exists()

## Import legacy save file (user://savegame.json) to autosave slot if it exists
func _import_legacy_save_if_exists() -> void:
	# Check if legacy save exists
	if not U_SAVE_MIGRATION_ENGINE.should_import_legacy_save():
		return

	# Safety: If we already have an autosave in the current slot system, don't import legacy.
	# This prevents repeatedly overwriting/“corrupting” the autosave if a stale legacy file
	# (user://savegame.json) lingers on disk for any reason.
	if slot_exists(SLOT_AUTOSAVE):
		push_warning("M_SaveManager: Legacy save exists at user://savegame.json but autosave slot already exists; skipping import")
		return

	# Import and migrate legacy save
	var migrated_save: Dictionary = U_SAVE_MIGRATION_ENGINE.import_legacy_save()

	if migrated_save.is_empty():
		push_error("M_SaveManager: Failed to import legacy save")
		return

	# Write migrated save to autosave slot
	var autosave_path: String = _get_slot_file_path(SLOT_AUTOSAVE)
	print("M_SaveManager: Importing legacy save user://savegame.json -> %s" % autosave_path)
	var file_io := U_SAVE_FILE_IO.new()
	var result: Error = file_io.save_to_file(autosave_path, migrated_save)

	if result == OK:
		print("M_SaveManager: Successfully imported legacy save to autosave slot")
	else:
		push_error("M_SaveManager: Failed to write imported legacy save (error %d)" % result)

## Clean up orphaned thumbnail files (no matching .json save)
func _cleanup_orphaned_thumbnails() -> void:
	var dir := DirAccess.open(_save_dir)
	if dir == null:
		push_error("M_SaveManager: Failed to open save directory for thumbnail cleanup")
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with("_thumb.png"):
			var base_name: String = file_name.get_basename()
			var slot_base: String = base_name.trim_suffix("_thumb")
			var save_path: String = _get_slot_file_path(StringName(slot_base))
			if not FileAccess.file_exists(save_path):
				var remove_error: Error = dir.remove(file_name)
				if remove_error != OK:
					push_error("M_SaveManager: Failed to remove orphaned thumbnail: %s (error %d)" % [file_name, remove_error])
				else:
					print_verbose("M_SaveManager: Removed orphaned thumbnail: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Initialize autosave scheduler as child node
func _initialize_autosave_scheduler() -> void:
	# Load and instantiate the autosave scheduler script
	var scheduler_script := load("res://scripts/managers/helpers/u_autosave_scheduler.gd")
	_autosave_scheduler = scheduler_script.new()
	_autosave_scheduler.name = "U_AutosaveScheduler"

	# Add as child node
	add_child(_autosave_scheduler)

	# Scheduler will auto-initialize and subscribe to events in its _ready()

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

## Check if save/load operations are currently locked
##
## Returns true if either a save or load operation is in progress.
## Used by U_AutosaveScheduler to prevent autosaves during save/load operations.
func is_locked() -> bool:
	return _is_saving or _is_loading

## ============================================================================
## Public API - Save Operations
## ============================================================================

## Request an autosave (called by U_AutosaveScheduler)
##
## Always saves to the autosave slot. Priority parameter is reserved for future
## cooldown enforcement but currently unused.
func request_autosave(_priority: int = 0) -> void:
	save_to_slot(SLOT_AUTOSAVE)

## Save current state to a specific slot
##
## Returns Error code (OK on success, ERR_BUSY if already saving)
func save_to_slot(slot_id: StringName) -> Error:
	# Check lock - reject if already saving
	if _is_saving:
		return ERR_BUSY

	# Validate slot_id
	if not slot_id in ALL_SLOTS:
		push_error("M_SaveManager: Invalid slot_id: %s" % slot_id)
		return ERR_INVALID_PARAMETER

	# Set lock
	_is_saving = true

	# Emit save_started event
	var is_autosave: bool = (slot_id == SLOT_AUTOSAVE)
	U_ECSEventBus.publish(StringName("save_started"), {
		"slot_id": slot_id,
		"is_autosave": is_autosave
	})

	# Get persistable state (transient fields already filtered)
	var state: Dictionary = _state_store.get_persistable_state()
	if state.has("audio"):
		state.erase("audio")
	if state.has("display"):
		state.erase("display")

	# Build header metadata
	var header: Dictionary = _build_metadata(slot_id)
	var thumbnail_path: String = _try_save_thumbnail(slot_id)
	if not thumbnail_path.is_empty():
		header["thumbnail_path"] = thumbnail_path

	# Combine header + state
	var save_data := {
		"header": header,
		"state": state
	}

	# Write to file atomically
	var file_path: String = _get_slot_file_path(slot_id)
	var file_io := U_SAVE_FILE_IO.new()
	var result: Error = file_io.save_to_file(file_path, save_data)

	# Clear lock
	_is_saving = false

	# Emit completion event
	if result == OK:
		U_ECSEventBus.publish(StringName("save_completed"), {
			"slot_id": slot_id
		})
	else:
		U_ECSEventBus.publish(StringName("save_failed"), {
			"slot_id": slot_id,
			"error_code": result
		})

	return result

## Load state from a specific slot
##
## Loads the save file, preserves state to StateHandoff, and transitions to the saved scene.
## M_StateStore will automatically restore state after the scene loads.
##
## Returns Error code (OK on success, ERR_BUSY if already loading/transitioning, ERR_FILE_NOT_FOUND if slot doesn't exist)
func load_from_slot(slot_id: StringName) -> Error:
	# Check if already loading
	if _is_loading:
		return ERR_BUSY

	# Check if scene manager is currently transitioning
	var typed_scene_manager := _scene_manager as I_SceneManager
	if typed_scene_manager != null:
		if typed_scene_manager.is_transitioning():
			return ERR_BUSY

	# Validate slot_id
	if not slot_id in ALL_SLOTS:
		push_error("M_SaveManager: Invalid slot_id: %s" % slot_id)
		return ERR_INVALID_PARAMETER

	# Check if slot exists
	if not slot_exists(slot_id):
		return ERR_FILE_NOT_FOUND

	# Set loading lock
	_is_loading = true

	# Read and validate save file
	var file_path: String = _get_slot_file_path(slot_id)
	var validation_result: Dictionary = _validate_and_load_save_file(file_path)

	if validation_result.has("error"):
		_clear_loading_lock()
		return validation_result["error"]

	var header: Dictionary = validation_result["header"]
	var loaded_state: Dictionary = validation_result["state"]
	var target_scene_id: StringName = validation_result["scene_id"]
	if loaded_state.has("audio"):
		loaded_state.erase("audio")
	if loaded_state.has("display"):
		loaded_state.erase("display")

	# BUG FIX: Clear scene_stack from loaded state to prevent pausing on load
	# Legacy saves may have scene_stack persisted (before it was marked transient)
	# Clearing it here prevents M_PauseManager from pausing the tree after load
	if loaded_state.has("scene"):
		var scene_slice: Dictionary = loaded_state["scene"]
		if scene_slice.has("scene_stack"):
			scene_slice.erase("scene_stack")
			loaded_state["scene"] = scene_slice

	# BUG FIX: Clear navigation overlay state from loaded state (legacy saves)
	# Navigation slice is now entirely transient, but legacy saves may have persisted it
	# Clear overlay_stack, overlay_return_stack, and save_load_mode to prevent UI issues
	if loaded_state.has("navigation"):
		var nav_slice: Dictionary = loaded_state["navigation"]
		if nav_slice.has("overlay_stack"):
			nav_slice.erase("overlay_stack")
		if nav_slice.has("overlay_return_stack"):
			nav_slice.erase("overlay_return_stack")
		if nav_slice.has("save_load_mode"):
			nav_slice.erase("save_load_mode")
		loaded_state["navigation"] = nav_slice

	# Apply loaded state directly to M_StateStore
	# This updates all slices immediately before scene transition
	var typed_store := _state_store as I_StateStore
	if typed_store != null:
		typed_store.apply_loaded_state(loaded_state)
		if typed_store.has_method("apply_global_settings_from_disk"):
			typed_store.call("apply_global_settings_from_disk")
	else:
		# Fallback: preserve to StateHandoff (legacy behavior)
		for slice_name in loaded_state:
			var slice_data: Dictionary = loaded_state[slice_name]
			U_STATE_HANDOFF.preserve_slice(StringName(slice_name), slice_data)

	# Store target scene for transition completion verification
	_loading_target_scene = target_scene_id

	# Subscribe to state store to detect when transition completes
	# We'll clear _is_loading lock when we see transition_completed action
	if _state_store:
		_transition_complete_unsubscribe = _state_store.subscribe(_on_load_transition_action)

	# BUG FIX: Always use loading screen when loading from saves
	# Loading is a significant operation that deserves visual feedback
	var transition_type: String = "loading"

	# Trigger scene transition with loading screen
	# Note: M_StateStore will restore state from handoff after scene loads
	var scene_mgr := _scene_manager as I_SceneManager
	if scene_mgr != null:
		scene_mgr.transition_to_scene(target_scene_id, transition_type)
	else:
		# No scene manager - clear handoff, unsubscribe, and fail gracefully
		U_STATE_HANDOFF.clear_all()
		_clear_loading_lock()
		push_error("M_SaveManager: No scene manager available for load transition")
		return ERR_UNAVAILABLE

	return OK

## Delete a save slot
##
## Removes the save file and backup for the specified slot.
## Cannot delete the autosave slot.
##
## Returns Error code (OK on success, ERR_UNAUTHORIZED for autosave, ERR_FILE_NOT_FOUND if slot doesn't exist)
func delete_slot(slot_id: StringName) -> Error:
	# Prevent deletion of autosave slot
	if slot_id == SLOT_AUTOSAVE:
		return ERR_UNAUTHORIZED

	# Validate slot_id
	if not slot_id in ALL_SLOTS:
		push_error("M_SaveManager: Invalid slot_id: %s" % slot_id)
		return ERR_INVALID_PARAMETER

	# Check if slot exists
	if not slot_exists(slot_id):
		return ERR_FILE_NOT_FOUND

	var file_path: String = _get_slot_file_path(slot_id)
	var bak_path: String = file_path + ".bak"
	var tmp_path: String = file_path + ".tmp"
	var thumbnail_path: String = _get_thumbnail_file_path(slot_id)

	var dir := DirAccess.open(_save_dir)
	if not dir:
		push_error("M_SaveManager: Failed to open save directory for deletion")
		return ERR_FILE_CANT_OPEN

	# Delete main file
	if FileAccess.file_exists(file_path):
		var error: Error = dir.remove(file_path.get_file())
		if error != OK:
			push_error("M_SaveManager: Failed to delete save file: %s (error %d)" % [file_path, error])
			return error

	# Delete backup file if it exists
	if FileAccess.file_exists(bak_path):
		dir.remove(bak_path.get_file())

	# Delete temp file if it exists (cleanup)
	if FileAccess.file_exists(tmp_path):
		dir.remove(tmp_path.get_file())

	# Delete thumbnail file if it exists
	if FileAccess.file_exists(thumbnail_path):
		var thumb_error: Error = dir.remove(thumbnail_path.get_file())
		if thumb_error != OK:
			push_error("M_SaveManager: Failed to delete thumbnail file: %s (error %d)" % [thumbnail_path, thumb_error])

	return OK

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

	# Read header from save file
	var file_path: String = _get_slot_file_path(slot_id)
	var file_io := U_SAVE_FILE_IO.new()
	file_io.silent_mode = true  # Don't spam warnings for missing files
	var save_data: Dictionary = file_io.load_from_file(file_path)

	if save_data.is_empty():
		return {}

	# Extract and return header
	var header: Dictionary = save_data.get("header", {})
	if header.is_empty():
		return {}

	# Add exists flag for consistency
	header["exists"] = true
	return header

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

## Check if any save files exist
func has_any_saves() -> bool:
	for slot_id in ALL_SLOTS:
		if slot_exists(slot_id):
			return true
	return false

## Get the most recent save slot ID (by timestamp)
## Returns the slot_id of the newest save, or empty StringName if no saves exist
## Priority: autosave → newest manual save
func get_most_recent_save_slot() -> StringName:
	var most_recent_slot: StringName = StringName("")
	var most_recent_timestamp: String = ""

	for slot_id in ALL_SLOTS:
		var metadata := get_slot_metadata(slot_id)
		if metadata.is_empty():
			continue  # Skip empty slots

		var timestamp: String = metadata.get("timestamp", "")
		if timestamp.is_empty():
			continue

		# First save found, or this one is newer
		if most_recent_timestamp.is_empty() or timestamp > most_recent_timestamp:
			most_recent_timestamp = timestamp
			most_recent_slot = slot_id

	return most_recent_slot

## ============================================================================
## Internal - Load Transition Management
## ============================================================================

## Callback for state store actions during load
## Listens for transition_completed to clear loading lock
func _on_load_transition_action(action: Dictionary, _state: Dictionary) -> void:
	var action_type: String = str(action.get("type", ""))

	# Only care about transition_completed actions
	if action_type != String(U_SCENE_ACTIONS.ACTION_TRANSITION_COMPLETED):
		return

	# Verify the scene_id matches what we're loading
	var payload: Dictionary = action.get("payload", {})
	var completed_scene_id: StringName = payload.get("scene_id", StringName(""))

	if completed_scene_id != _loading_target_scene:
		# Not our transition - ignore
		return

	# Transition complete - clear loading lock
	_clear_loading_lock()

## Clear loading lock and cleanup transition tracking
func _clear_loading_lock() -> void:
	_is_loading = false
	_loading_target_scene = StringName("")

	# Unsubscribe from state store if we have an active subscription
	if _transition_complete_unsubscribe.is_valid():
		_transition_complete_unsubscribe.call()
		_transition_complete_unsubscribe = Callable()

## ============================================================================
## Internal - Load Validation
## ============================================================================

## Validate and load a save file
##
## Returns a Dictionary with either:
## - Success: {"header": Dictionary, "state": Dictionary, "scene_id": StringName}
## - Failure: {"error": Error}
func _validate_and_load_save_file(file_path: String) -> Dictionary:
	var file_io := U_SAVE_FILE_IO.new()
	file_io.silent_mode = true  # Don't spam warnings during load
	var save_data: Dictionary = file_io.load_from_file(file_path)

	# Check if file loaded successfully
	if save_data.is_empty():
		push_error("M_SaveManager: Failed to load save file")
		return {"error": ERR_FILE_CORRUPT}

	# Apply migrations to upgrade old save files (v0 → v1, etc.)
	save_data = U_SAVE_MIGRATION_ENGINE.migrate(save_data)

	# Validate save structure using U_SaveValidator
	var validation_result: Dictionary = U_SAVE_VALIDATOR.validate_save_structure(save_data)

	if not validation_result.get("valid", false):
		# Validation failed - emit error with detailed message
		var error_message: String = validation_result.get("message", "Unknown validation error")
		push_error("M_SaveManager: %s" % error_message)
		return {"error": validation_result.get("error", ERR_FILE_CORRUPT)}

	# Validation succeeded - extract validated data
	return {
		"header": validation_result["header"],
		"state": validation_result["state"],
		"scene_id": validation_result["scene_id"]
	}

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
	return _save_dir + String(slot_id) + ".json"

## Get thumbnail file path for a slot
func _get_thumbnail_file_path(slot_id: StringName) -> String:
	return _save_dir + String(slot_id) + "_thumb.png"

## Attempt to capture and save a thumbnail for the given slot.
## Returns the thumbnail path if saved successfully, otherwise an empty string.
func _try_save_thumbnail(slot_id: StringName) -> String:
	var image: Image = _get_thumbnail_image_for_slot(slot_id)
	if image == null:
		return ""

	var capture := _get_screenshot_capture()
	var resized: Image = capture.resize_to_thumbnail(image)
	if resized == null:
		return ""

	var thumbnail_path := _get_thumbnail_file_path(slot_id)
	var error: Error = _write_thumbnail_image(resized, thumbnail_path)
	if error != OK:
		return ""

	return thumbnail_path

## Resolve which image to use for the slot.
## Autosave captures live; manual saves use cached image from pause.
func _get_thumbnail_image_for_slot(slot_id: StringName) -> Image:
	if slot_id == SLOT_AUTOSAVE:
		return _capture_autosave_image()
	return _get_cached_manual_image()

## Capture a live viewport image for autosaves.
func _capture_autosave_image() -> Image:
	var viewport := get_viewport()
	var capture := _get_screenshot_capture()
	return capture.capture_viewport(viewport)

## Fetch cached screenshot for manual saves.
func _get_cached_manual_image() -> Image:
	var cache := _get_screenshot_cache()
	if cache == null:
		return null
	if cache.has_method("get_cached_screenshot"):
		return cache.call("get_cached_screenshot")
	return null

## Write a thumbnail image to disk.
func _write_thumbnail_image(image: Image, path: String) -> Error:
	var capture := _get_screenshot_capture()
	return capture.save_to_file(image, path)

func _get_screenshot_cache() -> Node:
	return U_ServiceLocator.try_get_service(StringName("screenshot_cache"))

func _get_screenshot_capture() -> U_ScreenshotCapture:
	if _screenshot_capture == null:
		_screenshot_capture = U_SCREENSHOT_CAPTURE.new()
	return _screenshot_capture

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
