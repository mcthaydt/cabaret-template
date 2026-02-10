extends GutTest

## Unit tests for Scene Contract Validation (Phase 12.5 - T300)
##
## Tests validation system that catches scene configuration errors at load time.
## Validates gameplay scenes have required nodes (player, camera, spawns).


var validator: I_SCENE_CONTRACT

func before_each() -> void:
	validator = I_SCENE_CONTRACT.new()

func after_each() -> void:
	validator = null

## T300: Test validator can validate gameplay scenes
func test_validator_has_validate_scene_method() -> void:
	assert_has_method(validator, "validate_scene", "Should have validate_scene method")

## T301: Test gameplay scene validation - valid scene passes
func test_valid_gameplay_scene_passes_validation() -> void:
	# Create a valid gameplay scene
	var scene := Node3D.new()
	scene.name = "TestGameplayScene"
	add_child_autofree(scene)

	# Add required player entity
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	scene.add_child(player)

	# Add required camera
	var camera := Camera3D.new()
	scene.add_child(camera)

	# Add required sp_default spawn point
	var spawn_default := Node3D.new()
	spawn_default.name = "sp_default"
	scene.add_child(spawn_default)

	# Validate
	var result: Dictionary = validator.validate_scene(scene, I_SCENE_CONTRACT.SceneType.GAMEPLAY)

	# Assert
	assert_true(result.get("valid", false), "Valid gameplay scene should pass validation")
	assert_eq(result.get("errors", []).size(), 0, "Should have no errors")

## T301: Test gameplay scene validation - missing player fails
func test_gameplay_scene_missing_player_fails() -> void:
	var scene := Node3D.new()
	add_child_autofree(scene)

	# Add camera and spawn but NO player
	var camera := Camera3D.new()
	scene.add_child(camera)

	var spawn := Node3D.new()
	spawn.name = "sp_default"
	scene.add_child(spawn)

	# Validate
	var result: Dictionary = validator.validate_scene(scene, I_SCENE_CONTRACT.SceneType.GAMEPLAY)

	# Assert
	assert_false(result.get("valid", true), "Missing player should fail validation")
	assert_gt(result.get("errors", []).size(), 0, "Should have error about missing player")

## T301: Test gameplay scene validation - missing camera fails
func test_gameplay_scene_missing_camera_fails() -> void:
	var scene := Node3D.new()
	add_child_autofree(scene)

	# Add player and spawn but NO camera
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	scene.add_child(player)

	var spawn := Node3D.new()
	spawn.name = "sp_default"
	scene.add_child(spawn)

	# Validate
	var result: Dictionary = validator.validate_scene(scene, I_SCENE_CONTRACT.SceneType.GAMEPLAY)

	# Assert
	assert_false(result.get("valid", true), "Missing camera should fail validation")
	assert_gt(result.get("errors", []).size(), 0, "Should have error about missing camera")

## T301: Test gameplay scene validation - missing sp_default fails
func test_gameplay_scene_missing_sp_default_fails() -> void:
	var scene := Node3D.new()
	add_child_autofree(scene)

	# Add player and camera but NO sp_default
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	scene.add_child(player)

	var camera := Camera3D.new()
	scene.add_child(camera)

	# Validate
	var result: Dictionary = validator.validate_scene(scene, I_SCENE_CONTRACT.SceneType.GAMEPLAY)

	# Assert
	assert_false(result.get("valid", true), "Missing sp_default should fail validation")
	assert_gt(result.get("errors", []).size(), 0, "Should have error about missing sp_default")

## T302: Test UI scene validation - UI scene shouldn't have player
func test_ui_scene_with_player_fails() -> void:
	var scene := CanvasLayer.new()
	add_child_autofree(scene)

	# UI scene should NOT have player
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	scene.add_child(player)

	# Validate
	var result: Dictionary = validator.validate_scene(scene, I_SCENE_CONTRACT.SceneType.UI)

	# Assert
	assert_false(result.get("valid", true), "UI scene with player should fail validation")
	assert_gt(result.get("errors", []).size(), 0, "Should have error about player in UI scene")

## T302: Test UI scene validation - valid UI scene passes
func test_valid_ui_scene_passes() -> void:
	var scene := CanvasLayer.new()
	add_child_autofree(scene)

	# Add some UI elements (no player, no spawns)
	var label := Label.new()
	scene.add_child(label)

	# Validate
	var result: Dictionary = validator.validate_scene(scene, I_SCENE_CONTRACT.SceneType.UI)

	# Assert
	assert_true(result.get("valid", false), "Valid UI scene should pass validation")

## T302: Test validator provides multiple errors for multiple issues
func test_validator_provides_all_errors_at_once() -> void:
	var scene := Node3D.new()
	add_child_autofree(scene)

	# Scene with NO player, NO camera, NO spawns (multiple errors)

	# Validate
	var result: Dictionary = validator.validate_scene(scene, I_SCENE_CONTRACT.SceneType.GAMEPLAY)

	# Assert
	assert_false(result.get("valid", true), "Invalid scene should fail")
	assert_gte(result.get("errors", []).size(), 3, "Should report all 3 missing requirements")
