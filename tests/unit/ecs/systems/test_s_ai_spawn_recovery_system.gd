extends BaseTest

const S_AI_SPAWN_RECOVERY_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_spawn_recovery_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_FLOATING_SETTINGS := preload("res://scripts/resources/ecs/rs_floating_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const I_SPAWN_MANAGER := preload("res://scripts/interfaces/i_spawn_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

class SpawnManagerStub extends I_SPAWN_MANAGER:
	var spawn_entity_calls: Array[Dictionary] = []
	var return_value: bool = true

	func spawn_player_at_point(_scene: Node, _spawn_point_id: StringName) -> bool:
		return false

	func spawn_entity_at_point(scene: Node, entity_id: StringName, spawn_point_id: StringName) -> bool:
		spawn_entity_calls.append({
			"scene": scene,
			"entity_id": entity_id,
			"spawn_point_id": spawn_point_id,
		})
		return return_value

	func initialize_scene_camera(_scene: Node) -> Camera3D:
		return null

	func spawn_at_last_spawn(_scene: Node) -> bool:
		return false

class FakeBody extends CharacterBody3D:
	pass

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_fixture(include_spawn_point: bool = true, spawn_point_id: StringName = &"sp_ai_patrol") -> Dictionary:
	var system_script: Script = _load_script(S_AI_SPAWN_RECOVERY_SYSTEM_PATH)
	if system_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_AISpawnRecoverySystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var system: BaseECSSystem = system_variant as BaseECSSystem
	autofree(system)
	system.ecs_manager = ecs_manager
	system.configure(ecs_manager)

	var scene_root := Node3D.new()
	scene_root.name = "GameplayRoot"
	add_child_autofree(scene_root)
	scene_root.add_child(system)

	var entities_root := Node3D.new()
	entities_root.name = "Entities"
	scene_root.add_child(entities_root)

	var spawn_points_root := Node3D.new()
	spawn_points_root.name = "SpawnPoints"
	entities_root.add_child(spawn_points_root)

	if include_spawn_point:
		var spawn_point := Node3D.new()
		spawn_point.name = String(spawn_point_id)
		spawn_points_root.add_child(spawn_point)
		autofree(spawn_point)

	var npcs := Node3D.new()
	npcs.name = "NPCs"
	entities_root.add_child(npcs)

	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_PatrolDrone"
	entity.entity_id = &"patrol_drone"
	npcs.add_child(entity)
	autofree(entity)

	var body := FakeBody.new()
	body.name = "NPC_Body"
	entity.add_child(body)
	autofree(body)

	var brain := C_AI_BRAIN_COMPONENT.new()
	var brain_settings := RS_AI_BRAIN_SETTINGS.new()
	brain_settings.respawn_spawn_point_id = spawn_point_id
	brain_settings.respawn_unsupported_delay_sec = 0.0
	brain_settings.respawn_recovery_cooldown_sec = 1.0
	brain.brain_settings = brain_settings
	brain.task_state = {"ai_move_target": Vector3(6.0, 1.0, -6.0)}
	entity.add_child(brain)
	autofree(brain)

	var movement := C_MOVEMENT_COMPONENT.new()
	var movement_settings := RS_MOVEMENT_SETTINGS.new()
	movement_settings.support_grace_time = 0.0
	movement.settings = movement_settings
	entity.add_child(movement)
	autofree(movement)

	var input := C_INPUT_COMPONENT.new()
	input.set_move_vector(Vector2(0.8, -0.4))
	entity.add_child(input)
	autofree(input)

	var floating := C_FLOATING_COMPONENT.new()
	floating.settings = RS_FLOATING_SETTINGS.new()
	floating.update_support_state(false, -9999.0)
	entity.add_child(floating)
	autofree(floating)

	ecs_manager.add_component_to_entity(entity, brain)
	ecs_manager.add_component_to_entity(entity, floating)
	ecs_manager.add_component_to_entity(entity, movement)
	ecs_manager.add_component_to_entity(entity, input)

	var spawn_manager := SpawnManagerStub.new()
	autofree(spawn_manager)
	U_SERVICE_LOCATOR.register(StringName("spawn_manager"), spawn_manager)

	return {
		"system": system,
		"ecs_manager": ecs_manager,
		"scene_root": scene_root,
		"entity": entity,
		"body": body,
		"brain": brain,
		"input": input,
		"floating": floating,
		"spawn_manager": spawn_manager,
	}

func test_does_not_recover_when_unsupported_window_is_brief() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var brain: C_AI_BRAIN_COMPONENT = fixture["brain"] as C_AI_BRAIN_COMPONENT
	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	var settings: RS_AIBrainSettings = brain.brain_settings as RS_AIBrainSettings
	settings.respawn_unsupported_delay_sec = 5.0

	system.process_tick(0.016)

	assert_eq(spawn_manager.spawn_entity_calls.size(), 0, "Recovery should not trigger before unsupported delay elapses")

func test_recovers_once_then_respects_cooldown_and_clears_ai_state() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: C_AI_BRAIN_COMPONENT = fixture["brain"] as C_AI_BRAIN_COMPONENT
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.velocity = Vector3(1.0, -12.0, 2.0)
	input.set_move_vector(Vector2(0.9, 0.2))

	system.process_tick(0.016)
	system.process_tick(0.016)

	assert_eq(spawn_manager.spawn_entity_calls.size(), 1, "Recovery should trigger once then be held by cooldown")
	assert_eq(input.move_vector, Vector2.ZERO, "Recovery should clear movement input")
	assert_eq(body.velocity, Vector3.ZERO, "Recovery should zero body velocity")
	assert_eq(brain.task_state, {}, "Recovery should clear brain task_state")

func test_missing_spawn_point_disables_recovery_for_entity_session() -> void:
	var fixture: Dictionary = _create_fixture(false, &"sp_missing_ai_spawn")
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var scene_root: Node3D = fixture["scene_root"] as Node3D

	system.process_tick(0.016)
	assert_push_error("spawn point 'sp_missing_ai_spawn' missing for entity 'patrol_drone'")
	assert_eq(spawn_manager.spawn_entity_calls.size(), 0, "Recovery should not call spawn manager when spawn point is missing")

	var late_spawn := Node3D.new()
	late_spawn.name = "sp_missing_ai_spawn"
	scene_root.get_node("Entities/SpawnPoints").add_child(late_spawn)
	autofree(late_spawn)

	system.process_tick(0.016)
	assert_eq(spawn_manager.spawn_entity_calls.size(), 0, "Recovery should remain disabled for the entity after missing-spawn failure")
