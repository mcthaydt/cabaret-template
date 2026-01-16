extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const DAMAGE_FLASH_PUBLISHER := preload("res://scripts/ecs/systems/s_damage_flash_publisher_system.gd")
const EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const EVENT_NAMES := preload("res://scripts/ecs/u_ecs_event_names.gd")

const ENTITY_ID := StringName("player")


func before_each() -> void:
	EVENT_BUS.reset()


func _spawn_system():
	var manager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var system = DAMAGE_FLASH_PUBLISHER.new()
	manager.add_child(system)
	autofree(system)
	await get_tree().process_frame
	return system


func _capture_requests() -> Array:
	var captured: Array = []
	EVENT_BUS.subscribe(EVENT_NAMES.EVENT_DAMAGE_FLASH_REQUEST, func(event_data: Dictionary) -> void:
		captured.append(event_data)
	)
	return captured


func test_subscribes_to_health_changed_on_ready() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 100.0,
		"new_health": 90.0,
		"is_dead": false,
	})

	assert_eq(captured.size(), 1, "Should publish request when health changes")


func test_subscribes_to_entity_death_on_ready() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_DEATH, {
		"entity_id": ENTITY_ID,
	})

	assert_eq(captured.size(), 1, "Should publish request on death event")


func test_health_changed_publishes_damage_flash_request() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 100.0,
		"new_health": 50.0,
		"is_dead": false,
	})

	assert_eq(captured.size(), 1, "Health changed should publish one request")
	var payload: Dictionary = captured[0].get("payload", {})
	assert_eq(payload.get("entity_id"), ENTITY_ID)
	assert_eq(payload.get("source"), StringName("damage"))


func test_ignores_healing() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 50.0,
		"new_health": 75.0,
		"is_dead": false,
	})

	assert_eq(captured.size(), 0, "Healing should not publish request")


func test_ignores_damage_when_dead() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 10.0,
		"new_health": 0.0,
		"is_dead": true,
	})

	assert_eq(captured.size(), 0, "Damage when dead should not publish request")


func test_death_publishes_damage_flash_request() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_DEATH, {
		"entity_id": ENTITY_ID,
	})

	assert_eq(captured.size(), 1, "Death should publish flash request")
	var payload: Dictionary = captured[0].get("payload", {})
	assert_eq(payload.get("source"), StringName("death"))


func test_intensity_fixed_at_1_0_for_now() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 100.0,
		"new_health": 75.0,
		"is_dead": false,
	})

	var payload: Dictionary = captured[0].get("payload", {})
	var intensity: float = float(payload.get("intensity", 0.0))
	assert_almost_eq(intensity, 1.0, 0.001, "Intensity should be fixed at 1.0")


func test_unsubscribes_on_exit_tree() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var system := DAMAGE_FLASH_PUBLISHER.new()
	manager.add_child(system)
	await get_tree().process_frame

	var captured := _capture_requests()
	manager.remove_child(system)
	await get_tree().process_frame

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 100.0,
		"new_health": 50.0,
		"is_dead": false,
	})

	assert_eq(captured.size(), 0, "System should unsubscribe on exit_tree")
	autofree(system)
