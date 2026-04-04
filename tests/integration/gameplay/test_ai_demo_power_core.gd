extends BaseTest

## Integration test for the AI demo in gameplay_power_core.
## Validates the full patrol → investigate goal-switch pipeline using
## the actual patrol-drone brain settings loaded from the scene, with
## mocked ECS infrastructure (MockECSManager + MockStateStore).

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const S_AI_NAVIGATION_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_navigation_system.gd"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")

const PATROL_DRONE_BRAIN_SETTINGS := preload("res://resources/ai/patrol_drone/cfg_patrol_drone_brain.tres")

const WAYPOINT_A := Vector3(-6.0, 1.0, -6.0)
const WAYPOINT_B := Vector3(6.0, 1.0, -6.0)
const WAYPOINT_C := Vector3(6.0, 1.0, 6.0)
const WAYPOINT_D := Vector3(-6.0, 1.0, 6.0)
const FLAG_ZONE_POSITION := Vector3(4.0, 1.0, 0.0)
const DRONE_START := Vector3(-4.0, 2.5, 0.0)
const MOVE_SIMULATION_SPEED := 6.0

class FakeBody extends CharacterBody3D:
	pass

var _store: MockStateStore
var _ecs_manager: MockECSManager
var _behavior_system: BaseECSSystem
var _navigation_system: BaseECSSystem
var _root: Node3D
var _ai_entity: Node3D
var _ai_body: FakeBody
var _ai_brain: C_AIBrainComponent
var _ai_input: C_InputComponent

func before_each() -> void:
	U_ServiceLocator.clear()

	_store = MOCK_STATE_STORE.new()
	_store.set_slice(StringName("gameplay"), {})
	autofree(_store)
	add_child(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)

	_ecs_manager = MOCK_ECS_MANAGER.new()
	autofree(_ecs_manager)

	_root = Node3D.new()
	add_child_autofree(_root)

	var behavior_script: Script = load(S_AI_BEHAVIOR_SYSTEM_PATH) as Script
	assert_not_null(behavior_script)
	if behavior_script == null:
		return
	_behavior_system = behavior_script.new() as BaseECSSystem
	autofree(_behavior_system)
	_root.add_child(_behavior_system)
	_behavior_system.state_store = _store
	_behavior_system.ecs_manager = _ecs_manager
	_behavior_system.configure(_ecs_manager)

	var navigation_script: Script = load(S_AI_NAVIGATION_SYSTEM_PATH) as Script
	assert_not_null(navigation_script)
	if navigation_script == null:
		return
	_navigation_system = navigation_script.new() as BaseECSSystem
	autofree(_navigation_system)
	_root.add_child(_navigation_system)
	_navigation_system.ecs_manager = _ecs_manager
	_navigation_system.configure(_ecs_manager)

	# Scene node stubs — patrol .tres uses relative NodePaths from entity
	# (e.g. "../../Waypoints/WaypointA"). Entity lives at _root/E_PatrolDrone,
	# so "../../" resolves to self (the test node).
	var waypoints_container := Node3D.new()
	waypoints_container.name = "Waypoints"
	add_child_autofree(waypoints_container)
	_add_waypoint(waypoints_container, "WaypointA", WAYPOINT_A)
	_add_waypoint(waypoints_container, "WaypointB", WAYPOINT_B)
	_add_waypoint(waypoints_container, "WaypointC", WAYPOINT_C)
	_add_waypoint(waypoints_container, "WaypointD", WAYPOINT_D)

	var interactions_container := Node3D.new()
	interactions_container.name = "Interactions"
	add_child_autofree(interactions_container)
	var flag_zone_stub := Node3D.new()
	flag_zone_stub.name = "Inter_ActivatableNode"
	interactions_container.add_child(flag_zone_stub)
	flag_zone_stub.global_position = FLAG_ZONE_POSITION

	_ai_entity = Node3D.new()
	_ai_entity.name = "E_PatrolDrone"
	autofree(_ai_entity)
	_root.add_child(_ai_entity)

	_ai_body = FakeBody.new()
	_ai_entity.add_child(_ai_body)
	autofree(_ai_body)
	_ai_body.global_position = DRONE_START

	var ai_movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	ai_movement.settings = RS_MOVEMENT_SETTINGS.new()
	_ai_entity.add_child(ai_movement)
	autofree(ai_movement)

	_ai_input = C_INPUT_COMPONENT.new()
	_ai_entity.add_child(_ai_input)
	autofree(_ai_input)

	_ai_brain = C_AI_BRAIN_COMPONENT.new()
	_ai_brain.brain_settings = PATROL_DRONE_BRAIN_SETTINGS.duplicate(true)
	_ai_entity.add_child(_ai_brain)
	autofree(_ai_brain)

	_ecs_manager.add_component_to_entity(_ai_entity, _ai_brain)
	_ecs_manager.add_component_to_entity(_ai_entity, _ai_input)
	_ecs_manager.add_component_to_entity(_ai_entity, ai_movement)

func after_each() -> void:
	U_ServiceLocator.clear()
	_store = null
	_ecs_manager = null
	_behavior_system = null
	_navigation_system = null
	_root = null
	_ai_entity = null
	_ai_body = null
	_ai_brain = null
	_ai_input = null

func _simulate_ai_motion(delta: float) -> void:
	var move_vector: Vector2 = _ai_input.move_vector
	if move_vector.length() <= 0.0001:
		return
	var clamped := move_vector.normalized() if move_vector.length() > 1.0 else move_vector
	var desired_velocity := Vector3(clamped.x, 0.0, clamped.y) * MOVE_SIMULATION_SPEED
	_ai_body.global_position += desired_velocity * maxf(delta, 0.0)

func _tick(delta: float) -> void:
	_behavior_system.process_tick(delta)
	_navigation_system.process_tick(delta)
	_simulate_ai_motion(delta)

func _add_waypoint(container: Node3D, wp_name: String, position: Vector3) -> void:
	var wp := Node3D.new()
	wp.name = wp_name
	container.add_child(wp)
	wp.global_position = position

func _set_flag(flag_id: StringName, value: bool) -> void:
	var gameplay: Dictionary = _store.get_slice(StringName("gameplay"))
	var flags: Dictionary = {}
	var flags_variant: Variant = gameplay.get("ai_demo_flags", {})
	if flags_variant is Dictionary:
		flags = (flags_variant as Dictionary).duplicate(true)
	flags[flag_id] = value
	gameplay["ai_demo_flags"] = flags
	_store.set_slice(StringName("gameplay"), gameplay)

# ---------------------------------------------------------------
# Tests
# ---------------------------------------------------------------

func test_patrol_drone_starts_with_patrol_goal() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_tick(0.1)

	assert_eq(_ai_brain.active_goal_id, StringName("patrol"), "Drone should begin with patrol goal")
	assert_false(_ai_brain.current_task_queue.is_empty(), "Patrol should decompose into a non-empty task queue")

func test_patrol_drone_moves_toward_first_waypoint() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_tick(0.1)

	assert_true(_ai_brain.task_state.has("ai_move_target"), "First patrol task should set a move target")
	assert_true(_ai_input.move_vector.length() > 0.0, "Navigation should produce a non-zero move vector")

func test_patrol_drone_reaches_waypoints_in_order() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	var waypoints: Array[Vector3] = [WAYPOINT_A, WAYPOINT_B, WAYPOINT_C, WAYPOINT_D]
	var reached: Array[bool] = [false, false, false, false]
	var current_wp_index: int = 0

	for _step in range(600):
		_tick(0.1)

		if current_wp_index < waypoints.size():
			var xz_dist := Vector2(
				_ai_body.global_position.x - waypoints[current_wp_index].x,
				_ai_body.global_position.z - waypoints[current_wp_index].z
			).length()
			if xz_dist <= 1.0:
				reached[current_wp_index] = true
				current_wp_index += 1

		if current_wp_index >= waypoints.size():
			break

	assert_true(reached[0], "Patrol drone should reach waypoint A")
	assert_true(reached[1], "Patrol drone should reach waypoint B")
	assert_true(reached[2], "Patrol drone should reach waypoint C")
	assert_true(reached[3], "Patrol drone should reach waypoint D")

func test_patrol_completes_and_loops() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	var queue_emptied: bool = false
	for _step in range(800):
		_tick(0.1)
		if _ai_brain.current_task_queue.is_empty():
			queue_emptied = true
			break

	assert_true(queue_emptied, "Patrol task queue should drain after visiting all waypoints")

	for _replan_step in range(10):
		_tick(0.1)
		if not _ai_brain.current_task_queue.is_empty():
			break

	assert_eq(_ai_brain.active_goal_id, StringName("patrol"), "Drone should re-plan patrol after queue drains")
	assert_false(_ai_brain.current_task_queue.is_empty(), "Patrol should re-decompose for the next loop")

func test_investigate_goal_activates_on_flag() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_tick(0.1)
	assert_eq(_ai_brain.active_goal_id, StringName("patrol"))

	_set_flag(StringName("power_core_activated"), true)

	for _step in range(10):
		_tick(0.1)
		if _ai_brain.active_goal_id == StringName("investigate"):
			break

	assert_eq(_ai_brain.active_goal_id, StringName("investigate"), "Drone should switch to investigate when power_core_activated flag is set")

func test_investigate_produces_movement_toward_flag_zone() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	for _step in range(10):
		_tick(0.1)
		if _ai_brain.active_goal_id == StringName("investigate"):
			break

	assert_eq(_ai_brain.active_goal_id, StringName("investigate"))
	assert_true(_ai_input.move_vector.length() > 0.0, "Investigate goal should produce movement input")

func test_investigate_completes_full_sequence() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	var switched_to_investigate: bool = false
	var investigate_queue_emptied: bool = false

	for _step in range(600):
		_tick(0.1)
		if not switched_to_investigate and _ai_brain.active_goal_id == StringName("investigate"):
			switched_to_investigate = true
		if switched_to_investigate and _ai_brain.current_task_queue.is_empty():
			investigate_queue_emptied = true
			break

	assert_true(switched_to_investigate, "Should switch to investigate goal")
	assert_true(investigate_queue_emptied, "Investigate task queue should drain after move + scan + wait")

func test_drone_returns_to_patrol_after_investigate() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	var investigate_done: bool = false
	for _step in range(600):
		_tick(0.1)
		if _ai_brain.active_goal_id == StringName("investigate") and _ai_brain.current_task_queue.is_empty():
			investigate_done = true
			break

	assert_true(investigate_done, "Investigate should complete")

	for _step in range(30):
		_tick(0.1)
		if _ai_brain.active_goal_id == StringName("patrol"):
			break

	assert_eq(_ai_brain.active_goal_id, StringName("patrol"), "Drone should fall back to patrol after investigate completes")

func test_rising_edge_prevents_re_investigate_while_flag_stays_true() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	var investigate_done: bool = false
	for _step in range(600):
		_tick(0.1)
		if _ai_brain.active_goal_id == StringName("investigate") and _ai_brain.current_task_queue.is_empty():
			investigate_done = true
			break

	assert_true(investigate_done, "First investigate should complete")

	# Tick enough to clear any cooldowns
	for _step in range(50):
		_tick(0.1)

	# Flag is still true — rising edge should prevent re-triggering
	assert_eq(_ai_brain.active_goal_id, StringName("patrol"), "Rising edge should prevent re-investigate while flag stays true")

func test_rising_edge_allows_re_investigate_after_flag_toggle() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	var first_investigate_done: bool = false
	for _step in range(600):
		_tick(0.1)
		if _ai_brain.active_goal_id == StringName("investigate") and _ai_brain.current_task_queue.is_empty():
			first_investigate_done = true
			break

	assert_true(first_investigate_done, "First investigate should complete")

	# Wait for cooldown to expire (2.5s in the .tres)
	for _step in range(50):
		_tick(0.1)

	assert_eq(_ai_brain.active_goal_id, StringName("patrol"))

	# Toggle flag off then on again → rising edge resets
	_set_flag(StringName("power_core_activated"), false)
	for _step in range(5):
		_tick(0.1)

	_set_flag(StringName("power_core_activated"), true)

	var second_investigate: bool = false
	for _step in range(30):
		_tick(0.1)
		if _ai_brain.active_goal_id == StringName("investigate"):
			second_investigate = true
			break

	assert_true(second_investigate, "Rising edge should allow investigate after flag toggles off→on")
