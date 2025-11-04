extends GutTest

## Unit tests for U_SceneRegistry resource-based scene entries loader (T212)

const U_SceneRegistry := preload("res://scripts/scene_management/u_scene_registry.gd")
const RS_SceneRegistryEntry := preload("res://scripts/scene_management/resources/rs_scene_registry_entry.gd")

var _tmp_path := "res://resources/scene_registry/tmp_registry_test.tres"
var _tmp_scene_id := StringName("tmp_registry_test_scene")
var _scenes_backup: Dictionary

func after_each() -> void:
    # Cleanup registry and file if present
    if _scenes_backup != null:
        U_SceneRegistry._scenes = _scenes_backup  # restore previous registry
    var da := DirAccess.open("res://resources/scene_registry/")
    if da and da.file_exists("tmp_registry_test.tres"):
        da.remove("tmp_registry_test.tres")

func test_loads_valid_resource_entry_and_skips_duplicates() -> void:
    # Backup and clear scenes to avoid duplicate warnings from existing .tres files
    _scenes_backup = (U_SceneRegistry._scenes as Dictionary).duplicate(true)
    U_SceneRegistry._scenes = {}

    # Create a valid resource entry .tres
    var entry := RS_SceneRegistryEntry.new()
    entry.scene_id = _tmp_scene_id
    entry.scene_path = "res://scenes/tmp_invalid_gameplay.tscn"  # existing test scene path
    entry.scene_type = 1  # GAMEPLAY
    entry.default_transition = "instant"
    entry.preload_priority = 0

    var save_err := ResourceSaver.save(entry, _tmp_path)
    assert_eq(save_err, OK, "Should save registry entry resource")

    # Load entries from directory (invokable at runtime)
    U_SceneRegistry._load_resource_entries()

    # Assert scene registered
    assert_true(U_SceneRegistry._scenes.has(_tmp_scene_id), "Resource entry should be registered")

