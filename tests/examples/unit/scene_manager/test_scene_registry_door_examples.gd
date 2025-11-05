extends GutTest

## Example tests for door pairings (exterior ↔ interior)

const U_SceneRegistry = preload("res://scripts/scene_management/u_scene_registry.gd")

func test_example_get_door_exit_metadata() -> void:
	var exit_data: Dictionary = U_SceneRegistry.get_door_exit(
		StringName("exterior"),
		StringName("door_to_house")
	)
	assert_not_null(exit_data)
	assert_true(exit_data.has("target_scene_id"))
	assert_true(exit_data.has("target_spawn_point"))
	assert_true(exit_data.has("transition_type"))

func test_example_exterior_to_interior() -> void:
	var exit_data: Dictionary = U_SceneRegistry.get_door_exit(
		StringName("exterior"),
		StringName("door_to_house")
	)
	assert_eq(exit_data["target_scene_id"], StringName("interior_house"))
	assert_eq(exit_data["target_spawn_point"], StringName("sp_entrance_from_exterior"))

func test_example_interior_to_exterior() -> void:
	var exit_data: Dictionary = U_SceneRegistry.get_door_exit(
		StringName("interior_house"),
		StringName("door_to_exterior")
	)
	assert_eq(exit_data["target_scene_id"], StringName("exterior"))
	assert_eq(exit_data["target_spawn_point"], StringName("sp_exit_from_house"))

func test_example_invalid_door_returns_empty() -> void:
	var exit_data: Dictionary = U_SceneRegistry.get_door_exit(
		StringName("exterior"),
		StringName("nonexistent_door")
	)
	assert_eq(exit_data.size(), 0)

