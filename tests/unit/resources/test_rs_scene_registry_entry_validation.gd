extends GutTest

## Tests for RS_SceneRegistryEntry schema validation (F15).
##
## Validates that empty scene_id and scene_path push_error (elevated from
## editor-only push_warning), and that valid entries produce no errors.
## The existing is_valid() utility remains as a double-check layer.

const TEST_RESOURCE_PATH := "res://tests/unit/resources/test_cfg_scene_entry_invalid.tres"


func test_empty_scene_id_pushes_error() -> void:
	var entry := RS_SceneRegistryEntry.new()
	autofree(entry)
	entry.scene_id = StringName("")
	assert_push_error("scene_id must not be empty")


func test_empty_scene_path_pushes_error() -> void:
	var entry := RS_SceneRegistryEntry.new()
	autofree(entry)
	entry.scene_path = ""
	assert_push_error("scene_path must not be empty")


func test_valid_entry_no_error() -> void:
	var entry := RS_SceneRegistryEntry.new()
	autofree(entry)
	entry.scene_id = StringName("test_scene")
	entry.scene_path = "res://scenes/test.tscn"
	assert_push_error(0, "valid entry should produce no errors")


func test_error_includes_resource_path() -> void:
	var entry := RS_SceneRegistryEntry.new()
	autofree(entry)
	entry.resource_path = TEST_RESOURCE_PATH
	entry.scene_id = StringName("")
	assert_push_error(TEST_RESOURCE_PATH)


func test_is_valid_returns_false_for_empty_scene_id() -> void:
	var entry := RS_SceneRegistryEntry.new()
	autofree(entry)
	entry.scene_id = StringName("")
	entry.scene_path = "res://scenes/test.tscn"
	assert_push_error("scene_id must not be empty")
	assert_false(entry.is_valid(), "is_valid() should return false for empty scene_id")


func test_is_valid_returns_false_for_empty_scene_path() -> void:
	var entry := RS_SceneRegistryEntry.new()
	autofree(entry)
	entry.scene_id = StringName("test_scene")
	entry.scene_path = ""
	assert_push_error("scene_path must not be empty")
	assert_false(entry.is_valid(), "is_valid() should return false for empty scene_path")


func test_is_valid_returns_true_for_valid_entry() -> void:
	var entry := RS_SceneRegistryEntry.new()
	autofree(entry)
	entry.scene_id = StringName("test_scene")
	entry.scene_path = "res://scenes/test.tscn"
	assert_true(entry.is_valid(), "is_valid() should return true for valid entry")


func test_both_empty_fields_each_push_error() -> void:
	var entry := RS_SceneRegistryEntry.new()
	autofree(entry)
	entry.scene_id = StringName("")
	entry.scene_path = ""
	assert_push_error("scene_id must not be empty")
	assert_push_error("scene_path must not be empty")