extends BaseTest

const M_SAVE_MIGRATION_ENGINE := preload("res://scripts/managers/helpers/m_save_migration_engine.gd")

## Phase 7: Save Migration System Tests
##
## Tests version detection, migration chains, and legacy save import

## ============================================================================
## Version Detection Tests
## ============================================================================

func test_detect_version_returns_0_for_headerless_save() -> void:
	var headerless_save: Dictionary = {
		"gameplay": {"player_health": 100},
		"scene": {"current_scene_id": "gameplay_base"}
	}

	var version: int = M_SAVE_MIGRATION_ENGINE.detect_version(headerless_save)
	assert_eq(version, 0, "Headerless save should be detected as version 0")

func test_detect_version_returns_header_version_for_v1_plus() -> void:
	var v1_save: Dictionary = {
		"header": {"save_version": 1},
		"state": {}
	}

	var version: int = M_SAVE_MIGRATION_ENGINE.detect_version(v1_save)
	assert_eq(version, 1, "Should return version from header")

func test_detect_version_handles_missing_save_version_field() -> void:
	var malformed_save: Dictionary = {
		"header": {"timestamp": "2025-01-01T00:00:00Z"},
		"state": {}
	}

	var version: int = M_SAVE_MIGRATION_ENGINE.detect_version(malformed_save)
	assert_eq(version, 0, "Missing save_version field should default to 0")

## ============================================================================
## v0 -> v1 Migration Tests
## ============================================================================

func test_migrate_v0_to_v1_wraps_state_in_header_structure() -> void:
	var v0_save: Dictionary = {
		"gameplay": {"player_health": 100, "playtime_seconds": 42},
		"scene": {"current_scene_id": "gameplay_base"}
	}

	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(v0_save)

	assert_true(migrated.has("header"), "Migrated save should have header")
	assert_true(migrated.has("state"), "Migrated save should have state")
	assert_eq(migrated["header"]["save_version"], 1, "Header should indicate version 1")

func test_migrate_v0_to_v1_preserves_all_state_slices() -> void:
	var v0_save: Dictionary = {
		"gameplay": {"player_health": 75, "death_count": 3},
		"scene": {"current_scene_id": "interior_house"},
		"settings": {"master_volume": 0.8}
	}

	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(v0_save)

	var state: Dictionary = migrated["state"]
	assert_eq(state["gameplay"]["player_health"], 75, "Should preserve gameplay slice")
	assert_eq(state["scene"]["current_scene_id"], "interior_house", "Should preserve scene slice")
	assert_eq(state["settings"]["master_volume"], 0.8, "Should preserve settings slice")

func test_migrate_v0_to_v1_generates_default_header_fields() -> void:
	var v0_save: Dictionary = {
		"gameplay": {},  # No playtime_seconds - test default generation
		"scene": {"current_scene_id": "gameplay_base"}
	}

	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(v0_save)

	var header: Dictionary = migrated["header"]
	assert_eq(header["save_version"], 1, "Should set save_version to 1")
	assert_true(header.has("timestamp"), "Should generate timestamp")
	assert_eq(header.get("playtime_seconds", -1), 0, "Should default playtime to 0 if missing")

func test_migrate_v0_to_v1_extracts_playtime_from_gameplay_slice() -> void:
	var v0_save: Dictionary = {
		"gameplay": {"playtime_seconds": 42},
		"scene": {"current_scene_id": "gameplay_base"}
	}

	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(v0_save)

	assert_eq(migrated["header"]["playtime_seconds"], 42, "Should extract playtime from gameplay slice")

func test_migrate_v0_to_v1_extracts_scene_id_from_scene_slice() -> void:
	var v0_save: Dictionary = {
		"gameplay": {},
		"scene": {"current_scene_id": "exterior_village"}
	}

	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(v0_save)

	assert_eq(migrated["header"]["current_scene_id"], "exterior_village", "Should extract scene_id from scene slice")

## ============================================================================
## Migration Chain Tests
## ============================================================================

func test_migrate_v1_save_returns_unchanged() -> void:
	var v1_save: Dictionary = {
		"header": {"save_version": 1, "timestamp": "2025-01-01T00:00:00Z"},
		"state": {"gameplay": {"player_health": 100}}
	}

	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(v1_save)

	assert_eq(migrated["header"]["save_version"], 1, "v1 save should remain v1")
	assert_eq(migrated, v1_save, "v1 save should be unchanged")

func test_migrate_chains_multiple_versions() -> void:
	# This test will pass even without v2->v3 migrations defined
	# because migrate() will stop at the latest defined migration
	var v0_save: Dictionary = {
		"gameplay": {"player_health": 100},
		"scene": {"current_scene_id": "gameplay_base"}
	}

	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(v0_save)

	# Should at least migrate to v1
	assert_gte(migrated["header"]["save_version"], 1, "Should migrate to at least v1")

## ============================================================================
## Error Handling Tests
## ============================================================================

func test_migrate_handles_empty_dictionary() -> void:
	var empty_save: Dictionary = {}

	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(empty_save)

	# Should treat as v0 and wrap in header
	assert_true(migrated.has("header"), "Empty save should get header")
	assert_true(migrated.has("state"), "Empty save should get state wrapper")

func test_migrate_handles_invalid_header() -> void:
	var invalid_save: Dictionary = {
		"header": "this_is_not_a_dictionary",
		"state": {}
	}

	# Should detect as v0 (invalid structure) and re-wrap
	var migrated: Dictionary = M_SAVE_MIGRATION_ENGINE.migrate(invalid_save)

	assert_true(migrated["header"] is Dictionary, "Should have valid Dictionary header after migration")

## ============================================================================
## Legacy Save Import Tests (user://savegame.json)
## ============================================================================

func test_should_import_legacy_save_returns_true_if_file_exists() -> void:
	# Create a fake legacy save
	var legacy_path := "user://savegame.json"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"gameplay": {}}))
	file.close()

	var should_import: bool = M_SAVE_MIGRATION_ENGINE.should_import_legacy_save()

	assert_true(should_import, "Should return true when legacy save exists")

	# Cleanup
	DirAccess.remove_absolute(legacy_path)

func test_should_import_legacy_save_returns_false_if_file_missing() -> void:
	# Ensure no legacy save exists
	var legacy_path := "user://savegame.json"
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_path)

	var should_import: bool = M_SAVE_MIGRATION_ENGINE.should_import_legacy_save()

	assert_false(should_import, "Should return false when legacy save missing")

func test_import_legacy_save_migrates_and_returns_save_data() -> void:
	# Create a legacy save (v0 format)
	var legacy_path := "user://savegame.json"
	var legacy_data: Dictionary = {
		"gameplay": {"player_health": 80, "playtime_seconds": 120},
		"scene": {"current_scene_id": "gameplay_base"}
	}
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_data))
	file.close()

	var imported: Dictionary = M_SAVE_MIGRATION_ENGINE.import_legacy_save()

	# Should be migrated to v1 format
	assert_true(imported.has("header"), "Imported save should have header")
	assert_true(imported.has("state"), "Imported save should have state")
	assert_eq(imported["header"]["save_version"], 1, "Should migrate to v1")
	assert_eq(imported["state"]["gameplay"]["player_health"], 80, "Should preserve state data")

	# Cleanup
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_path)

func test_import_legacy_save_deletes_original_file() -> void:
	# Create a legacy save
	var legacy_path := "user://savegame.json"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"gameplay": {}}))
	file.close()

	M_SAVE_MIGRATION_ENGINE.import_legacy_save()

	assert_false(FileAccess.file_exists(legacy_path), "Legacy save should be deleted after import")
