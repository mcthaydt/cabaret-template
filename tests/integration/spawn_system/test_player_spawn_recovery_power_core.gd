extends GutTest

const SCENE_PATH := "res://scenes/gameplay/gameplay_power_core.tscn"
const M_SPAWN_MANAGER := preload("res://scripts/core/managers/m_spawn_manager.gd")
const M_STATE_STORE := preload("res://scripts/core/state/m_state_store.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const U_ECS_UTILS := preload("res://scripts/core/utils/ecs/u_ecs_utils.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/core/ecs/components/c_floating_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/core/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/core/ecs/components/c_movement_component.gd")
const C_SPAWN_RECOVERY_COMPONENT := preload("res://scripts/core/ecs/components/c_spawn_recovery_component.gd")

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

func test_player_recovers_to_default_spawn_when_falling_below_map() -> void:
	if _scene == null:
		fail_test("Scene failed to instantiate")
		return

	var entity := _scene.get_node_or_null("Entities/E_Player") as Node3D
	var body := _scene.get_node_or_null("Entities/E_Player/Player_Body") as CharacterBody3D
	var recovery_system := _scene.get_node_or_null("Systems/Movement/S_SpawnRecoverySystem")
	var spawn_point := _scene.get_node_or_null("Entities/SpawnPoints/sp_default") as Node3D
	assert_not_null(entity, "Expected player entity in gameplay_power_core")
	assert_not_null(body, "Expected player body in gameplay_power_core")
	assert_not_null(recovery_system, "Expected S_SpawnRecoverySystem in gameplay_power_core")
	assert_not_null(spawn_point, "Expected default spawn point in gameplay_power_core")
	if entity == null or body == null or recovery_system == null or spawn_point == null:
		return

	var spawn_recovery := _scene.get_node_or_null("Entities/E_Player/Components/C_SpawnRecoveryComponent") as C_SPAWN_RECOVERY_COMPONENT
	var floating := _scene.get_node_or_null("Entities/E_Player/Components/C_FloatingComponent") as C_FLOATING_COMPONENT
	var input_component := _scene.get_node_or_null("Entities/E_Player/Components/C_InputComponent") as C_INPUT_COMPONENT
	var movement := _scene.get_node_or_null("Entities/E_Player/Components/C_MovementComponent") as C_MOVEMENT_COMPONENT
	assert_not_null(spawn_recovery, "Expected player spawn recovery component")
	assert_not_null(floating, "Expected player floating component")
	assert_not_null(input_component, "Expected player input component")
	assert_not_null(movement, "Expected player movement component")
	if spawn_recovery == null or floating == null or input_component == null or movement == null:
		return

	var recovery_settings: Resource = spawn_recovery.settings
	assert_not_null(recovery_settings, "Expected player spawn recovery settings")
	if recovery_settings == null:
		return

	recovery_settings.set("unsupported_delay_sec", 0.0)
	recovery_settings.set("recovery_cooldown_sec", 1.0)
	recovery_settings.set("startup_grace_period_sec", 1.0)

	var now: float = U_ECS_UTILS.get_current_time()
	if movement.settings != null:
		movement.settings.support_grace_time = 0.0
	floating.reset_recent_support(now, 5.0)

	entity.global_position = Vector3(80.0, -140.0, -75.0)
	body.velocity = Vector3(0.4, -20.0, 0.6)
	input_component.set_move_vector(Vector2(0.9, -0.3))

	recovery_system.process_tick(1.1)
	recovery_system.process_tick(0.016)

	assert_true(entity.global_position.y > -5.0, "Player should respawn near floor, not remain far below the map")
	assert_almost_eq(entity.global_position.x, spawn_point.global_position.x, 0.25)
	assert_almost_eq(entity.global_position.z, spawn_point.global_position.z, 0.25)
	assert_eq(input_component.move_vector, Vector2.ZERO, "Respawn should clear player move vector")
	assert_eq(body.velocity, Vector3.ZERO, "Respawn should clear player body velocity")
