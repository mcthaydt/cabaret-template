extends GutTest

const M_VFX_MANAGER := preload("res://scripts/core/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_VCAM_ACTIONS := preload("res://scripts/core/state/actions/u_vcam_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

func test_silhouette_event_sets_transparency_on_occluders() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var store := manager.state_store as MockStateStore
	var target := _create_mesh_target()

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	assert_almost_eq(target.transparency, 0.0, 0.001,
		"First detection frame should not apply silhouette due debounce")

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)

	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001,
		"VFX manager should set transparency on occluder from action payload")

func test_silhouette_disable_restores_transparency() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var store := manager.state_store as MockStateStore
	var target := _create_mesh_target()
	var original_transparency: float = target.transparency

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [], false))
	manager._physics_process(0.0)

	assert_almost_eq(target.transparency, original_transparency, 0.001,
		"Disable request should restore original transparency")

func test_silhouette_preserves_material_override() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var store := manager.state_store as MockStateStore
	var target := _create_mesh_target()
	var original_material := StandardMaterial3D.new()
	target.material_override = original_material

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)

	assert_eq(target.material_override, original_material,
		"Occluder material_override should stay untouched")

func test_silhouette_event_respects_player_gating() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var store := manager.state_store as MockStateStore
	var target := _create_mesh_target()

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("enemy"), [target], true))
	manager._physics_process(0.0)

	assert_almost_eq(target.transparency, 0.0, 0.001,
		"Non-player silhouette request should be ignored")

func test_silhouette_event_respects_transition_blocking() -> void:
	var manager := await _create_manager_with_state(StringName("player"), true, [], StringName("gameplay"))
	var store := manager.state_store as MockStateStore
	var target := _create_mesh_target()

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)

	assert_almost_eq(target.transparency, 0.0, 0.001,
		"Transition-blocked silhouette request should be ignored")

func test_silhouette_clear_request_bypasses_transition_blocking() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var store := manager.state_store as MockStateStore
	var target := _create_mesh_target()

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)

	store.set_slice(StringName("scene"), {
		"is_transitioning": true,
		"scene_stack": [],
	})
	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [], false))
	manager._physics_process(0.0)
	assert_almost_eq(target.transparency, 0.0, 0.001,
		"Explicit clear should process even while transition-blocked")

func test_silhouette_clear_request_still_respects_player_gating() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var store := manager.state_store as MockStateStore
	var target := _create_mesh_target()

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("enemy"), [], false))
	manager._physics_process(0.0)
	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001,
		"Non-player clear request should be ignored")

func test_silhouette_count_dispatches_from_applied_overrides() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var store := manager.state_store as MockStateStore
	var target := _create_mesh_target()
	store.clear_dispatched_actions()

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	assert_true(
		_find_last_action_by_type(
			store.get_dispatched_actions(),
			U_VCAM_ACTIONS.ACTION_UPDATE_SILHOUETTE_COUNT
		).is_empty(),
		"First detection frame should not dispatch active silhouette count"
	)

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	var activate_action := _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_UPDATE_SILHOUETTE_COUNT
	)
	assert_false(activate_action.is_empty(), "Second frame should dispatch active silhouette count")
	var activate_payload := activate_action.get("payload", {}) as Dictionary
	assert_eq(int(activate_payload.get("count", -1)), 1)

	store.clear_dispatched_actions()
	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [target], true))
	manager._physics_process(0.0)
	assert_true(
		_find_last_action_by_type(
			store.get_dispatched_actions(),
			U_VCAM_ACTIONS.ACTION_UPDATE_SILHOUETTE_COUNT
		).is_empty(),
		"Unchanged active silhouette count should not dispatch"
	)

	store.dispatch(U_VCAM_ACTIONS.silhouette_update_request(StringName("player"), [], false))
	manager._physics_process(0.0)
	var clear_action := _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_UPDATE_SILHOUETTE_COUNT
	)
	assert_false(clear_action.is_empty(), "Clear should dispatch zero active silhouettes")
	var clear_payload := clear_action.get("payload", {}) as Dictionary
	assert_eq(int(clear_payload.get("count", -1)), 0)

func _create_mesh_target() -> MeshInstance3D:
	var target := MeshInstance3D.new()
	target.mesh = BoxMesh.new()
	add_child_autofree(target)
	return target

func _create_manager_with_state(
	player_entity_id: StringName,
	is_transitioning: bool,
	scene_stack: Array,
	shell: StringName
) -> M_VFXManager:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {
		"player_entity_id": String(player_entity_id),
	})
	store.set_slice(StringName("scene"), {
		"is_transitioning": is_transitioning,
		"scene_stack": scene_stack.duplicate(true),
	})
	store.set_slice(StringName("navigation"), {
		"shell": shell,
	})
	add_child_autofree(store)

	var manager := M_VFX_MANAGER.new()
	manager.state_store = store
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager

func _find_last_action_by_type(actions: Array[Dictionary], action_type: StringName) -> Dictionary:
	for i in range(actions.size() - 1, -1, -1):
		var action: Dictionary = actions[i]
		if action.get("type", StringName("")) == action_type:
			return action
	return {}
