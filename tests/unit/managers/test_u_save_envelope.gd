extends GutTest

const U_SaveTestHelpers := preload("res://tests/helpers/u_save_test_helpers.gd")
const U_SaveEnvelope := preload("res://scripts/state/utils/u_save_envelope.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")

var _files: U_SaveTestHelpers.SaveFileTracker

func before_each() -> void:
	_files = U_SaveTestHelpers.create_save_file_tracker()

func after_each() -> void:
	if _files != null:
		_files.cleanup()
	_files = null

func test_write_envelope_writes_version_metadata_and_state() -> void:
	var path := _files.make_path("save_envelope", "json", "save_manager")

	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id = 1
	metadata.slot_type = RS_SaveSlotMetadata.SlotType.MANUAL
	metadata.scene_id = StringName("gameplay_base")
	metadata.scene_name = "Gameplay Base"
	metadata.is_empty = false
	metadata.file_version = U_SaveEnvelope.SAVE_FILE_VERSION
	metadata.file_path = path

	var state := {
		"gameplay": {
			"paused": false,
			"death_count": 3,
		}
	}

	var err := U_SaveEnvelope.write_envelope(path, metadata, state)
	assert_eq(err, OK)
	assert_true(FileAccess.file_exists(path))

	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file)
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary)

	var envelope := parsed as Dictionary
	assert_eq(int(envelope.get("version", -1)), U_SaveEnvelope.SAVE_FILE_VERSION)
	assert_true(envelope.get("metadata") is Dictionary)
	assert_true(envelope.get("state") is Dictionary)

	var md := envelope["metadata"] as Dictionary
	assert_eq(md.get("scene_id"), "gameplay_base")
	assert_eq(bool(md.get("is_empty")), false)

func test_invalid_json_returns_empty_envelope() -> void:
	var path := _files.make_path("invalid_json", "json", "save_manager")

	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string("{ this is not valid json")
	file.close()

	var envelope := U_SaveEnvelope.try_read_envelope(path)
	assert_eq(envelope, {})

	var metadata := U_SaveEnvelope.try_read_metadata(path)
	assert_true(metadata.is_empty)

func test_unsupported_version_returns_empty_envelope() -> void:
	var path := _files.make_path("unsupported_version", "json", "save_manager")

	var bad := {
		"version": 999,
		"metadata": {
			"is_empty": false
		},
		"state": {}
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(bad))
	file.close()

	var envelope := U_SaveEnvelope.try_read_envelope(path)
	assert_eq(envelope, {})

func test_missing_metadata_or_state_returns_empty_envelope() -> void:
	var path1 := _files.make_path("missing_metadata", "json", "save_manager")
	var file1 := FileAccess.open(path1, FileAccess.WRITE)
	assert_not_null(file1)
	file1.store_string(JSON.stringify({"version": U_SaveEnvelope.SAVE_FILE_VERSION, "state": {}}))
	file1.close()
	assert_eq(U_SaveEnvelope.try_read_envelope(path1), {})

	var path2 := _files.make_path("missing_state", "json", "save_manager")
	var file2 := FileAccess.open(path2, FileAccess.WRITE)
	assert_not_null(file2)
	file2.store_string(JSON.stringify({"version": U_SaveEnvelope.SAVE_FILE_VERSION, "metadata": {}}))
	file2.close()
	assert_eq(U_SaveEnvelope.try_read_envelope(path2), {})

func test_legacy_import_wraps_once_and_renames_backup() -> void:
	var dir_path := U_SaveTestHelpers.ensure_test_subdir("save_manager_legacy_import")
	U_SaveTestHelpers.purge_test_subdir("save_manager_legacy_import")

	var legacy_path := "%s/savegame.json" % dir_path
	var auto_path := "%s/savegame_auto.json" % dir_path
	var backup_path := "%s/savegame_legacy_backup.json" % dir_path

	U_SaveTestHelpers.remove_file_if_exists(legacy_path)
	U_SaveTestHelpers.remove_file_if_exists(auto_path)
	U_SaveTestHelpers.remove_file_if_exists(backup_path)

	var legacy_state := {
		"gameplay": {
			"paused": true,
			"death_count": 1,
		}
	}

	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	assert_not_null(legacy_file)
	legacy_file.store_string(JSON.stringify(legacy_state))
	legacy_file.close()
	assert_true(FileAccess.file_exists(legacy_path))

	var err := U_SaveEnvelope.try_import_legacy_as_auto_slot(legacy_path, auto_path, backup_path)
	assert_eq(err, OK)
	assert_true(FileAccess.file_exists(auto_path))
	assert_false(FileAccess.file_exists(legacy_path))
	assert_true(FileAccess.file_exists(backup_path))

	var envelope := U_SaveEnvelope.try_read_envelope(auto_path)
	assert_eq(int(envelope.get("version", -1)), U_SaveEnvelope.SAVE_FILE_VERSION)
	assert_true(envelope.get("metadata") is Dictionary)
	assert_true(envelope.get("state") is Dictionary)

	var err2 := U_SaveEnvelope.try_import_legacy_as_auto_slot(legacy_path, auto_path, backup_path)
	assert_eq(err2, OK)
