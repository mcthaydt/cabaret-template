extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const RS_AI_GOAL := preload("res://scripts/resources/ai/rs_ai_goal.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/rs_ai_primitive_task.gd")
const RS_CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_primitive_task(task_id: StringName) -> Resource:
	var task: Resource = RS_AI_PRIMITIVE_TASK.new()
	task.set("task_id", task_id)
	return task

func _new_goal(goal_id: StringName, priority: int, score: float, task_id: StringName) -> Resource:
	var goal: Resource = RS_AI_GOAL.new()
	var condition: Resource = RS_CONDITION_CONSTANT.new()
	condition.set("score", score)
	var conditions: Array[Resource] = [condition]
	goal.set("goal_id", goal_id)
	goal.set("priority", priority)
	goal.set("conditions", conditions)
	goal.set("root_task", _new_primitive_task(task_id))
	return goal

func _create_fixture(
	goals: Array[Resource],
	default_goal_id: StringName = StringName(),
	evaluation_interval: float = 0.5
) -> Dictionary:
	var system_script: Script = _load_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	if system_script == null:
		return {}

	var store := MOCK_STATE_STORE.new()
	autofree(store)
	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BaseECSSystem, "S_AIBehaviorSystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var system: BaseECSSystem = system_variant as BaseECSSystem
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	system.configure(ecs_manager)

	var brain_settings: Resource = RS_AI_BRAIN_SETTINGS.new()
	brain_settings.set("goals", goals)
	brain_settings.set("default_goal_id", default_goal_id)
	brain_settings.set("evaluation_interval", evaluation_interval)

	var entity := Node3D.new()
	entity.name = "E_TestNPC"
	autofree(entity)

	var brain: Variant = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = brain_settings
	entity.add_child(brain)
	autofree(brain)
	ecs_manager.add_component_to_entity(entity, brain)

	return {
		"store": store,
		"ecs_manager": ecs_manager,
		"system": system,
		"entity": entity,
		"brain": brain,
	}

func test_system_extends_base_ecs_system() -> void:
	var system_script: Script = _load_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	if system_script == null:
		return
	var system_variant: Variant = system_script.new()
	if system_variant is Node:
		autofree(system_variant as Node)
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_AIBehaviorSystem should extend BaseECSSystem")

func test_selects_highest_scoring_goal() -> void:
	var low_goal: Resource = _new_goal(StringName("patrol"), 1, 0.2, StringName("patrol_task"))
	var high_goal: Resource = _new_goal(StringName("investigate"), 1, 0.9, StringName("investigate_task"))
	var fixture: Dictionary = _create_fixture([low_goal, high_goal], StringName("patrol"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]
	system.process_tick(0.016)

	assert_eq(brain.active_goal_id, StringName("investigate"))
	assert_eq(brain.current_task_queue.size(), 1)
	if brain.current_task_queue.is_empty():
		return
	var first_task: Resource = brain.current_task_queue[0] as Resource
	assert_eq(first_task.get("task_id"), StringName("investigate_task"))

func test_ties_broken_by_priority() -> void:
	var low_priority_goal: Resource = _new_goal(StringName("low"), 1, 0.8, StringName("low_task"))
	var high_priority_goal: Resource = _new_goal(StringName("high"), 5, 0.8, StringName("high_task"))
	var fixture: Dictionary = _create_fixture([low_priority_goal, high_priority_goal], StringName("low"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]
	system.process_tick(0.016)

	assert_eq(brain.active_goal_id, StringName("high"))
	assert_eq(brain.current_task_queue.size(), 1)
	if brain.current_task_queue.is_empty():
		return
	var first_task: Resource = brain.current_task_queue[0] as Resource
	assert_eq(first_task.get("task_id"), StringName("high_task"))

func test_default_goal_used_when_no_goal_passes() -> void:
	var failing_a: Resource = _new_goal(StringName("a"), 1, 0.0, StringName("a_task"))
	var failing_b: Resource = _new_goal(StringName("b"), 1, 0.0, StringName("b_task"))
	var fixture: Dictionary = _create_fixture([failing_a, failing_b], StringName("b"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]
	system.process_tick(0.016)

	assert_eq(brain.active_goal_id, StringName("b"))
	assert_eq(brain.current_task_queue.size(), 1)
	if brain.current_task_queue.is_empty():
		return
	var first_task: Resource = brain.current_task_queue[0] as Resource
	assert_eq(first_task.get("task_id"), StringName("b_task"))

func test_goal_change_clears_task_queue() -> void:
	var first_condition: Resource = RS_CONDITION_CONSTANT.new()
	first_condition.set("score", 1.0)
	var second_condition: Resource = RS_CONDITION_CONSTANT.new()
	second_condition.set("score", 0.0)

	var first_goal: Resource = RS_AI_GOAL.new()
	var first_conditions: Array[Resource] = [first_condition]
	first_goal.set("goal_id", StringName("first"))
	first_goal.set("priority", 1)
	first_goal.set("conditions", first_conditions)
	first_goal.set("root_task", _new_primitive_task(StringName("first_task")))

	var second_goal: Resource = RS_AI_GOAL.new()
	var second_conditions: Array[Resource] = [second_condition]
	second_goal.set("goal_id", StringName("second"))
	second_goal.set("priority", 1)
	second_goal.set("conditions", second_conditions)
	second_goal.set("root_task", _new_primitive_task(StringName("second_task")))

	var fixture: Dictionary = _create_fixture([first_goal, second_goal], StringName("first"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]

	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("first"))
	var stale_queue: Array[Resource] = [_new_primitive_task(StringName("stale_task"))]
	brain.current_task_queue = stale_queue
	brain.current_task_index = 1
	brain.task_state = {"started": true}

	first_condition.set("score", 0.0)
	second_condition.set("score", 1.0)
	system.process_tick(0.016)

	assert_eq(brain.active_goal_id, StringName("second"))
	assert_eq(brain.current_task_index, 0)
	assert_true(brain.task_state.is_empty())
	assert_eq(brain.current_task_queue.size(), 1)
	if brain.current_task_queue.is_empty():
		return
	var first_task: Resource = brain.current_task_queue[0] as Resource
	assert_eq(first_task.get("task_id"), StringName("second_task"))

func test_evaluation_interval_throttles_scoring() -> void:
	var first_condition: Resource = RS_CONDITION_CONSTANT.new()
	first_condition.set("score", 1.0)
	var second_condition: Resource = RS_CONDITION_CONSTANT.new()
	second_condition.set("score", 0.0)

	var first_goal: Resource = RS_AI_GOAL.new()
	var first_conditions: Array[Resource] = [first_condition]
	first_goal.set("goal_id", StringName("first"))
	first_goal.set("priority", 1)
	first_goal.set("conditions", first_conditions)
	first_goal.set("root_task", _new_primitive_task(StringName("first_task")))

	var second_goal: Resource = RS_AI_GOAL.new()
	var second_conditions: Array[Resource] = [second_condition]
	second_goal.set("goal_id", StringName("second"))
	second_goal.set("priority", 1)
	second_goal.set("conditions", second_conditions)
	second_goal.set("root_task", _new_primitive_task(StringName("second_task")))

	var fixture: Dictionary = _create_fixture([first_goal, second_goal], StringName("first"), 1.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]
	system.process_tick(0.1)
	assert_eq(brain.active_goal_id, StringName("first"))

	first_condition.set("score", 0.0)
	second_condition.set("score", 1.0)
	system.process_tick(0.1)
	assert_eq(brain.active_goal_id, StringName("first"))

	system.process_tick(1.0)
	assert_eq(brain.active_goal_id, StringName("second"))

func test_no_brain_component_no_crash() -> void:
	var system_script: Script = _load_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	if system_script == null:
		return

	var store := MOCK_STATE_STORE.new()
	autofree(store)
	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system_variant: Variant = system_script.new()
	if not (system_variant is BaseECSSystem):
		return
	var system: BaseECSSystem = system_variant as BaseECSSystem
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	system.configure(ecs_manager)

	system.process_tick(0.016)
	assert_true(true, "Processing with no C_AIBrainComponent entities should not crash")
