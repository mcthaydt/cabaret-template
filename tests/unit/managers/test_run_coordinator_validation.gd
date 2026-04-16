extends GutTest

## Tests for cross-reference boot validation in M_RunCoordinatorManager (F15 Commit 5).
##
## Validates that game_config references (retry_scene_id, default_objective_set_id)
## are checked against live registries at boot time.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const I_OBJECTIVES_MANAGER := preload("res://scripts/interfaces/i_objectives_manager.gd")

class ObjectivesStub extends I_OBJECTIVES_MANAGER:
	var _known_sets: Dictionary = {StringName("default_progression"): true}

	func reset_for_new_run(_set_id: StringName = StringName("default_progression")) -> bool:
		return true

	func has_objective_set(set_id: StringName) -> bool:
		return _known_sets.has(set_id)


func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()


func test_invalid_retry_scene_id_pushes_error() -> void:
	var coordinator := M_RunCoordinatorManager.new()
	coordinator.game_config = RS_GameConfig.new()
	coordinator.game_config.retry_scene_id = StringName("nonexistent_scene_xyz")
	autofree(coordinator.game_config)
	add_child_autofree(coordinator)
	await wait_process_frames(2)
	coordinator.queue_free()
	assert_push_error("not found in U_SceneRegistry")


func test_invalid_objective_set_id_pushes_error() -> void:
	var objectives_stub := ObjectivesStub.new()
	autofree(objectives_stub)
	U_SERVICE_LOCATOR.register(StringName("objectives_manager"), objectives_stub)

	var coordinator := M_RunCoordinatorManager.new()
	coordinator.game_config = RS_GameConfig.new()
	coordinator.game_config.default_objective_set_id = StringName("nonexistent_objective_set_xyz")
	autofree(coordinator.game_config)
	add_child_autofree(coordinator)
	await wait_process_frames(2)
	coordinator.queue_free()
	assert_push_error("not found in objectives registry")


func test_valid_config_no_error() -> void:
	var objectives_stub := ObjectivesStub.new()
	autofree(objectives_stub)
	U_SERVICE_LOCATOR.register(StringName("objectives_manager"), objectives_stub)

	var coordinator := M_RunCoordinatorManager.new()
	coordinator.game_config = RS_GameConfig.new()
	# Default retry_scene_id is "power_core" which should exist in the scene registry.
	# Default default_objective_set_id is "default_progression" which the stub knows.
	add_child_autofree(coordinator)
	await wait_process_frames(2)
	# No assert_push_error — valid config should not push errors for cross-references.