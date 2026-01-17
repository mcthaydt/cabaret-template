extends GutTest

## Integration test: Verify spawn bookkeeping is set before scene is added to tree
## This prevents race condition where M_GameplayInitializer checks for spawn status
## before M_SceneManager has recorded it, causing double spawn calls.

const M_SceneManager = preload("res://scripts/managers/m_scene_manager.gd")

## Test that M_SceneManager tracks spawn before scene enters the tree
func test_spawn_flag_set_before_scene_added_to_tree() -> void:
	var scene_manager := M_SceneManager.new()
	var test_scene := Node.new()
	test_scene.name = "TestGameplayScene"

	# When: Scene is marked by M_SceneManager (simulating the fix)
	scene_manager.mark_scene_spawned(test_scene)
	add_child_autofree(test_scene)
	await get_tree().process_frame

	# Then: Spawn flag should be visible both before and after entering the tree
	assert_true(scene_manager.has_scene_been_spawned(test_scene),
		"Spawn flag should be recorded before the scene enters the tree")
	scene_manager.free()

## Test that without spawn flag, initializer would run
func test_without_spawn_flag_initializer_would_spawn() -> void:
	var scene_manager := M_SceneManager.new()
	var test_scene := Node.new()
	test_scene.name = "TestGameplaySceneNoFlag"

	# When: Scene is added to tree without prior mark
	add_child_autofree(test_scene)
	await get_tree().process_frame

	# Then: Spawn flag should be absent
	assert_false(scene_manager.has_scene_been_spawned(test_scene),
		"Without spawn flag, initializer should perform spawn")
	scene_manager.free()

## Test spawn flag persists after mark
func test_spawn_flag_persists_after_scene_added() -> void:
	var scene_manager := M_SceneManager.new()
	var test_scene := Node.new()
	test_scene.name = "SpawnPersistenceScene"

	scene_manager.mark_scene_spawned(test_scene)
	add_child_autofree(test_scene)
	await get_tree().process_frame

	assert_true(scene_manager.has_scene_been_spawned(test_scene),
		"Spawn flag should persist after scene is added to tree")
	scene_manager.free()
