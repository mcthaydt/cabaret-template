extends GutTest

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func test_blocked_when_is_transitioning_true() -> void:
	var manager := await _create_manager_with_state({
		"is_transitioning": true,
		"scene_stack": []
	}, {
		"shell": StringName("gameplay")
	})

	assert_true(manager._is_transition_blocked(), "Should block when is_transitioning is true")

func test_blocked_when_scene_stack_not_empty() -> void:
	var manager := await _create_manager_with_state({
		"is_transitioning": false,
		"scene_stack": [StringName("pause_menu")]
	}, {
		"shell": StringName("gameplay")
	})

	assert_true(manager._is_transition_blocked(), "Should block when scene_stack has overlays")

func test_blocked_when_shell_not_gameplay() -> void:
	var manager := await _create_manager_with_state({
		"is_transitioning": false,
		"scene_stack": []
	}, {
		"shell": StringName("main_menu")
	})

	assert_true(manager._is_transition_blocked(), "Should block when shell is not gameplay")

func test_allowed_in_normal_gameplay() -> void:
	var manager := await _create_manager_with_state({
		"is_transitioning": false,
		"scene_stack": []
	}, {
		"shell": StringName("gameplay")
	})

	assert_false(manager._is_transition_blocked(), "Should allow VFX in normal gameplay")

func test_allowed_when_no_state_store() -> void:
	var manager := M_VFX_MANAGER.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	assert_false(manager._is_transition_blocked(), "Should allow VFX when no state store is available")

func _create_manager_with_state(scene_slice: Dictionary, nav_slice: Dictionary) -> M_VFXManager:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("scene"), scene_slice)
	store.set_slice(StringName("navigation"), nav_slice)
	add_child_autofree(store)

	var manager := M_VFX_MANAGER.new()
	manager.state_store = store
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager
