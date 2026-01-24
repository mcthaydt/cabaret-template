extends BaseTest

const M_ECSManager := preload("res://scripts/managers/m_ecs_manager.gd")
const S_DamageSystem := preload("res://scripts/ecs/systems/s_damage_system.gd")
const C_DamageZoneComponent := preload("res://scripts/ecs/components/c_damage_zone_component.gd")
const C_PlayerTagComponent := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const C_HealthComponent := preload("res://scripts/ecs/components/c_health_component.gd")
const RS_HealthSettings := preload("res://scripts/resources/ecs/rs_health_settings.gd")
const U_ECSEventBus := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_damage_applies_on_enter_event() -> void:
	var setup := await _setup_world()
	var damage_component: C_DamageZoneComponent = setup["zone"]
	var health_component: C_HealthComponent = setup["health"]
	var system: S_DamageSystem = setup["system"]
	var body: CharacterBody3D = setup["body"]

	damage_component.damage_amount = 10.0
	damage_component.damage_cooldown = 0.0

	U_ECSEventBus.publish(StringName("damage_zone_entered"), {
		"zone": damage_component,
		"zone_id": StringName("hazard"),
		"body": body,
	})

	system.process_tick(0.1)

	assert_eq(health_component.dequeue_total_damage(), 10.0,
		"Damage system should queue damage when enter event received")

func test_exit_event_stops_additional_damage() -> void:
	var setup := await _setup_world()
	var damage_component: C_DamageZoneComponent = setup["zone"]
	var health_component: C_HealthComponent = setup["health"]
	var system: S_DamageSystem = setup["system"]
	var body: CharacterBody3D = setup["body"]

	damage_component.damage_amount = 5.0
	damage_component.damage_cooldown = 0.0

	U_ECSEventBus.publish(StringName("damage_zone_entered"), {
		"zone": damage_component,
		"zone_id": StringName("hazard"),
		"body": body,
	})
	await get_tree().process_frame
	system.process_tick(0.1)
	health_component.dequeue_total_damage()

	U_ECSEventBus.publish(StringName("damage_zone_exited"), {
		"zone": damage_component,
		"zone_id": StringName("hazard"),
		"body": body,
	})
	await get_tree().process_frame
	system.process_tick(0.1)

	assert_eq(health_component.dequeue_total_damage(), 0.0,
		"Damage system should stop applying damage after exit event")

func _setup_world() -> Dictionary:
	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	var entity := Node3D.new()
	entity.name = "E_Player"
	manager.add_child(entity)

	var body := CharacterBody3D.new()
	body.name = "Body"
	entity.add_child(body)

	var player_tag := C_PlayerTagComponent.new()
	entity.add_child(player_tag)

	var health := C_HealthComponent.new()
	health.settings = RS_HealthSettings.new()
	entity.add_child(health)

	var zone_entity := Node3D.new()
	zone_entity.name = "E_DamageZone"
	manager.add_child(zone_entity)

	var zone := C_DamageZoneComponent.new()
	zone.damage_cooldown = 0.0
	zone_entity.add_child(zone)

	await wait_physics_frames(2)  # allow deferred registration

	var system := S_DamageSystem.new()
	manager.add_child(system)
	autofree(system)
	# on_configured() is automatically called by BaseECSSystem.configure()
	await wait_physics_frames(2)

	return {
		"manager": manager,
		"entity": entity,
		"health": health,
		"zone": zone,
		"system": system,
		"body": body,
	}
