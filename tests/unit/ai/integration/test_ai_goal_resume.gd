extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const S_AI_NAVIGATION_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_navigation_system.gd"
const S_INPUT_SYSTEM_PATH := "res://scripts/ecs/systems/s_input_system.gd"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")

const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_AI_GOAL := preload("res://scripts/resources/ai/rs_ai_goal.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/rs_ai_primitive_task.gd")
const RS_AI_COMPOUND_TASK := preload("res://scripts/resources/ai/rs_ai_compound_task.gd")
const RS_AI_ACTION_MOVE_TO := preload("res://scripts/resources/ai/actions/rs_ai_action_move_to.gd")
const RS_AI_ACTION_WAIT := preload("res://scripts/resources/ai/actions/rs_ai_action_wait.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const RS_CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")

const I_INPUT_SOURCE := preload("res://scripts/interfaces/i_input_source.gd")
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/managers/m_input_device_manager.gd")

const MOVE_SIMULATION_SPEED := 4.0

class FakeBody extends CharacterBody3D:
	pass

class InputSourceStub extends I_INPUT_SOURCE:
	var move_input: Vector2 = Vector2.ZERO
	var look_input: Vector2 = Vector2.ZERO

	func capture_input(_delta: float) -> Dictionary:
		return {
			"move_input": move_input,
			"look_input": look_input,
			"camera_center_just_pressed": false,
			"jump_pressed": false,
			"jump_just_pressed": false,
			"sprint_pressed": false,
			"device_id": -1,
		}

class InputDeviceManagerStub extends M_INPUT_DEVICE_MANAGER:
	var source: I_InputSource = null

	func get_input_source_for_device(_device_type: int) -> I_InputSource:
		return source

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

func _new_constant_condition(score: float) -> Resource:
	var condition: Resource = RS_CONDITION_CONSTANT.new()
	condition.set("score", score)
	return condition

func _new_move_action(target: Vector3, threshold: float = 0.2) -> Resource:
	var action: Resource = RS_AI_ACTION_MOVE_TO.new()
	action.set("target_position", target)
	action.set("arrival_threshold", threshold)
	return action

func _new_wait_action(duration: float) -> Resource:
	var action: Resource = RS_AI_ACTION_WAIT.new()
	action.set("duration", duration)
	return action

func _new_primitive_task(task_id: StringName, action: Resource) -> Resource:
	var task: Resource = RS_AI_PRIMITIVE_TASK.new()
	task.set("task_id", task_id)
	task.set("action", action)
	return task

func _new_compound_task(task_id: StringName, subtasks: Array[Resource]) -> Resource:
	var task: Resource = RS_AI_COMPOUND_TASK.new()
	task.set("task_id", task_id)
	task.set("subtasks", subtasks)
	return task

func _new_goal(
	goal_id: StringName,
	priority: int,
	conditions: Array[Resource],
	root_task: Resource,
	options: Dictionary = {}
) -> Resource:
	var goal: Resource = RS_AI_GOAL.new()
	goal.set("goal_id", goal_id)
	goal.set("priority", priority)
	goal.set("conditions", conditions)
	goal.set("root_task", root_task)
	if options.has("cooldown"):
		goal.set("cooldown", float(options.get("cooldown", 0.0)))
	if options.has("one_shot"):
		goal.set("one_shot", bool(options.get("one_shot", false)))
	if options.has("requires_rising_edge"):
		goal.set("requires_rising_edge", bool(options.get("requires_rising_edge", false)))
	return goal

func _new_brain_settings(
	goals: Array[Resource],
	default_goal_id: StringName = StringName(),
	evaluation_interval: float = 0.0
) -> Resource:
	var brain_settings: Resource = RS_AI_BRAIN_SETTINGS.new()
	brain_settings.set("goals", goals)
	brain_settings.set("default_goal_id", default_goal_id)
	brain_settings.set("evaluation_interval", evaluation_interval)
	return brain_settings

func _create_fixture(
	brain_settings: Resource,
	initial_state: Dictionary = {}
) -> Dictionary:
	var behavior_script: Script = _load_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	var navigation_script: Script = _load_script(S_AI_NAVIGATION_SYSTEM_PATH)
	var input_script: Script = _load_script(S_INPUT_SYSTEM_PATH)
	if behavior_script == null or navigation_script == null or input_script == null:
		return {}

	var store := MOCK_STATE_STORE.new()
	autofree(store)
	for slice_name_variant in initial_state.keys():
		var slice_name: StringName = StringName(str(slice_name_variant))
		var slice_data_variant: Variant = initial_state.get(slice_name_variant, {})
		if slice_data_variant is Dictionary:
			store.set_slice(slice_name, slice_data_variant as Dictionary)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var root := Node3D.new()
	add_child_autofree(root)

	var behavior_variant: Variant = behavior_script.new()
	if not (behavior_variant is BaseECSSystem):
		return {}
	var behavior_system: BaseECSSystem = behavior_variant as BaseECSSystem
	autofree(behavior_system)
	root.add_child(behavior_system)
	behavior_system.state_store = store
	behavior_system.ecs_manager = ecs_manager
	behavior_system.configure(ecs_manager)

	var navigation_variant: Variant = navigation_script.new()
	if not (navigation_variant is BaseECSSystem):
		return {}
	var navigation_system: BaseECSSystem = navigation_variant as BaseECSSystem
	autofree(navigation_system)
	root.add_child(navigation_system)
	navigation_system.ecs_manager = ecs_manager
	navigation_system.configure(ecs_manager)

	var input_variant: Variant = input_script.new()
	if not (input_variant is BaseECSSystem):
		return {}
	var input_system: BaseECSSystem = input_variant as BaseECSSystem
	autofree(input_system)
	root.add_child(input_system)
	input_system.state_store = store
	input_system.ecs_manager = ecs_manager
	input_system.set("_manager", ecs_manager)
	input_system.set("_actions_validated", true)
	input_system.set("_actions_valid", true)

	var input_source := InputSourceStub.new()
	input_source.move_input = Vector2(0.6, -0.2)
	var input_device_manager := InputDeviceManagerStub.new()
	autofree(input_device_manager)
	input_device_manager.source = input_source
	input_system.set("_input_device_manager", input_device_manager)

	var ai_entity := Node3D.new()
	ai_entity.name = "E_AIAgent"
	autofree(ai_entity)
	root.add_child(ai_entity)
	var ai_body := FakeBody.new()
	ai_entity.add_child(ai_body)
	autofree(ai_body)
	var ai_movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	ai_movement.settings = RS_MOVEMENT_SETTINGS.new()
	ai_entity.add_child(ai_movement)
	autofree(ai_movement)
	var ai_input: C_InputComponent = C_INPUT_COMPONENT.new()
	ai_entity.add_child(ai_input)
	autofree(ai_input)
	var ai_brain: Variant = C_AI_BRAIN_COMPONENT.new()
	ai_brain.brain_settings = brain_settings
	ai_entity.add_child(ai_brain)
	autofree(ai_brain)

	ecs_manager.add_component_to_entity(ai_entity, ai_brain)
	ecs_manager.add_component_to_entity(ai_entity, ai_input)
	ecs_manager.add_component_to_entity(ai_entity, ai_movement)

	var player_entity := Node3D.new()
	player_entity.name = "E_Player"
	autofree(player_entity)
	root.add_child(player_entity)
	var player_input: C_InputComponent = C_INPUT_COMPONENT.new()
	player_entity.add_child(player_input)
	autofree(player_input)
	var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)
	autofree(player_tag)
	ecs_manager.add_component_to_entity(player_entity, player_input)
	ecs_manager.add_component_to_entity(player_entity, player_tag)

	return {
		"root": root,
		"store": store,
		"ecs_manager": ecs_manager,
		"behavior_system": behavior_system,
		"navigation_system": navigation_system,
		"input_system": input_system,
		"ai_entity": ai_entity,
		"ai_body": ai_body,
		"ai_brain": ai_brain,
		"ai_input": ai_input,
	}

func _simulate_ai_motion(fixture: Dictionary, delta: float) -> void:
	var body: FakeBody = fixture.get("ai_body", null) as FakeBody
	var ai_input: C_InputComponent = fixture.get("ai_input", null) as C_InputComponent
	if body == null or ai_input == null:
		return
	var move_vector: Vector2 = ai_input.move_vector
	if move_vector.length() <= 0.0001:
		return
	var unclamped := Vector2(move_vector.x, move_vector.y)
	if unclamped.length() > 1.0:
		unclamped = unclamped.normalized()
	var desired_velocity := Vector3(unclamped.x, 0.0, unclamped.y) * MOVE_SIMULATION_SPEED
	body.global_position += desired_velocity * maxf(delta, 0.0)

# --- Tests ---

func test_resume_patrol_after_interrupt_at_saved_index() -> void:
	var target_a := Vector3(4.0, 0.0, 0.0)
	var target_b := Vector3(4.0, 0.0, 4.0)
	var target_c := Vector3(0.0, 0.0, 4.0)

	var patrol_subtasks: Array[Resource] = [
		_new_primitive_task(StringName("move_a"), _new_move_action(target_a, 0.25)),
		_new_primitive_task(StringName("wait_a"), _new_wait_action(0.2)),
		_new_primitive_task(StringName("move_b"), _new_move_action(target_b, 0.25)),
		_new_primitive_task(StringName("wait_b"), _new_wait_action(0.2)),
		_new_primitive_task(StringName("move_c"), _new_move_action(target_c, 0.25)),
		_new_primitive_task(StringName("wait_c"), _new_wait_action(0.2)),
	]
	var patrol_root: Resource = _new_compound_task(StringName("patrol_root"), patrol_subtasks)

	var patrol_condition: Resource = _new_constant_condition(1.0)
	var interrupt_condition: Resource = _new_constant_condition(0.0)

	var interrupt_root: Resource = _new_primitive_task(
		StringName("interrupt_wait"), _new_wait_action(0.3)
	)

	var patrol_goal: Resource = _new_goal(
		StringName("patrol"), 1, [patrol_condition], patrol_root
	)
	var interrupt_goal: Resource = _new_goal(
		StringName("interrupt"), 3, [interrupt_condition], interrupt_root
	)

	var brain_settings: Resource = _new_brain_settings(
		[patrol_goal, interrupt_goal], StringName("patrol"), 0.0
	)

	var fixture: Dictionary = _create_fixture(brain_settings)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var navigation: BaseECSSystem = fixture["navigation_system"] as BaseECSSystem
	var body: FakeBody = fixture["ai_body"] as FakeBody
	var brain: Variant = fixture["ai_brain"]

	body.global_position = Vector3.ZERO

	# Step 1: Run patrol until we reach task_index 2 (move_b)
	var reached_move_b: bool = false
	for _step in range(120):
		behavior.process_tick(0.1)
		navigation.process_tick(0.1)
		_simulate_ai_motion(fixture, 0.1)
		if brain.active_goal_id == StringName("patrol") and brain.current_task_index >= 2:
			reached_move_b = true
			break

	assert_true(reached_move_b, "Patrol should reach at least task_index 2 (move_b)")
	var interrupted_index: int = brain.current_task_index

	# Step 2: Trigger interrupt goal (higher priority)
	interrupt_condition.set("score", 1.0)
	behavior.process_tick(0.1)

	assert_eq(brain.active_goal_id, StringName("interrupt"),
		"Should switch to interrupt goal")

	# Step 3: Complete the interrupt goal
	for _step in range(10):
		behavior.process_tick(0.1)
		if brain.current_task_queue.is_empty():
			break

	# Step 4: Disable interrupt so patrol wins again
	interrupt_condition.set("score", 0.0)
	behavior.process_tick(0.1)

	assert_eq(brain.active_goal_id, StringName("patrol"),
		"Should return to patrol goal")
	assert_eq(brain.current_task_index, interrupted_index,
		"Should resume patrol at the task index where it was interrupted")


func test_no_resume_when_goal_completes_normally() -> void:
	var patrol_subtasks: Array[Resource] = [
		_new_primitive_task(StringName("wait_a"), _new_wait_action(0.5)),
		_new_primitive_task(StringName("wait_b"), _new_wait_action(0.5)),
		_new_primitive_task(StringName("wait_c"), _new_wait_action(0.5)),
	]
	var patrol_root: Resource = _new_compound_task(StringName("patrol_root"), patrol_subtasks)
	var patrol_goal: Resource = _new_goal(
		StringName("patrol"), 1, [_new_constant_condition(1.0)], patrol_root
	)

	var brain_settings: Resource = _new_brain_settings(
		[patrol_goal], StringName("patrol"), 0.0
	)

	var fixture: Dictionary = _create_fixture(brain_settings)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var brain: Variant = fixture["ai_brain"]

	# Run until patrol completes
	for _step in range(60):
		behavior.process_tick(0.1)
		if brain.current_task_queue.is_empty():
			break

	assert_true(brain.current_task_queue.is_empty(),
		"Patrol should complete normally")

	# Re-evaluate with small delta so first task doesn't complete in same tick
	behavior.process_tick(0.01)

	assert_eq(brain.active_goal_id, StringName("patrol"))
	assert_eq(brain.current_task_index, 0,
		"Completed goal should restart from index 0, not resume")


func test_suspended_state_cleared_after_resume() -> void:
	var patrol_subtasks: Array[Resource] = [
		_new_primitive_task(StringName("wait_a"), _new_wait_action(0.5)),
		_new_primitive_task(StringName("wait_b"), _new_wait_action(0.5)),
	]
	var patrol_root: Resource = _new_compound_task(StringName("patrol_root"), patrol_subtasks)

	var patrol_condition: Resource = _new_constant_condition(1.0)
	var interrupt_condition: Resource = _new_constant_condition(0.0)

	var interrupt_root: Resource = _new_primitive_task(
		StringName("interrupt_wait"), _new_wait_action(0.5)
	)

	var patrol_goal: Resource = _new_goal(
		StringName("patrol"), 1, [patrol_condition], patrol_root
	)
	var interrupt_goal: Resource = _new_goal(
		StringName("interrupt"), 3, [interrupt_condition], interrupt_root
	)

	var brain_settings: Resource = _new_brain_settings(
		[patrol_goal, interrupt_goal], StringName("patrol"), 0.0
	)

	var fixture: Dictionary = _create_fixture(brain_settings)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var brain: Variant = fixture["ai_brain"]

	# Run patrol until we reach wait_b (index 1)
	for _step in range(30):
		behavior.process_tick(0.1)
		if brain.active_goal_id == StringName("patrol") and brain.current_task_index >= 1:
			break
	assert_eq(brain.current_task_index, 1, "Should reach task index 1")

	# Trigger interrupt
	interrupt_condition.set("score", 1.0)
	behavior.process_tick(0.1)
	assert_eq(brain.active_goal_id, StringName("interrupt"))

	# Complete interrupt and return to patrol
	for _step in range(20):
		behavior.process_tick(0.1)
		if brain.current_task_queue.is_empty():
			break
	interrupt_condition.set("score", 0.0)
	behavior.process_tick(0.01)
	assert_eq(brain.active_goal_id, StringName("patrol"),
		"Should resume patrol")
	assert_eq(brain.current_task_index, 1,
		"Should resume at suspended index")

	# Now let patrol complete normally
	for _step in range(30):
		behavior.process_tick(0.1)
		if brain.current_task_queue.is_empty():
			break
	assert_true(brain.current_task_queue.is_empty(),
		"Patrol should complete normally")

	# Trigger interrupt again
	interrupt_condition.set("score", 1.0)
	behavior.process_tick(0.1)

	# Complete and return
	for _step in range(20):
		behavior.process_tick(0.1)
		if brain.current_task_queue.is_empty():
			break
	interrupt_condition.set("score", 0.0)
	behavior.process_tick(0.01)

	assert_eq(brain.active_goal_id, StringName("patrol"))
	assert_eq(brain.current_task_index, 0,
		"After patrol completed normally, second resume should start fresh at 0")
