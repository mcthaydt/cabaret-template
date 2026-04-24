extends BaseTest

## Integration test for the AI demo in gameplay_power_core.
## Validates the patrol/investigate BT behavior using mocked ECS
## infrastructure (MockECSManager + MockStateStore).

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/demo/ecs/systems/s_ai_behavior_system.gd"
const S_MOVE_TARGET_FOLLOWER_SYSTEM_PATH := "res://scripts/demo/ecs/systems/s_move_target_follower_system.gd"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/demo/ecs/components/c_move_target_component.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/core/resources/ecs/rs_movement_settings.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

const PATROL_DRONE_BRAIN_SETTINGS := preload("res://resources/ai/patrol_drone/cfg_patrol_drone_brain.tres")

const WAYPOINT_A := Vector3(-6.0, 1.0, -6.0)
const WAYPOINT_B := Vector3(6.0, 1.0, -6.0)
const WAYPOINT_C := Vector3(6.0, 1.0, 6.0)
const WAYPOINT_D := Vector3(-6.0, 1.0, 6.0)
const FLAG_ZONE_POSITION := Vector3(4.0, 1.0, 0.0)
const DRONE_START := Vector3(-4.0, 2.5, 0.0)
const MOVE_SIMULATION_SPEED := 6.0
const ROOT_SELECTOR_ID := StringName("patrol_drone_bt_root")
const BT_ACTION_STATE_BAG_KEY := &"bt_action_state_bag"
const PATROL_TARGET_PATH := "../../Waypoints/WaypointA"
const INVESTIGATE_TARGET_PATH := "../../Interactions/Inter_ActivatableNode"

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
var _ai_move_target: C_MoveTargetComponent

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

	var navigation_script: Script = load(S_MOVE_TARGET_FOLLOWER_SYSTEM_PATH) as Script
	assert_not_null(navigation_script)
	if navigation_script == null:
		return
	_navigation_system = navigation_script.new() as BaseECSSystem
	autofree(_navigation_system)
	_root.add_child(_navigation_system)
	_navigation_system.ecs_manager = _ecs_manager
	_navigation_system.configure(_ecs_manager)

	# Scene node stubs - patrol .tres uses relative NodePaths from entity
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

	_ai_move_target = C_MOVE_TARGET_COMPONENT.new()
	_ai_entity.add_child(_ai_move_target)
	autofree(_ai_move_target)

	_ai_brain = C_AI_BRAIN_COMPONENT.new()
	_ai_brain.brain_settings = PATROL_DRONE_BRAIN_SETTINGS.duplicate(true)
	_ai_entity.add_child(_ai_brain)
	autofree(_ai_brain)

	_ecs_manager.add_component_to_entity(_ai_entity, _ai_brain)
	_ecs_manager.add_component_to_entity(_ai_entity, _ai_input)
	_ecs_manager.add_component_to_entity(_ai_entity, ai_movement)
	_ecs_manager.add_component_to_entity(_ai_entity, _ai_move_target)

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
	_ai_move_target = null

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

func _find_action_state_value(key: StringName) -> Variant:
	if _ai_brain == null:
		return null
	for node_state_variant in _ai_brain.bt_state_bag.values():
		if not (node_state_variant is Dictionary):
			continue
		var node_state: Dictionary = node_state_variant as Dictionary
		var action_state_variant: Variant = node_state.get(BT_ACTION_STATE_BAG_KEY, null)
		if not (action_state_variant is Dictionary):
			continue
		var action_state: Dictionary = action_state_variant as Dictionary
		if action_state.has(key):
			return action_state.get(key)
	return null

func _has_action_state_key(key: StringName) -> bool:
	return _find_action_state_value(key) != null

func _observe_action_key_over_ticks(key: StringName, ticks: int, delta: float) -> bool:
	for _step in range(max(ticks, 0)):
		_tick(delta)
		if _has_action_state_key(key):
			return true
	return false

func _observe_requested_path(expected_path: String, ticks: int, delta: float) -> bool:
	for _step in range(max(ticks, 0)):
		_tick(delta)
		var path_variant: Variant = _find_action_state_value(U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH)
		if str(path_variant) == expected_path:
			return true
	return false

func _wait_for_scan_cycle(ticks: int, delta: float) -> bool:
	var saw_scan_start: bool = false
	for _step in range(max(ticks, 0)):
		_tick(delta)
		var is_scanning: bool = _has_action_state_key(U_AI_TASK_STATE_KEYS.SCAN_ELAPSED)
		if is_scanning:
			saw_scan_start = true
			continue
		if saw_scan_start:
			return true
	return false

func _count_scan_starts_over_ticks(ticks: int, delta: float) -> int:
	var starts: int = 0
	var was_scanning: bool = false
	for _step in range(max(ticks, 0)):
		_tick(delta)
		var is_scanning: bool = _has_action_state_key(U_AI_TASK_STATE_KEYS.SCAN_ELAPSED)
		if is_scanning and not was_scanning:
			starts += 1
		was_scanning = is_scanning
	return starts

# ---------------------------------------------------------------
# Tests
# ---------------------------------------------------------------

func test_patrol_drone_starts_with_patrol_goal() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_tick(0.1)

	assert_eq(_ai_brain.active_goal_id, ROOT_SELECTOR_ID, "Drone should evaluate the BT root selector on start")
	assert_true(
		_observe_requested_path(PATROL_TARGET_PATH, 12, 0.1),
		"Patrol should request movement toward waypoint A when no investigate flags are set"
	)

func test_patrol_drone_moves_toward_first_waypoint() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	assert_true(
		_observe_requested_path(PATROL_TARGET_PATH, 24, 0.1),
		"First patrol action should resolve the waypoint-A node path"
	)
	assert_true(_ai_move_target.is_active, "Move target component should be active while patrol MoveTo runs")
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

	var saw_waypoint_d: bool = false
	var looped_back_to_a: bool = false

	for _step in range(1000):
		_tick(0.1)
		var requested_path_variant: Variant = _find_action_state_value(U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH)
		var requested_path: String = str(requested_path_variant)
		if requested_path == "../../Waypoints/WaypointD":
			saw_waypoint_d = true
		if saw_waypoint_d and requested_path == PATROL_TARGET_PATH:
			looped_back_to_a = true
			break

	assert_eq(_ai_brain.active_goal_id, ROOT_SELECTOR_ID, "Patrol should continue under the BT root selector")
	assert_true(saw_waypoint_d, "Patrol loop should eventually request waypoint D")
	assert_true(looped_back_to_a, "After waypoint D, patrol should loop back to waypoint A")

func test_investigate_goal_activates_on_flag() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_tick(0.1)
	assert_eq(_ai_brain.active_goal_id, ROOT_SELECTOR_ID)

	_set_flag(StringName("power_core_activated"), true)

	assert_true(
		_observe_requested_path(INVESTIGATE_TARGET_PATH, 320, 0.1),
		"Drone should route into investigate movement when power_core_activated is true"
	)

func test_investigate_produces_movement_toward_flag_zone() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	assert_true(_observe_requested_path(INVESTIGATE_TARGET_PATH, 30, 0.1))
	assert_true(_ai_input.move_vector.length() > 0.0, "Investigate branch should produce movement input")

func test_investigate_completes_full_sequence() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	var saw_investigate_move: bool = _observe_requested_path(INVESTIGATE_TARGET_PATH, 60, 0.1)
	var saw_scan: bool = _observe_action_key_over_ticks(U_AI_TASK_STATE_KEYS.SCAN_ELAPSED, 180, 0.1)
	var completed_scan_cycle: bool = _wait_for_scan_cycle(220, 0.1)
	var saw_wait: bool = _observe_action_key_over_ticks(U_AI_TASK_STATE_KEYS.ELAPSED, 120, 0.1)

	assert_true(saw_investigate_move, "Investigate should request movement toward the activatable target")
	assert_true(saw_scan, "Investigate sequence should run scan action")
	assert_true(completed_scan_cycle, "Investigate scan action should complete")
	assert_true(saw_wait, "Investigate sequence should run wait action after scan")

func test_drone_returns_to_patrol_after_investigate() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	assert_true(_wait_for_scan_cycle(260, 0.1), "Investigate scan cycle should complete")
	assert_true(
		_observe_requested_path(PATROL_TARGET_PATH, 120, 0.1),
		"Drone should return to patrol waypoint targeting after investigate completes"
	)

func test_rising_edge_prevents_re_investigate_while_flag_stays_true() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)

	assert_true(_wait_for_scan_cycle(260, 0.1), "First investigate should complete")

	# Tick enough to clear cooldown (2.5s) and verify rising-edge gate blocks
	# retrigger while the flag remains true.
	for _step in range(50):
		_tick(0.1)

	assert_true(
		_observe_requested_path(PATROL_TARGET_PATH, 100, 0.1),
		"While flag stays true, selector should fall back to patrol branch after the first investigate run"
	)
	var additional_scan_starts: int = _count_scan_starts_over_ticks(160, 0.1)
	assert_eq(additional_scan_starts, 0, "Rising edge should prevent a second investigate scan while flag remains true")

func test_rising_edge_toggle_without_gate_sampling_does_not_reinvestigate() -> void:
	if _behavior_system == null:
		fail_test("Fixture setup failed")
		return

	_set_flag(StringName("power_core_activated"), true)
	assert_true(_wait_for_scan_cycle(260, 0.1), "First investigate should complete")

	# Wait for cooldown to expire.
	for _step in range(50):
		_tick(0.1)

	# Toggle flag off long enough for the investigate branch to sample false,
	# then toggle on for a fresh rising edge.
	_set_flag(StringName("power_core_activated"), false)
	for _step in range(260):
		_tick(0.1)

	_set_flag(StringName("power_core_activated"), true)

	var saw_second_investigate_target: bool = _observe_requested_path(INVESTIGATE_TARGET_PATH, 320, 0.1)
	var second_scan_starts: int = _count_scan_starts_over_ticks(260, 0.1)

	assert_false(
		saw_second_investigate_target,
		"Investigate should not re-run after toggle when the branch never samples a false gate state."
	)
	assert_eq(
		second_scan_starts,
		0,
		"Investigate scan should not restart without a false gate tick on the investigate branch."
	)
