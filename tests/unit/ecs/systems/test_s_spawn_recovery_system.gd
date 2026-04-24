extends BaseTest

const S_SPAWN_RECOVERY_SYSTEM_PATH := "res://scripts/ecs/systems/s_spawn_recovery_system.gd"
const C_SPAWN_RECOVERY_COMPONENT_PATH := "res://scripts/ecs/components/c_spawn_recovery_component.gd"
const RS_SPAWN_RECOVERY_SETTINGS_PATH := "res://scripts/core/resources/ecs/rs_spawn_recovery_settings.gd"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/core/resources/ai/brain/rs_ai_brain_settings.gd")
const RS_FLOATING_SETTINGS := preload("res://scripts/core/resources/ecs/rs_floating_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/core/resources/ecs/rs_movement_settings.gd")
const I_SPAWN_MANAGER := preload("res://scripts/core/interfaces/i_spawn_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

class SpawnManagerStub extends I_SPAWN_MANAGER:
	var spawn_player_calls: Array[Dictionary] = []
	var spawn_entity_calls: Array[Dictionary] = []
	var spawn_last_calls: Array[Dictionary] = []
	var return_value: bool = true

	func spawn_player_at_point(scene: Node, spawn_point_id: StringName) -> bool:
		spawn_player_calls.append({
			"scene": scene,
			"spawn_point_id": spawn_point_id,
		})
		return return_value

	func spawn_entity_at_point(scene: Node, entity_id: StringName, spawn_point_id: StringName) -> bool:
		spawn_entity_calls.append({
			"scene": scene,
			"entity_id": entity_id,
			"spawn_point_id": spawn_point_id,
		})
		return return_value

	func initialize_scene_camera(_scene: Node) -> Camera3D:
		return null

	func spawn_at_last_spawn(scene: Node) -> bool:
		spawn_last_calls.append({
			"scene": scene,
		})
		return return_value

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

func _create_fixture(
	entity_id: StringName,
	spawn_point_id: StringName,
	include_ai_brain: bool = true
) -> Dictionary:
	var system_script: Script = _load_script(S_SPAWN_RECOVERY_SYSTEM_PATH)
	var recovery_component_script: Script = _load_script(C_SPAWN_RECOVERY_COMPONENT_PATH)
	var recovery_settings_script: Script = _load_script(RS_SPAWN_RECOVERY_SETTINGS_PATH)
	if system_script == null or recovery_component_script == null or recovery_settings_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_SpawnRecoverySystem should extend BaseECSSystem")
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

	if spawn_point_id != StringName(""):
		var spawn_point := Node3D.new()
		spawn_point.name = String(spawn_point_id)
		spawn_points_root.add_child(spawn_point)
		autofree(spawn_point)

	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_%s" % String(entity_id).capitalize()
	entity.entity_id = entity_id
	entities_root.add_child(entity)
	autofree(entity)

	var body := FakeBody.new()
	body.name = "NPC_Body"
	entity.add_child(body)
	autofree(body)

	var recovery_component: BaseECSComponent = recovery_component_script.new()
	var recovery_settings: Resource = recovery_settings_script.new()
	recovery_settings.set("spawn_point_id", spawn_point_id)
	recovery_settings.set("unsupported_delay_sec", 0.0)
	recovery_settings.set("recovery_cooldown_sec", 1.0)
	recovery_settings.set("startup_grace_period_sec", 1.0)
	recovery_component.set("settings", recovery_settings)
	entity.add_child(recovery_component)
	autofree(recovery_component)

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

	var brain: C_AIBrainComponent = null
	if include_ai_brain:
		brain = C_AI_BRAIN_COMPONENT.new()
		brain.brain_settings = RS_AI_BRAIN_SETTINGS.new()
		brain.bt_state_bag = {
			101: {"ai_move_target": Vector3(6.0, 1.0, -6.0)},
		}
		entity.add_child(brain)
		autofree(brain)
		ecs_manager.add_component_to_entity(entity, brain)

	ecs_manager.add_component_to_entity(entity, recovery_component)
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
		"recovery_component": recovery_component,
		"recovery_settings": recovery_settings,
	}

func test_entity_unsupported_beyond_delay_triggers_respawn() -> void:
	var fixture: Dictionary = _create_fixture(&"patrol_drone", &"sp_ai_patrol_drone")
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	system.process_tick(1.1)
	system.process_tick(0.016)

	assert_eq(spawn_manager.spawn_entity_calls.size(), 1, "Unsupported entity should trigger respawn once delay elapses")

func test_startup_grace_period_prevents_early_recovery() -> void:
	var fixture: Dictionary = _create_fixture(&"patrol_drone", &"sp_ai_patrol_drone")
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	for i in range(30):
		system.process_tick(0.016)

	assert_eq(spawn_manager.spawn_entity_calls.size(), 0, "Recovery must not fire during startup grace period")

func test_recovery_cooldown_prevents_spam() -> void:
	var fixture: Dictionary = _create_fixture(&"patrol_drone", &"sp_ai_patrol_drone")
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	system.process_tick(1.1)
	system.process_tick(0.016)
	system.process_tick(0.016)

	assert_eq(spawn_manager.spawn_entity_calls.size(), 1, "Cooldown should suppress repeated respawns")

func test_supported_entity_clears_unsupported_timer() -> void:
	var fixture: Dictionary = _create_fixture(&"patrol_drone", &"sp_ai_patrol_drone")
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var floating: C_FloatingComponent = fixture["floating"] as C_FloatingComponent
	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var settings: Resource = fixture["recovery_settings"] as Resource
	settings.set("unsupported_delay_sec", 5.0)

	system.process_tick(1.1)
	floating.update_support_state(true, 9999.0)
	system.process_tick(0.016)
	floating.update_support_state(false, -9999.0)
	system.process_tick(0.016)

	assert_eq(spawn_manager.spawn_entity_calls.size(), 0, "Support recovery should clear unsupported timer and prevent immediate respawn")

func test_player_entity_respawned_via_shared_system() -> void:
	var fixture: Dictionary = _create_fixture(&"player", StringName(""), false)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	system.process_tick(1.1)
	system.process_tick(0.016)

	assert_eq(spawn_manager.spawn_last_calls.size(), 1, "Player entity should respawn through shared player spawn flow")
	assert_eq(spawn_manager.spawn_entity_calls.size(), 0, "Player recovery should not use entity spawn flow when spawn_point_id is empty")

func test_npc_entity_respawned_via_shared_system() -> void:
	var fixture: Dictionary = _create_fixture(&"patrol_drone", &"sp_ai_patrol_drone", true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: C_AIBrainComponent = fixture["brain"] as C_AIBrainComponent
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var spawn_manager: SpawnManagerStub = fixture["spawn_manager"] as SpawnManagerStub
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.velocity = Vector3(2.0, -12.0, 0.3)
	input.set_move_vector(Vector2(0.7, -0.3))

	system.process_tick(1.1)
	system.process_tick(0.016)

	assert_eq(spawn_manager.spawn_entity_calls.size(), 1, "NPC entity should respawn via generic entity spawn flow")
	assert_eq(input.move_vector, Vector2.ZERO, "Respawn should clear move vector")
	assert_eq(body.velocity, Vector3.ZERO, "Respawn should clear body velocity")
	assert_eq(brain.bt_state_bag, {}, "Respawn should clear AI BT runtime state for NPCs")
