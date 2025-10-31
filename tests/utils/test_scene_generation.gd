extends GutTest

## Test to generate area transition scenes programmatically
##
## This test runs U_SceneBuilder to create exterior.tscn and interior_house.tscn.
## Run this test once to generate the scenes for Phase 6 (Area Transitions).

const U_SCENE_BUILDER := preload("res://scripts/utils/u_scene_builder.gd")

func test_generate_exterior_scene() -> void:
	# Given: Scene builder utility
	# When: Generate exterior scene
	var success: bool = U_SCENE_BUILDER.create_area_scene(
		"exterior",
		StringName("door_to_house"),
		StringName("interior_house"),
		StringName("entrance_from_exterior"),
		StringName("exit_from_house"),
		"res://scenes/gameplay/exterior.tscn"
	)

	# Then: Scene should be created successfully
	assert_true(success, "exterior.tscn should be created successfully")

	# Verify file exists
	assert_true(FileAccess.file_exists("res://scenes/gameplay/exterior.tscn"),
		"exterior.tscn file should exist after generation")

func test_generate_interior_house_scene() -> void:
	# Given: Scene builder utility
	# When: Generate interior_house scene
	var success: bool = U_SCENE_BUILDER.create_area_scene(
		"interior_house",
		StringName("door_to_exterior"),
		StringName("exterior"),
		StringName("exit_from_house"),
		StringName("entrance_from_exterior"),
		"res://scenes/gameplay/interior_house.tscn"
	)

	# Then: Scene should be created successfully
	assert_true(success, "interior_house.tscn should be created successfully")

	# Verify file exists
	assert_true(FileAccess.file_exists("res://scenes/gameplay/interior_house.tscn"),
		"interior_house.tscn file should exist after generation")

func test_exterior_scene_loads() -> void:
	# Given: Generated exterior scene
	# When: Load the scene
	var scene: PackedScene = load("res://scenes/gameplay/exterior.tscn")

	# Then: Scene should load successfully
	assert_not_null(scene, "exterior.tscn should load")

	# Instantiate to verify structure
	var instance := scene.instantiate()
	assert_not_null(instance, "exterior scene should instantiate")

	# Verify has expected children
	assert_not_null(instance.get_node_or_null("Entities"), "Should have Entities node")
	assert_not_null(instance.get_node_or_null("Managers/M_ECSManager"), "Should have M_ECSManager")

	instance.queue_free()

func test_interior_house_scene_loads() -> void:
	# Given: Generated interior_house scene
	# When: Load the scene
	var scene: PackedScene = load("res://scenes/gameplay/interior_house.tscn")

	# Then: Scene should load successfully
	assert_not_null(scene, "interior_house.tscn should load")

	# Instantiate to verify structure
	var instance := scene.instantiate()
	assert_not_null(instance, "interior_house scene should instantiate")

	# Verify has expected children
	assert_not_null(instance.get_node_or_null("Entities"), "Should have Entities node")
	assert_not_null(instance.get_node_or_null("Managers/M_ECSManager"), "Should have M_ECSManager")

	instance.queue_free()
