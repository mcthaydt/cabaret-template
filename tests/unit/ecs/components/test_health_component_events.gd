extends BaseTest

const C_HealthComponent := preload("res://scripts/ecs/components/c_health_component.gd")
const RS_HealthSettings := preload("res://scripts/ecs/resources/rs_health_settings.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_health_changed_event_includes_entity_id_and_values() -> void:
	var entity := autofree(Node3D.new())
	entity.name = "E_Player"
	add_child(entity)
	await get_tree().process_frame

	var component := C_HealthComponent.new()
	component.settings = RS_HealthSettings.new()
	entity.add_child(component)
	await get_tree().process_frame

	component.apply_damage(25.0)

	var events := U_ECSEventBus.get_event_history()
	assert_eq(events.size(), 1, "Health change should publish one event")

	var event: Dictionary = events[0]
	assert_eq(event.get("name"), StringName("health_changed"))
	var payload: Dictionary = event.get("payload", {})
	assert_eq(payload.get("entity_id"), StringName("player"))
	assert_almost_eq(payload.get("previous_health"), 100.0, 0.001)
	assert_almost_eq(payload.get("new_health"), 75.0, 0.001)
	assert_false(payload.get("is_dead", true))

func test_mark_dead_publishes_health_and_death_events() -> void:
	var entity := autofree(Node3D.new())
	entity.name = "E_Player"
	add_child(entity)
	await get_tree().process_frame

	var component := C_HealthComponent.new()
	component.settings = RS_HealthSettings.new()
	entity.add_child(component)
	await get_tree().process_frame

	component.mark_dead()

	var events := U_ECSEventBus.get_event_history()
	assert_eq(events.size(), 2, "Marking dead should publish health_changed and entity_death events")

	var health_event: Dictionary = events[0]
	assert_eq(health_event.get("name"), StringName("health_changed"))
	var health_payload: Dictionary = health_event.get("payload", {})
	assert_eq(health_payload.get("entity_id"), StringName("player"))
	assert_true(health_payload.get("is_dead", false))
	assert_almost_eq(health_payload.get("previous_health"), 100.0, 0.001)
	assert_almost_eq(health_payload.get("new_health"), 0.0, 0.001)

	var death_event: Dictionary = events[1]
	assert_eq(death_event.get("name"), StringName("entity_death"))
	var death_payload: Dictionary = death_event.get("payload", {})
	assert_eq(death_payload.get("entity_id"), StringName("player"))
	assert_true(death_payload.get("is_dead", false))
	assert_almost_eq(death_payload.get("previous_health"), 100.0, 0.001)
	assert_almost_eq(death_payload.get("new_health"), 0.0, 0.001)
