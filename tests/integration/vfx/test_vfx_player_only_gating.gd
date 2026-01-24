extends BaseTest

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")

const PLAYER_ID := StringName("player")
const ENEMY_ID := StringName("enemy")

var _store: MockStateStore
var _vfx_manager: M_VFXManager

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()
	await get_tree().process_frame

	_store = MOCK_STATE_STORE.new()
	_store.set_slice(StringName("gameplay"), {
		"player_entity_id": String(PLAYER_ID)
	})
	_store.set_slice(StringName("navigation"), {
		"shell": StringName("gameplay")
	})
	_store.set_slice(StringName("scene"), {
		"is_transitioning": false,
		"scene_stack": []
	})
	add_child(_store)
	autofree(_store)

	_vfx_manager = M_VFX_MANAGER.new()
	_vfx_manager.state_store = _store
	add_child(_vfx_manager)
	autofree(_vfx_manager)
	await get_tree().process_frame

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	super.after_each()

func _process_vfx() -> void:
	_vfx_manager._physics_process(0.0)

func _get_flash_rect() -> ColorRect:
	if _vfx_manager == null:
		return null
	var overlay := _vfx_manager.get_node_or_null("DamageFlashOverlay") as CanvasLayer
	if overlay == null:
		return null
	return overlay.get_node_or_null("FlashRect") as ColorRect

func test_enemy_shake_is_ignored() -> void:
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SCREEN_SHAKE_REQUEST, {
		"entity_id": ENEMY_ID,
		"trauma_amount": 0.4,
		"source": "damage",
	})

	_process_vfx()

	assert_almost_eq(_vfx_manager.get_trauma(), 0.0, 0.0001, "Enemy shake should be ignored")

func test_player_shake_is_applied() -> void:
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SCREEN_SHAKE_REQUEST, {
		"entity_id": PLAYER_ID,
		"trauma_amount": 0.4,
		"source": "damage",
	})

	_process_vfx()

	assert_true(_vfx_manager.get_trauma() > 0.0, "Player shake should be applied")

func test_enemy_flash_is_ignored() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_DAMAGE_FLASH_REQUEST, {
		"entity_id": ENEMY_ID,
		"intensity": 1.0,
		"source": "damage",
	})

	_process_vfx()

	assert_almost_eq(flash_rect.modulate.a, 0.0, 0.0001, "Enemy flash should be ignored")

func test_player_flash_is_applied() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_DAMAGE_FLASH_REQUEST, {
		"entity_id": PLAYER_ID,
		"intensity": 1.0,
		"source": "damage",
	})

	_process_vfx()

	assert_true(flash_rect.modulate.a > 0.0, "Player flash should be applied")
