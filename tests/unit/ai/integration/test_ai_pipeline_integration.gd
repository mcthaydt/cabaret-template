extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const S_AI_NAVIGATION_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_navigation_system.gd"
const S_INPUT_SYSTEM_PATH := "res://scripts/ecs/systems/s_input_system.gd"
const S_MOVEMENT_SYSTEM_PATH := "res://scripts/ecs/systems/s_movement_system.gd"

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
const RS_CONDITION_REDUX_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_redux_field.gd")

const I_INPUT_SOURCE := preload("res://scripts/interfaces/i_input_source.gd")
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/managers/m_input_device_manager.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")

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

class CameraManagerStub extends I_CAMERA_MANAGER:
	var main_camera: Camera3D = null

	func get_main_camera() -> Camera3D:
		return main_camera

	func apply_main_camera_transform(_transform: Transform3D) -> void:
		pass

	func is_blend_active() -> bool:
		return false

	func initialize_scene_camera(_scene: Node) -> Camera3D:
		return null

	func finalize_blend_to_scene(_new_scene: Node) -> void:
		pass

	func apply_shake_offset(_offset: Vector2, _rotation: float) -> void:
		pass

	func set_shake_source(_source: StringName, _offset: Vector2, _rotation: float) -> void:
		pass

	func clear_shake_source(_source: StringName) -> void:
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

func _new_constant_condition(score: float) -> Resource:
	var condition: Resource = RS_CONDITION_CONSTANT.new()
	condition.set("score", score)
	return condition

func _new_redux_equals_condition(state_path: String, expected_value: String) -> Resource:
	var condition: Resource = RS_CONDITION_REDUX_FIELD.new()
	condition.set("state_path", state_path)
	condition.set("match_mode", "equals")
	condition.set("match_value_string", expected_value)
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

func _new_compound_task(task_id: StringName, subtasks: Array[Resource], method_conditions: Array[Resource] = []) -> Resource:
	var task: Resource = RS_AI_COMPOUND_TASK.new()
	task.set("task_id", task_id)
	task.set("subtasks", subtasks)
	task.set("method_conditions", method_conditions)
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

func _register_camera(camera: Camera3D) -> void:
	var camera_manager := CameraManagerStub.new()
	autofree(camera_manager)
	camera_manager.main_camera = camera
	U_SERVICE_LOCATOR.register(StringName("camera_manager"), camera_manager)

func _create_fixture(
	brain_settings: Resource,
	initial_state: Dictionary = {},
	with_camera: bool = false,
	camera_yaw: float = -PI / 2.0,
	include_movement_system: bool = false
) -> Dictionary:
	var behavior_script: Script = _load_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	var navigation_script: Script = _load_script(S_AI_NAVIGATION_SYSTEM_PATH)
	var input_script: Script = _load_script(S_INPUT_SYSTEM_PATH)
	var movement_script: Script = null
	if include_movement_system:
		movement_script = _load_script(S_MOVEMENT_SYSTEM_PATH)
	if behavior_script == null or navigation_script == null or input_script == null:
		return {}
	if include_movement_system and movement_script == null:
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
	assert_true(behavior_variant is BASE_ECS_SYSTEM, "S_AIBehaviorSystem should extend BaseECSSystem")
	if not (behavior_variant is BaseECSSystem):
		return {}
	var behavior_system: BaseECSSystem = behavior_variant as BaseECSSystem
	autofree(behavior_system)
	root.add_child(behavior_system)
	behavior_system.state_store = store
	behavior_system.ecs_manager = ecs_manager
	behavior_system.configure(ecs_manager)

	var navigation_variant: Variant = navigation_script.new()
	assert_true(navigation_variant is BASE_ECS_SYSTEM, "S_AINavigationSystem should extend BaseECSSystem")
	if not (navigation_variant is BaseECSSystem):
		return {}
	var navigation_system: BaseECSSystem = navigation_variant as BaseECSSystem
	autofree(navigation_system)
	root.add_child(navigation_system)
	navigation_system.ecs_manager = ecs_manager
	navigation_system.configure(ecs_manager)

	var input_variant: Variant = input_script.new()
	assert_true(input_variant is BASE_ECS_SYSTEM, "S_InputSystem should extend BaseECSSystem")
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

	var movement_system: BaseECSSystem = null
	if include_movement_system:
		var movement_variant: Variant = movement_script.new()
		assert_true(movement_variant is BASE_ECS_SYSTEM, "S_MovementSystem should extend BaseECSSystem")
		if not (movement_variant is BaseECSSystem):
			return {}
		movement_system = movement_variant as BaseECSSystem
		autofree(movement_system)
		root.add_child(movement_system)
		movement_system.state_store = store
		movement_system.ecs_manager = ecs_manager
		movement_system.configure(ecs_manager)

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

	var camera: Camera3D = null
	if with_camera:
		camera = Camera3D.new()
		camera.rotation = Vector3(0.0, camera_yaw, 0.0)
		autofree(camera)
		root.add_child(camera)
		_register_camera(camera)

	return {
		"root": root,
		"store": store,
		"ecs_manager": ecs_manager,
		"behavior_system": behavior_system,
			"navigation_system": navigation_system,
			"input_system": input_system,
			"movement_system": movement_system,
			"input_source": input_source,
			"ai_entity": ai_entity,
		"ai_body": ai_body,
		"ai_brain": ai_brain,
		"ai_input": ai_input,
		"player_input": player_input,
		"camera": camera,
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

func _assert_vector3_almost_eq(actual: Vector3, expected: Vector3, epsilon: float = 0.0001) -> void:
	assert_almost_eq(actual.x, expected.x, epsilon)
	assert_almost_eq(actual.y, expected.y, epsilon)
	assert_almost_eq(actual.z, expected.z, epsilon)

func test_full_pipeline_patrol_pattern() -> void:
	var target_a := Vector3(4.0, 0.0, 0.0)
	var target_b := Vector3(4.0, 0.0, 4.0)

	var patrol_subtasks: Array[Resource] = [
		_new_primitive_task(StringName("move_a"), _new_move_action(target_a, 0.25)),
		_new_primitive_task(StringName("wait_a"), _new_wait_action(0.2)),
		_new_primitive_task(StringName("move_b"), _new_move_action(target_b, 0.25)),
		_new_primitive_task(StringName("wait_b"), _new_wait_action(0.2)),
	]
	var patrol_root: Resource = _new_compound_task(StringName("patrol_root"), patrol_subtasks)
	var patrol_goal: Resource = _new_goal(
		StringName("patrol"),
		1,
		[_new_constant_condition(1.0)],
		patrol_root
	)
	var brain_settings: Resource = _new_brain_settings([patrol_goal], StringName("patrol"), 0.0)

	var fixture: Dictionary = _create_fixture(brain_settings, {}, true, -PI / 2.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var navigation: BaseECSSystem = fixture["navigation_system"] as BaseECSSystem
	var input_system: BaseECSSystem = fixture["input_system"] as BaseECSSystem
	var body: FakeBody = fixture["ai_body"] as FakeBody
	var ai_input: C_InputComponent = fixture["ai_input"] as C_InputComponent
	var player_input: C_InputComponent = fixture["player_input"] as C_InputComponent
	var brain: Variant = fixture["ai_brain"]
	var input_source: InputSourceStub = fixture["input_source"] as InputSourceStub

	body.global_position = Vector3.ZERO

	var reached_a: bool = false
	var reached_b: bool = false
	var completed: bool = false
	for step in range(240):
		behavior.process_tick(0.1)
		navigation.process_tick(0.1)
		var ai_before_input: Vector2 = ai_input.move_vector
		if step == 0:
			assert_almost_eq(ai_before_input.x, 1.0, 0.01)
			assert_almost_eq(ai_before_input.y, 0.0, 0.01)

		input_system.process_tick(0.1)
		assert_almost_eq(ai_input.move_vector.x, ai_before_input.x, 0.0001)
		assert_almost_eq(ai_input.move_vector.y, ai_before_input.y, 0.0001)

		_simulate_ai_motion(fixture, 0.1)

		if not reached_a and body.global_position.distance_to(target_a) <= 0.35:
			reached_a = true
		if reached_a and not reached_b and body.global_position.distance_to(target_b) <= 0.35:
			reached_b = true

		if brain.current_task_queue.is_empty():
			completed = true
			break

	assert_true(reached_a, "Patrol pipeline should reach waypoint A")
	assert_true(reached_b, "Patrol pipeline should reach waypoint B")
	assert_true(completed, "Patrol task queue should complete end-to-end")
	assert_true(brain.task_state.is_empty())
	assert_eq(brain.current_task_index, 0)
	assert_almost_eq(player_input.move_vector.x, input_source.move_input.x, 0.0001)
	assert_almost_eq(player_input.move_vector.y, input_source.move_input.y, 0.0001)

func test_pipeline_moves_entity_via_real_movement_system() -> void:
	var move_target := Vector3(3.0, 0.0, 0.0)
	var move_goal: Resource = _new_goal(
		StringName("move"),
		1,
		[_new_constant_condition(1.0)],
		_new_primitive_task(StringName("move_to_target"), _new_move_action(move_target, 0.2))
	)
	var brain_settings: Resource = _new_brain_settings([move_goal], StringName("move"), 0.0)

	var fixture: Dictionary = _create_fixture(brain_settings, {}, true, -PI / 2.0, true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var navigation: BaseECSSystem = fixture["navigation_system"] as BaseECSSystem
	var movement: BaseECSSystem = fixture["movement_system"] as BaseECSSystem
	var body: FakeBody = fixture["ai_body"] as FakeBody
	var brain: Variant = fixture["ai_brain"]

	body.global_position = Vector3.ZERO

	var completed: bool = false
	for _step in range(90):
		behavior.process_tick(0.1)
		navigation.process_tick(0.1)
		movement.process_tick(0.1)
		if brain.current_task_queue.is_empty():
			completed = true
			break

	assert_true(completed, "Pipeline should complete via real movement system coupling")
	assert_true(body.global_position.distance_to(move_target) <= 0.5)
	assert_true(body.global_position.x > 0.5)
	assert_almost_eq(body.global_position.z, 0.0, 0.5)

func test_goal_switch_replans_mid_queue() -> void:
	var patrol_condition: Resource = _new_constant_condition(1.0)
	var alert_condition: Resource = _new_constant_condition(0.0)

	var patrol_root: Resource = _new_compound_task(
		StringName("patrol_root"),
		[
			_new_primitive_task(StringName("patrol_move"), _new_move_action(Vector3(1.0, 0.0, 0.0), 0.2)),
			_new_primitive_task(StringName("patrol_wait"), _new_wait_action(1.0)),
			_new_primitive_task(StringName("patrol_move_2"), _new_move_action(Vector3(2.0, 0.0, 0.0), 0.2)),
		]
	)
	var alert_target := Vector3(-3.0, 0.0, 0.0)
	var alert_root: Resource = _new_compound_task(
		StringName("alert_root"),
		[
			_new_primitive_task(StringName("alert_move"), _new_move_action(alert_target, 0.2)),
			_new_primitive_task(StringName("alert_wait"), _new_wait_action(0.2)),
		]
	)

	var patrol_goal: Resource = _new_goal(
		StringName("patrol"),
		1,
		[patrol_condition],
		patrol_root
	)
	var alert_goal: Resource = _new_goal(
		StringName("alert"),
		1,
		[alert_condition],
		alert_root
	)
	var brain_settings: Resource = _new_brain_settings([patrol_goal, alert_goal], StringName("patrol"), 0.0)

	var fixture: Dictionary = _create_fixture(brain_settings)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var navigation: BaseECSSystem = fixture["navigation_system"] as BaseECSSystem
	var body: FakeBody = fixture["ai_body"] as FakeBody
	var brain: Variant = fixture["ai_brain"]
	var ai_input: C_InputComponent = fixture["ai_input"] as C_InputComponent

	body.global_position = Vector3.ZERO

	var entered_patrol_wait: bool = false
	for _step in range(60):
		behavior.process_tick(0.1)
		navigation.process_tick(0.1)
		_simulate_ai_motion(fixture, 0.1)
		if brain.active_goal_id == StringName("patrol") and brain.current_task_index == 1:
			entered_patrol_wait = true
			break

	assert_true(entered_patrol_wait, "Expected patrol goal to reach mid-queue wait before replanning")

	patrol_condition.set("score", 0.0)
	alert_condition.set("score", 1.0)

	behavior.process_tick(0.1)
	navigation.process_tick(0.1)

	assert_eq(brain.active_goal_id, StringName("alert"))
	assert_eq(brain.current_task_index, 0)
	assert_false(brain.task_state.has("elapsed"))
	assert_true(brain.task_state.has("ai_move_target"))
	var move_target_variant: Variant = brain.task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(move_target_variant is Vector3)
	if move_target_variant is Vector3:
		_assert_vector3_almost_eq(move_target_variant as Vector3, alert_target)
	assert_true(ai_input.move_vector.length() > 0.0)

func test_cooldown_prevents_goal_thrashing() -> void:
	var alpha_goal: Resource = _new_goal(
		StringName("alpha"),
		2,
		[_new_constant_condition(1.0)],
		_new_primitive_task(StringName("alpha_wait"), _new_wait_action(0.0)),
		{"cooldown": 0.3}
	)
	var beta_goal: Resource = _new_goal(
		StringName("beta"),
		1,
		[_new_constant_condition(1.0)],
		_new_primitive_task(StringName("beta_wait"), _new_wait_action(0.0))
	)
	var brain_settings: Resource = _new_brain_settings([alpha_goal, beta_goal], StringName(), 0.0)

	var fixture: Dictionary = _create_fixture(brain_settings)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var brain: Variant = fixture["ai_brain"]

	var selected_ids: Array[StringName] = []
	for _step in range(4):
		behavior.process_tick(0.1)
		selected_ids.append(brain.active_goal_id)

	assert_eq(selected_ids, [
		StringName("alpha"),
		StringName("beta"),
		StringName("beta"),
		StringName("alpha"),
	])

func test_default_goal_fallback_executes() -> void:
	var fallback_target := Vector3(2.0, 0.0, 2.0)
	var failing_goal_a: Resource = _new_goal(
		StringName("a"),
		1,
		[_new_constant_condition(0.0)],
		_new_primitive_task(StringName("a_wait"), _new_wait_action(0.3))
	)
	var fallback_goal: Resource = _new_goal(
		StringName("fallback"),
		1,
		[_new_constant_condition(0.0)],
		_new_primitive_task(StringName("fallback_move"), _new_move_action(fallback_target, 0.2))
	)
	var brain_settings: Resource = _new_brain_settings(
		[failing_goal_a, fallback_goal],
		StringName("fallback"),
		0.0
	)

	var fixture: Dictionary = _create_fixture(brain_settings)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var navigation: BaseECSSystem = fixture["navigation_system"] as BaseECSSystem
	var brain: Variant = fixture["ai_brain"]
	var ai_input: C_InputComponent = fixture["ai_input"] as C_InputComponent

	behavior.process_tick(0.1)
	navigation.process_tick(0.1)

	assert_eq(brain.active_goal_id, StringName("fallback"))
	assert_true(brain.task_state.has("ai_move_target"))
	var target_variant: Variant = brain.task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, fallback_target)
	assert_true(ai_input.move_vector.length() > 0.0)

func test_compound_method_selection_in_context() -> void:
	var high_branch_target := Vector3(5.0, 0.0, 0.0)
	var stealth_branch_target := Vector3(0.0, 0.0, -4.0)
	var root_task: Resource = _new_compound_task(
		StringName("method_root"),
		[
			_new_primitive_task(StringName("branch_high"), _new_move_action(high_branch_target, 0.2)),
			_new_primitive_task(StringName("branch_stealth"), _new_move_action(stealth_branch_target, 0.2)),
		],
		[
			_new_redux_equals_condition("gameplay.alert_mode", "high"),
			_new_redux_equals_condition("gameplay.alert_mode", "stealth"),
		]
	)
	var branch_goal: Resource = _new_goal(
		StringName("branch_goal"),
		1,
		[_new_constant_condition(1.0)],
		root_task
	)
	var brain_settings: Resource = _new_brain_settings([branch_goal], StringName("branch_goal"), 0.0)

	var fixture: Dictionary = _create_fixture(brain_settings, {
		"gameplay": {
			"alert_mode": "stealth",
		}
	})
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var behavior: BaseECSSystem = fixture["behavior_system"] as BaseECSSystem
	var navigation: BaseECSSystem = fixture["navigation_system"] as BaseECSSystem
	var brain: Variant = fixture["ai_brain"]

	behavior.process_tick(0.1)
	navigation.process_tick(0.1)

	assert_eq(brain.active_goal_id, StringName("branch_goal"))
	assert_eq(brain.current_task_queue.size(), 1)
	if brain.current_task_queue.is_empty():
		return
	var selected_task: Resource = brain.current_task_queue[0] as Resource
	assert_eq(selected_task.get("task_id"), StringName("branch_stealth"))

	var target_variant: Variant = brain.task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, stealth_branch_target)
