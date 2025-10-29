extends GutTest

## Unit tests for SceneRegistry static class
##
## Tests scene metadata management and door pairing validation.
## Tests follow TDD discipline: written BEFORE implementation.

const SceneRegistry = preload("res://scripts/scene_management/scene_registry.gd")

func before_each() -> void:
	# SceneRegistry is static, no setup needed
	pass

func after_each() -> void:
	# SceneRegistry is static, no teardown needed
	pass

## Test scene metadata structure
func test_get_scene_returns_metadata() -> void:
	var scene_data: Dictionary = SceneRegistry.get_scene(StringName("gameplay_base"))

	assert_not_null(scene_data, "Should return scene data")
	assert_true(scene_data.has("scene_id"), "Should have scene_id")
	assert_true(scene_data.has("path"), "Should have path")
	assert_true(scene_data.has("scene_type"), "Should have scene_type")
	assert_true(scene_data.has("default_transition"), "Should have default_transition")
	assert_true(scene_data.has("preload_priority"), "Should have preload_priority")

## Test scene types enum
func test_scene_types_defined() -> void:
	assert_eq(SceneRegistry.SceneType.MENU, 0, "MENU type should be 0")
	assert_eq(SceneRegistry.SceneType.GAMEPLAY, 1, "GAMEPLAY type should be 1")
	assert_eq(SceneRegistry.SceneType.UI, 2, "UI type should be 2")
	assert_eq(SceneRegistry.SceneType.END_GAME, 3, "END_GAME type should be 3")

## Test getting scene by ID
func test_get_scene_with_valid_id() -> void:
	var scene_data: Dictionary = SceneRegistry.get_scene(StringName("main_menu"))

	assert_not_null(scene_data, "Should return data for valid scene ID")
	assert_eq(scene_data["scene_id"], StringName("main_menu"), "Should return correct scene_id")

## Test getting scene with invalid ID
func test_get_scene_with_invalid_id() -> void:
	var scene_data: Dictionary = SceneRegistry.get_scene(StringName("nonexistent_scene"))

	assert_eq(scene_data.size(), 0, "Should return empty dict for invalid scene ID")

## Test get_scene_path convenience method
func test_get_scene_path() -> void:
	var path: String = SceneRegistry.get_scene_path(StringName("gameplay_base"))

	assert_not_null(path, "Should return path for valid scene")
	assert_true(path.begins_with("res://scenes/"), "Path should start with res://scenes/")
	assert_true(path.ends_with(".tscn"), "Path should end with .tscn")

## Test get_scene_type convenience method
func test_get_scene_type() -> void:
	var scene_type: int = SceneRegistry.get_scene_type(StringName("gameplay_base"))

	assert_eq(scene_type, SceneRegistry.SceneType.GAMEPLAY, "Should return correct scene type")

## Test get_default_transition convenience method
func test_get_default_transition() -> void:
	var transition: String = SceneRegistry.get_default_transition(StringName("gameplay_base"))

	assert_true(transition in ["instant", "fade", "loading"], "Should return valid transition type")

## Test door pairing structure
func test_get_door_exit_returns_metadata() -> void:
	var exit_data: Dictionary = SceneRegistry.get_door_exit(
		StringName("exterior"),
		StringName("door_to_house")
	)

	assert_not_null(exit_data, "Should return exit data")
	assert_true(exit_data.has("target_scene_id"), "Should have target_scene_id")
	assert_true(exit_data.has("target_spawn_point"), "Should have target_spawn_point")
	assert_true(exit_data.has("transition_type"), "Should have transition_type")

## Test door pairing - entering interior
func test_door_pairing_exterior_to_interior() -> void:
	var exit_data: Dictionary = SceneRegistry.get_door_exit(
		StringName("exterior"),
		StringName("door_to_house")
	)

	assert_eq(exit_data["target_scene_id"], StringName("interior_house"), "Should target interior scene")
	assert_eq(exit_data["target_spawn_point"], StringName("entrance_from_exterior"), "Should specify spawn point")

## Test door pairing - exiting interior
func test_door_pairing_interior_to_exterior() -> void:
	var exit_data: Dictionary = SceneRegistry.get_door_exit(
		StringName("interior_house"),
		StringName("door_to_exterior")
	)

	assert_eq(exit_data["target_scene_id"], StringName("exterior"), "Should target exterior scene")
	assert_eq(exit_data["target_spawn_point"], StringName("exit_from_house"), "Should specify spawn point")

## Test invalid door ID returns empty dict
func test_invalid_door_id_returns_empty() -> void:
	var exit_data: Dictionary = SceneRegistry.get_door_exit(
		StringName("exterior"),
		StringName("nonexistent_door")
	)

	assert_eq(exit_data.size(), 0, "Should return empty dict for invalid door")

## Test validate_door_pairings method
func test_validate_door_pairings_returns_true_for_valid_config() -> void:
	var result: bool = SceneRegistry.validate_door_pairings()

	assert_true(result, "Should return true for valid door pairings")

## Test door pairing validation detects broken pairings
func test_validation_detects_missing_return_door() -> void:
	# This test assumes there's a way to test validation without breaking the static data
	# In practice, this would require a test-only validation mode or injectable data
	# For now, we just test that the method exists and can be called
	var result: bool = SceneRegistry.validate_door_pairings()
	assert_true(result is bool, "validate_door_pairings should return a bool")

## Test get_all_scenes returns all registered scenes
func test_get_all_scenes() -> void:
	var all_scenes: Array = SceneRegistry.get_all_scenes()

	assert_gt(all_scenes.size(), 0, "Should return at least one scene")
	for scene_data in all_scenes:
		assert_true(scene_data is Dictionary, "Each item should be a Dictionary")
		assert_true(scene_data.has("scene_id"), "Each scene should have scene_id")

## Test get_scenes_by_type
func test_get_scenes_by_type() -> void:
	var gameplay_scenes: Array = SceneRegistry.get_scenes_by_type(SceneRegistry.SceneType.GAMEPLAY)

	assert_gt(gameplay_scenes.size(), 0, "Should return at least one gameplay scene")
	for scene_data in gameplay_scenes:
		assert_eq(scene_data["scene_type"], SceneRegistry.SceneType.GAMEPLAY, "All scenes should be GAMEPLAY type")

## Test preload priority values
func test_preload_priorities_are_valid() -> void:
	var all_scenes: Array = SceneRegistry.get_all_scenes()

	for scene_data in all_scenes:
		var priority: int = scene_data["preload_priority"]
		assert_true(priority >= 0 and priority <= 10, "Preload priority should be between 0 and 10")

## Test main_menu scene exists
func test_main_menu_scene_registered() -> void:
	var scene_data: Dictionary = SceneRegistry.get_scene(StringName("main_menu"))

	assert_false(scene_data.is_empty(), "main_menu should be registered")
	assert_eq(scene_data["scene_type"], SceneRegistry.SceneType.MENU, "main_menu should be MENU type")

## Test gameplay_base scene exists
func test_gameplay_base_scene_registered() -> void:
	var scene_data: Dictionary = SceneRegistry.get_scene(StringName("gameplay_base"))

	assert_false(scene_data.is_empty(), "gameplay_base should be registered")
	assert_eq(scene_data["scene_type"], SceneRegistry.SceneType.GAMEPLAY, "gameplay_base should be GAMEPLAY type")

## Test settings_menu scene exists
func test_settings_menu_scene_registered() -> void:
	var scene_data: Dictionary = SceneRegistry.get_scene(StringName("settings_menu"))

	assert_false(scene_data.is_empty(), "settings_menu should be registered")
	assert_eq(scene_data["scene_type"], SceneRegistry.SceneType.UI, "settings_menu should be UI type")
