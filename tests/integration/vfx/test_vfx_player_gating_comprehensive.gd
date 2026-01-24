extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const SCREEN_SHAKE_PUBLISHER := preload("res://scripts/ecs/systems/s_screen_shake_publisher_system.gd")
const DAMAGE_FLASH_PUBLISHER := preload("res://scripts/ecs/systems/s_damage_flash_publisher_system.gd")
const VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")

const PLAYER_ID := StringName("player")
const ENEMY_ID := StringName("enemy")

var _store: MockStateStore
var _ecs_manager: M_ECSManager
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

	_ecs_manager = ECS_MANAGER.new()
	add_child(_ecs_manager)
	autofree(_ecs_manager)
	await get_tree().process_frame

	var shake_publisher := SCREEN_SHAKE_PUBLISHER.new()
	_ecs_manager.add_child(shake_publisher)
	autofree(shake_publisher)

	var flash_publisher := DAMAGE_FLASH_PUBLISHER.new()
	_ecs_manager.add_child(flash_publisher)
	autofree(flash_publisher)
	await get_tree().process_frame

	_vfx_manager = VFX_MANAGER.new()
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


func _publish_health_changed(entity_id: StringName, previous_health: float, new_health: float) -> void:
	U_ECS_EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": entity_id,
		"previous_health": previous_health,
		"new_health": new_health,
		"is_dead": false,
	})


func _publish_death(entity_id: StringName) -> void:
	U_ECS_EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_DEATH, {
		"entity_id": entity_id,
	})


func _publish_landed(entity_id: StringName, vertical_velocity: float) -> void:
	U_ECS_EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_LANDED, {
		"entity_id": entity_id,
		"vertical_velocity": vertical_velocity,
	})


func _assert_no_vfx(flash_rect: ColorRect, context: String) -> void:
	assert_almost_eq(_vfx_manager.get_trauma(), 0.0, 0.0001,
		"%s should not add trauma" % context)
	assert_almost_eq(flash_rect.modulate.a, 0.0, 0.0001,
		"%s should not trigger damage flash" % context)


func test_enemy_damage_is_blocked() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	_publish_health_changed(ENEMY_ID, 100.0, 50.0)
	_process_vfx()

	_assert_no_vfx(flash_rect, "Enemy damage")


func test_player_damage_is_allowed() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	_publish_health_changed(PLAYER_ID, 100.0, 50.0)
	_process_vfx()

	assert_true(_vfx_manager.get_trauma() > 0.0, "Player damage should add trauma")
	assert_true(flash_rect.modulate.a > 0.0, "Player damage should trigger flash")


func test_enemy_death_is_blocked() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	_publish_death(ENEMY_ID)
	_process_vfx()

	_assert_no_vfx(flash_rect, "Enemy death")


func test_player_death_is_allowed() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	_publish_death(PLAYER_ID)
	_process_vfx()

	assert_true(_vfx_manager.get_trauma() > 0.0, "Player death should add trauma")
	assert_true(flash_rect.modulate.a > 0.0, "Player death should trigger flash")


func test_enemy_landing_is_blocked() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	_publish_landed(ENEMY_ID, -20.0)
	_process_vfx()

	assert_almost_eq(_vfx_manager.get_trauma(), 0.0, 0.0001, "Enemy landing should not add trauma")
	assert_almost_eq(flash_rect.modulate.a, 0.0, 0.0001, "Enemy landing should not trigger flash")


func test_player_landing_is_allowed() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	_publish_landed(PLAYER_ID, -20.0)
	_process_vfx()

	assert_true(_vfx_manager.get_trauma() > 0.0, "Player landing should add trauma")
	assert_almost_eq(flash_rect.modulate.a, 0.0, 0.0001, "Player landing should not trigger flash")
