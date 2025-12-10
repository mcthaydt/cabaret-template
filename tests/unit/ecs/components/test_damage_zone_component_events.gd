extends BaseTest

const C_DamageZoneComponent := preload("res://scripts/ecs/components/c_damage_zone_component.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_damage_zone_publishes_enter_and_exit_events() -> void:
	var component := C_DamageZoneComponent.new()
	component.damage_amount = 12.0
	component.is_instant_death = false
	add_child(component)

	var body := CharacterBody3D.new()
	body.name = "E_PlayerBody"

	component._on_body_entered(body)
	component._on_body_exited(body)

	var events := U_ECSEventBus.get_event_history()
	assert_eq(events.size(), 2, "Entering and exiting should publish two events")

	var enter_event: Dictionary = events[0]
	assert_eq(enter_event.get("name"), StringName("damage_zone_entered"))
	var enter_payload: Dictionary = enter_event.get("payload", {})
	assert_eq(enter_payload.get("body"), body)
	assert_eq(enter_payload.get("zone"), component)
	assert_eq(enter_payload.get("damage_per_second"), 12.0)

	var exit_event: Dictionary = events[1]
	assert_eq(exit_event.get("name"), StringName("damage_zone_exited"))
	var exit_payload: Dictionary = exit_event.get("payload", {})
	assert_eq(exit_payload.get("body"), body)
	assert_eq(exit_payload.get("zone"), component)
