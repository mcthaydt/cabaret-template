extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const SCREEN_SHAKE_PUBLISHER := preload("res://scripts/ecs/systems/s_screen_shake_publisher_system.gd")
const EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const EVENT_NAMES := preload("res://scripts/ecs/u_ecs_event_names.gd")
const RS_ScreenShakeTuning := preload("res://scripts/ecs/resources/rs_screen_shake_tuning.gd")

const ENTITY_ID := StringName("player")


func before_each() -> void:
	EVENT_BUS.reset()


func _spawn_system(custom_tuning = null):
	var manager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var system = SCREEN_SHAKE_PUBLISHER.new()
	if custom_tuning != null:
		system.tuning = custom_tuning
	manager.add_child(system)
	autofree(system)
	await get_tree().process_frame
	return system


func _capture_requests() -> Array:
	var captured: Array = []
	EVENT_BUS.subscribe(EVENT_NAMES.EVENT_SCREEN_SHAKE_REQUEST, func(event_data: Dictionary) -> void:
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


func test_subscribes_to_entity_landed_on_ready() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_LANDED, {
		"entity_id": ENTITY_ID,
		"vertical_velocity": -20.0,
	})

	assert_eq(captured.size(), 1, "Should publish request on landing event")


func test_subscribes_to_entity_death_on_ready() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_DEATH, {
		"entity_id": ENTITY_ID,
	})

	assert_eq(captured.size(), 1, "Should publish request on death event")


func test_health_changed_publishes_screen_shake_request() -> void:
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
	assert_true(payload.get("trauma_amount", 0.0) is float)


func test_damage_maps_to_trauma_range_0_3_to_0_6() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 100.0,
		"new_health": 50.0,
		"is_dead": false,
	})

	var payload: Dictionary = captured[0].get("payload", {})
	var trauma: float = float(payload.get("trauma_amount", 0.0))
	assert_almost_eq(trauma, 0.45, 0.001, "Damage 50 should map to trauma 0.45")

func test_uses_injected_tuning_resource() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	tuning.damage_min_trauma = 0.0
	tuning.damage_max_trauma = 1.0
	tuning.damage_max_value = 10.0

	await _spawn_system(tuning)
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 10.0,
		"new_health": 5.0,
		"is_dead": false,
	})

	assert_eq(captured.size(), 1, "Injected tuning should publish request")
	var payload: Dictionary = captured[0].get("payload", {})
	var trauma: float = float(payload.get("trauma_amount", 0.0))
	assert_almost_eq(trauma, 0.5, 0.001, "Injected tuning should drive trauma calculation")

func test_fallback_to_default_tuning_when_not_injected() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_HEALTH_CHANGED, {
		"entity_id": ENTITY_ID,
		"previous_health": 100.0,
		"new_health": 50.0,
		"is_dead": false,
	})

	assert_eq(captured.size(), 1, "Default tuning should publish request")
	var payload: Dictionary = captured[0].get("payload", {})
	var trauma: float = float(payload.get("trauma_amount", 0.0))
	assert_almost_eq(trauma, 0.45, 0.001, "Default tuning should match resource values")

func test_custom_tuning_affects_trauma_calculation() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	tuning.landing_threshold = 0.0
	tuning.landing_max_speed = 10.0
	tuning.landing_min_trauma = 0.8
	tuning.landing_max_trauma = 1.0

	await _spawn_system(tuning)
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_LANDED, {
		"entity_id": ENTITY_ID,
		"vertical_velocity": -5.0,
	})

	assert_eq(captured.size(), 1, "Landing should publish request with custom tuning")
	var payload: Dictionary = captured[0].get("payload", {})
	var trauma: float = float(payload.get("trauma_amount", 0.0))
	assert_almost_eq(trauma, 0.9, 0.001, "Custom tuning should affect landing trauma")

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


func test_landing_above_threshold_publishes_request() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_LANDED, {
		"entity_id": ENTITY_ID,
		"vertical_velocity": -20.0,
	})

	assert_eq(captured.size(), 1, "High-speed landing should publish request")
	var payload: Dictionary = captured[0].get("payload", {})
	var trauma: float = float(payload.get("trauma_amount", 0.0))
	assert_true(trauma >= 0.2 and trauma <= 0.4, "Landing trauma should be in 0.2-0.4 range")


func test_landing_below_threshold_ignored() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_LANDED, {
		"entity_id": ENTITY_ID,
		"vertical_velocity": -10.0,
	})

	assert_eq(captured.size(), 0, "Low-speed landing should be ignored")


func test_death_publishes_fixed_trauma_0_5() -> void:
	await _spawn_system()
	var captured := _capture_requests()

	EVENT_BUS.publish(EVENT_NAMES.EVENT_ENTITY_DEATH, {
		"entity_id": ENTITY_ID,
	})

	assert_eq(captured.size(), 1)
	var payload: Dictionary = captured[0].get("payload", {})
	var trauma: float = float(payload.get("trauma_amount", 0.0))
	assert_almost_eq(trauma, 0.5, 0.001, "Death should publish trauma 0.5")


func test_unsubscribes_on_exit_tree() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var system := SCREEN_SHAKE_PUBLISHER.new()
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
