extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const DEATH_HANDLER_SYSTEM := preload("res://scripts/ecs/systems/s_death_handler_system.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func _pump() -> void:
	await get_tree().process_frame

func _setup_fixture() -> Dictionary:
	var manager := ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await _pump()

	var entity := Node3D.new()
	entity.name = "E_Player"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var body := CharacterBody3D.new()
	body.name = "Body"
	entity.add_child(body)
	autofree(body)
	await _pump()

	var system := DEATH_HANDLER_SYSTEM.new()
	manager.add_child(system)
	autofree(system)
	await _pump()

	return {
		"manager": manager,
		"entity": entity,
		"body": body,
		"system": system,
	}

func test_death_request_spawns_ragdoll_and_hides_entity() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var entity: Node3D = fixture["entity"] as Node3D
	var body: CharacterBody3D = fixture["body"] as CharacterBody3D
	var system: Variant = fixture["system"]

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH_REQUESTED, {
		"entity_id": "player",
		"entity_root": entity,
		"body": body,
	})
	await _pump()

	assert_false(entity.visible, "Death handler should hide the source entity when ragdoll spawns")
	var ragdoll: RigidBody3D = system.call("get_ragdoll_for_entity", StringName("E_Player")) as RigidBody3D
	assert_not_null(ragdoll, "Death handler should spawn a ragdoll instance")

func test_respawn_request_restores_visibility_and_clears_ragdoll() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var entity: Node3D = fixture["entity"] as Node3D
	var body: CharacterBody3D = fixture["body"] as CharacterBody3D
	var system: Variant = fixture["system"]

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH_REQUESTED, {
		"entity_id": "player",
		"entity_root": entity,
		"body": body,
	})
	await _pump()
	assert_not_null(system.call("get_ragdoll_for_entity", StringName("E_Player")))

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_RESPAWN_REQUESTED, {
		"entity_id": "player",
		"entity_root": entity,
	})
	await _pump()

	assert_true(entity.visible, "Respawn should restore entity visibility")
	assert_null(system.call("get_ragdoll_for_entity", StringName("E_Player")), "Respawn should free ragdoll")

func test_unknown_entity_id_payload_is_ignored() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var entity: Node3D = fixture["entity"] as Node3D
	var system: Variant = fixture["system"]

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH_REQUESTED, {
		"entity_id": "ghost",
	})
	await _pump()

	assert_true(entity.visible, "Invalid payload should leave entity unchanged")
	assert_null(system.call("get_ragdoll_for_entity", StringName("E_Player")), "Unknown entity_id should not spawn ragdoll")
