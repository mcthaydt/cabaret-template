extends GutTest

const SCENE_PATH := "res://scenes/gameplay/gameplay_power_core.tscn"
const M_SPAWN_MANAGER := preload("res://scripts/core/managers/m_spawn_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const C_SPAWN_RECOVERY_COMPONENT := preload("res://scripts/ecs/components/c_spawn_recovery_component.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")

var _store: M_StateStore
var _spawn_manager: M_SpawnManager
var _scene: Node

func before_each() -> void:
	U_ServiceLocator.clear()

	_store = M_STATE_STORE.new()
	_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	_spawn_manager = M_SPAWN_MANAGER.new()
	add_child_autofree(_spawn_manager)
	U_ServiceLocator.register(StringName("spawn_manager"), _spawn_manager)
	await get_tree().process_frame

	var scene_resource: PackedScene = load(SCENE_PATH) as PackedScene
	assert_not_null(scene_resource, "Expected gameplay_power_core scene to load")
	if scene_resource == null:
		return

	_scene = scene_resource.instantiate()
	add_child_autofree(_scene)
	await get_tree().process_frame
	await get_tree().physics_frame

func after_each() -> void:
	U_ServiceLocator.clear()
	_store = null
	_spawn_manager = null
	_scene = null

func test_patrol_drone_recovers_to_ai_spawn_point_when_support_is_lost() -> void:
	if _scene == null:
		fail_test("Scene failed to instantiate")
		return

	var entity := _scene.get_node_or_null("Entities/NPCs/E_PatrolDrone") as Node3D
	var body := _scene.get_node_or_null("Entities/NPCs/E_PatrolDrone/Player_Body") as CharacterBody3D
	var recovery_system := _scene.get_node_or_null("Systems/Movement/S_SpawnRecoverySystem")
	var spawn_point := _scene.get_node_or_null("Entities/SpawnPoints/sp_ai_patrol_drone") as Node3D
	assert_not_null(entity, "Expected patrol drone entity in gameplay_power_core")
	assert_not_null(body, "Expected patrol drone body in gameplay_power_core")
	assert_not_null(recovery_system, "Expected S_SpawnRecoverySystem in gameplay_power_core")
	assert_not_null(spawn_point, "Expected AI patrol drone spawn point in gameplay_power_core")
	if entity == null or body == null or recovery_system == null or spawn_point == null:
		return

	var brain := _scene.get_node_or_null("Entities/NPCs/E_PatrolDrone/Components/C_AIBrainComponent") as C_AI_BRAIN_COMPONENT
	var spawn_recovery := _scene.get_node_or_null("Entities/NPCs/E_PatrolDrone/Components/C_SpawnRecoveryComponent") as C_SPAWN_RECOVERY_COMPONENT
	var floating := _scene.get_node_or_null("Entities/NPCs/E_PatrolDrone/Components/C_FloatingComponent") as C_FLOATING_COMPONENT
	var input_component := _scene.get_node_or_null("Entities/NPCs/E_PatrolDrone/Components/C_InputComponent") as C_INPUT_COMPONENT
	var movement := _scene.get_node_or_null("Entities/NPCs/E_PatrolDrone/Components/C_MovementComponent") as C_MOVEMENT_COMPONENT
	assert_not_null(brain, "Expected patrol drone brain component")
	assert_not_null(spawn_recovery, "Expected patrol drone spawn recovery component")
	assert_not_null(floating, "Expected patrol drone floating component")
	assert_not_null(input_component, "Expected patrol drone input component")
	assert_not_null(movement, "Expected patrol drone movement component")
	if brain == null or spawn_recovery == null or floating == null or input_component == null or movement == null:
		return

	var now: float = U_ECS_UTILS.get_current_time()
	if movement.settings != null:
		movement.settings.support_grace_time = 0.0
	floating.reset_recent_support(now, 5.0)
	brain.bt_state_bag = {
		101: {"ai_move_target": Vector3(6.0, 1.0, -6.0)},
	}
	var recovery_settings: Resource = spawn_recovery.settings
	assert_not_null(recovery_settings, "Expected patrol drone spawn recovery settings")
	if recovery_settings == null:
		return
	recovery_settings.set("unsupported_delay_sec", 0.0)
	recovery_settings.set("recovery_cooldown_sec", 1.0)

	entity.global_position = Vector3(50.0, -120.0, 50.0)
	body.velocity = Vector3(0.5, -30.0, 0.3)
	input_component.set_move_vector(Vector2(0.7, -0.8))

	# Advance past startup grace period so recovery can fire
	recovery_system.process_tick(1.1)
	recovery_system.process_tick(0.016)

	assert_true(entity.global_position.y > -5.0, "Patrol drone should be recovered near gameplay floor, not left far below scene")
	assert_almost_eq(entity.global_position.x, spawn_point.global_position.x, 0.2)
	assert_almost_eq(entity.global_position.z, spawn_point.global_position.z, 0.2)
	assert_eq(input_component.move_vector, Vector2.ZERO, "Recovery should clear AI input vector")
	assert_eq(body.velocity, Vector3.ZERO, "Recovery should zero patrol drone velocity")
	assert_eq(brain.bt_state_bag, {}, "Recovery should clear AI BT runtime state to avoid stale move targets")
