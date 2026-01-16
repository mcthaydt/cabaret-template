extends GutTest

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func test_returns_true_for_player_entity_id() -> void:
	var manager := await _create_manager_with_player_id(StringName("player"))

	var result: bool = manager._is_player_entity(StringName("player"))
	assert_true(result, "Should return true for matching player entity_id")

func test_returns_false_for_non_player_entity_id() -> void:
	var manager := await _create_manager_with_player_id(StringName("player"))

	var result: bool = manager._is_player_entity(StringName("enemy"))
	assert_false(result, "Should return false for non-player entity_id")

func test_returns_false_when_player_entity_id_empty() -> void:
	var manager := await _create_manager_with_player_id(StringName(""))

	var result: bool = manager._is_player_entity(StringName("player"))
	assert_false(result, "Should return false when player_entity_id is empty")

func test_returns_false_when_no_state_store() -> void:
	var manager := M_VFX_MANAGER.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	var result: bool = manager._is_player_entity(StringName("player"))
	assert_false(result, "Should return false when no state store is available")

func _create_manager_with_player_id(player_id: StringName) -> M_VFXManager:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {
		"player_entity_id": String(player_id)
	})
	store.set_slice(StringName("navigation"), {
		"shell": StringName("gameplay")
	})
	store.set_slice(StringName("scene"), {
		"is_transitioning": false,
		"scene_stack": []
	})
	add_child_autofree(store)

	var manager := M_VFX_MANAGER.new()
	manager.state_store = store
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager
