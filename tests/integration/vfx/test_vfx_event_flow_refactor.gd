extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const SCREEN_SHAKE_PUBLISHER := preload("res://scripts/ecs/systems/s_screen_shake_publisher_system.gd")
const DAMAGE_FLASH_PUBLISHER := preload("res://scripts/ecs/systems/s_damage_flash_publisher_system.gd")
const VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")

const ENTITY_ID := StringName("player")

var _store: M_StateStore
var _vfx_manager: M_VFXManager


func before_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = STATE_STORE.new()
	_store.settings = RS_STATE_STORE_SETTINGS.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_debug_logging = false
	_store.settings.enable_debug_overlay = false
	var gameplay_initial := RS_GAMEPLAY_INITIAL_STATE.new()
	gameplay_initial.player_entity_id = String(ENTITY_ID)
	_store.gameplay_initial_state = gameplay_initial
	var navigation_initial := RS_NAVIGATION_INITIAL_STATE.new()
	navigation_initial.shell = StringName("gameplay")
	_store.navigation_initial_state = navigation_initial
	_store.vfx_initial_state = RS_VFX_INITIAL_STATE.new()
	add_child(_store)
	autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)
	await get_tree().process_frame

	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var shake_publisher := SCREEN_SHAKE_PUBLISHER.new()
	manager.add_child(shake_publisher)
	autofree(shake_publisher)

	var flash_publisher := DAMAGE_FLASH_PUBLISHER.new()
	manager.add_child(flash_publisher)
	autofree(flash_publisher)

	_vfx_manager = VFX_MANAGER.new()
	add_child(_vfx_manager)
	autofree(_vfx_manager)
	await get_tree().process_frame


func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_STATE_HANDOFF.clear_all()
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


func test_health_changed_triggers_both_shake_and_flash() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	U_ECS_EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 100.0,
		"new_health": 50.0,
		"is_dead": false,
	})

	_process_vfx()

	assert_true(_vfx_manager.get_trauma() > 0.0, "Health change should add trauma")
	assert_true(flash_rect.modulate.a > 0.0, "Health change should trigger flash")


func test_landing_triggers_shake_only() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	U_ECS_EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_LANDED, {
		"entity_id": ENTITY_ID,
		"vertical_velocity": -20.0,
	})

	_process_vfx()

	assert_true(_vfx_manager.get_trauma() > 0.0, "Landing should add trauma")
	assert_almost_eq(flash_rect.modulate.a, 0.0, 0.0001, "Landing should not trigger flash")


func test_death_triggers_both_effects() -> void:
	var flash_rect := _get_flash_rect()
	assert_not_null(flash_rect, "FlashRect should exist")

	U_ECS_EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_DEATH, {
		"entity_id": ENTITY_ID,
	})

	_process_vfx()

	assert_almost_eq(_vfx_manager.get_trauma(), 0.5, 0.001, "Death should add fixed trauma")
	assert_true(flash_rect.modulate.a > 0.0, "Death should trigger flash")


func test_event_flow_preserves_trauma_amounts() -> void:
	U_ECS_EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 100.0,
		"new_health": 50.0,
		"is_dead": false,
	})

	_process_vfx()

	assert_almost_eq(_vfx_manager.get_trauma(), 0.45, 0.001, "Trauma amount should be preserved")
