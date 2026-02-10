extends RefCounted
class_name U_SaveMigrationEngine

## Save Migration Engine (Phase 7)
##
## Handles versioned save file migrations with pure Dictionary transformations.
## Migrations are composable and chainable for multi-version upgrades.
##
## Responsibilities:
## - Detect save file version (headerless = v0, header.save_version = v1+)
## - Apply migration transformations to upgrade saves
## - Chain migrations for multi-version jumps (v0 -> v3 = v0->v1->v2->v3)
## - Import legacy saves from user://savegame.json
##
## Migration contract:
## - All migrations are static functions: Dictionary -> Dictionary
## - Migrations are pure (no side effects)
## - Migrations are registered in MIGRATION_REGISTRY

## Current save file version
const CURRENT_VERSION := 1

## Legacy save path (pre-Phase 6)
const LEGACY_SAVE_PATH := "user://savegame.json"

## Migration registry: version -> migration Callable
## Each migration transforms version N to version N+1
@warning_ignore("unused_private_class_variable")
static var _migration_registry: Dictionary = {}

## Detect version from save file
##
## Returns:
## - 0 if headerless (v0 format)
## - header.save_version if present
static func detect_version(save_data: Dictionary) -> int:
	# Check if save has header
	if not save_data.has("header"):
		return 0  # Headerless = v0

	var header = save_data["header"]
	if not header is Dictionary:
		return 0  # Invalid header = treat as v0

	return header.get("save_version", 0)

## Migrate save file to current version
##
## Applies all necessary migrations in sequence to reach CURRENT_VERSION.
## Returns migrated save data.
static func migrate(save_data: Dictionary) -> Dictionary:
	var current_save := save_data.duplicate(true)
	var current_version := detect_version(current_save)

	# Apply migrations sequentially until we reach CURRENT_VERSION
	while current_version < CURRENT_VERSION:
		if current_version == 0:
			current_save = _migrate_v0_to_v1(current_save)
			current_version = 1
		# Future migrations would go here:
		# elif current_version == 1:
		#     current_save = _migrate_v1_to_v2(current_save)
		#     current_version = 2
		else:
			# No more migrations defined
			break

	return current_save

## Check if legacy save file exists
static func should_import_legacy_save(legacy_save_path: String = LEGACY_SAVE_PATH) -> bool:
	return FileAccess.file_exists(legacy_save_path)

## Import legacy save file and migrate it
##
## Loads user://savegame.json, migrates to current version, and deletes original.
## Returns migrated save data.
static func import_legacy_save(legacy_save_path: String = LEGACY_SAVE_PATH) -> Dictionary:
	# Load legacy save
	var file := FileAccess.open(legacy_save_path, FileAccess.READ)
	if file == null:
		push_error("U_SaveMigrationEngine: Failed to open legacy save at %s" % legacy_save_path)
		return {}

	var json_string := file.get_as_text()
	file.close()

	var legacy_data: Variant = JSON.parse_string(json_string)
	if not legacy_data is Dictionary:
		push_error("U_SaveMigrationEngine: Legacy save is not a valid Dictionary")
		return {}

	# Migrate to current version
	var migrated := migrate(legacy_data as Dictionary)

	# Delete original legacy save
	DirAccess.remove_absolute(legacy_save_path)

	return migrated

## ============================================================================
## Migration Functions (v0 -> v1, v1 -> v2, etc.)
## ============================================================================

## Migrate v0 (headerless) to v1 (with header)
static func _migrate_v0_to_v1(v0_save: Dictionary) -> Dictionary:
	# Build header from v0 state
	var header := {
		"save_version": 1,
		"timestamp": _get_iso8601_timestamp(),
		"build_id": _get_build_id(),
		"playtime_seconds": 0,
		"current_scene_id": "",
		"last_checkpoint": "",
		"target_spawn_point": "",
		"area_name": "",
		"thumbnail_path": "",
		"slot_id": ""  # Will be set by save manager when writing
	}

	# Extract metadata from gameplay slice if present
	var gameplay: Dictionary = v0_save.get("gameplay", {})
	if gameplay.has("playtime_seconds"):
		header["playtime_seconds"] = gameplay.get("playtime_seconds", 0)

	# Extract metadata from scene slice if present
	var scene: Dictionary = v0_save.get("scene", {})
	if scene.has("current_scene_id"):
		header["current_scene_id"] = scene.get("current_scene_id", "")
	if scene.has("last_checkpoint"):
		header["last_checkpoint"] = scene.get("last_checkpoint", "")
	if scene.has("target_spawn_point"):
		header["target_spawn_point"] = scene.get("target_spawn_point", "")

	# Wrap state in new structure
	return {
		"header": header,
		"state": v0_save.duplicate(true)
	}

## Helper: Get ISO 8601 timestamp
static func _get_iso8601_timestamp() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		datetime["year"],
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"],
		datetime["second"]
	]

## Helper: Get build ID
static func _get_build_id() -> String:
	if ProjectSettings.has_setting("application/config/version"):
		return ProjectSettings.get_setting("application/config/version")
	else:
		var project_name: String = ProjectSettings.get_setting("application/config/name", "Unknown")
		return "%s (dev)" % project_name
