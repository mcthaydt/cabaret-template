extends GutTest

const U_TransitionState = preload("res://scripts/scene_management/helpers/u_transition_state.gd")


func test_defaults() -> void:
	var state := U_TransitionState.new()
	assert_eq(state.progress, 0.0, "progress should default to 0.0")
	assert_false(state.scene_swap_complete, "scene_swap_complete should default to false")
	assert_eq(state.new_scene_ref, null, "new_scene_ref should default to null")
	assert_eq(state.old_camera_state, null, "old_camera_state should default to null")
	assert_false(state.should_blend, "should_blend should default to false")


func test_mutation_and_reset() -> void:
	var state := U_TransitionState.new()
	var scene := Node3D.new()
	add_child_autofree(scene)

	state.progress = 0.75
	state.scene_swap_complete = true
	state.new_scene_ref = scene
	state.old_camera_state = {"from": "test"}
	state.should_blend = true

	assert_eq(state.progress, 0.75, "progress should store assigned value")
	assert_true(state.scene_swap_complete, "scene_swap_complete should store assigned value")
	assert_eq(state.new_scene_ref, scene, "new_scene_ref should store assigned node")
	assert_eq(state.old_camera_state, {"from": "test"}, "old_camera_state should store assigned value")
	assert_true(state.should_blend, "should_blend should store assigned value")

	state.reset()
	assert_eq(state.progress, 0.0, "reset should clear progress")
	assert_false(state.scene_swap_complete, "reset should clear scene_swap_complete")
	assert_eq(state.new_scene_ref, null, "reset should clear new_scene_ref")
	assert_eq(state.old_camera_state, null, "reset should clear old_camera_state")
	assert_false(state.should_blend, "reset should clear should_blend")
