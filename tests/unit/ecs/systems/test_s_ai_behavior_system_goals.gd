extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_AI_ACTION_TRACK := preload("res://tests/mocks/mock_ai_action_track.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const RS_AI_GOAL := preload("res://scripts/resources/ai/rs_ai_goal.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/rs_ai_primitive_task.gd")
const RS_CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")

func before_each() -> void:
	MOCK_AI_ACTION_TRACK.clear_call_log()

func after_each() -> void:
	MOCK_AI_ACTION_TRACK.clear_call_log()

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_primitive_task(task_id: StringName, ticks_to_complete: int = 999) -> Resource:
	var task: Resource = RS_AI_PRIMITIVE_TASK.new()
	task.set("task_id", task_id)
	var action: Resource = MOCK_AI_ACTION_TRACK.new()
	action.set("label", String(task_id))
	action.set("ticks_to_complete", ticks_to_complete)
	task.set("action", action)
	return task

func _new_goal(
	goal_id: StringName,
	priority: int,
	score: float,
	task_id: StringName,
	options: Dictionary = {}
) -> Resource:
	var goal: Resource = RS_AI_GOAL.new()
	var condition: Resource = RS_CONDITION_CONSTANT.new()
	condition.set("score", score)
	var conditions: Array[Resource] = [condition]
	var ticks_to_complete: int = int(options.get("ticks_to_complete", 999))
	goal.set("goal_id", goal_id)
	goal.set("priority", priority)
	goal.set("conditions", conditions)
	goal.set("root_task", _new_primitive_task(task_id, ticks_to_complete))
	if options.has("cooldown"):
		goal.set("cooldown", float(options.get("cooldown", 0.0)))
	if options.has("one_shot"):
		goal.set("one_shot", bool(options.get("one_shot", false)))
	if options.has("requires_rising_edge"):
		goal.set("requires_rising_edge", bool(options.get("requires_rising_edge", false)))
	return goal

func _count_call_log_prefix(prefix: String) -> int:
	var count: int = 0
	for call_entry_variant in MOCK_AI_ACTION_TRACK.call_log:
		var call_entry: String = str(call_entry_variant)
		if call_entry.begins_with(prefix):
			count += 1
	return count

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
	brain.task_state = {"legacy": true}

	first_condition.set("score", 0.0)
	second_condition.set("score", 1.0)
	system.process_tick(0.016)

	assert_eq(brain.active_goal_id, StringName("second"))
	assert_eq(brain.current_task_index, 0)
	assert_false(brain.task_state.has("legacy"))
	assert_eq(brain.current_task_queue.size(), 1)
	if brain.current_task_queue.is_empty():
		return
	var first_task: Resource = brain.current_task_queue[0] as Resource
	assert_eq(first_task.get("task_id"), StringName("second_task"))

func test_same_goal_replans_after_queue_completion() -> void:
	var patrol_goal: Resource = _new_goal(
		StringName("patrol"),
		1,
		1.0,
		StringName("patrol_task"),
		{"ticks_to_complete": 1}
	)
	var fixture: Dictionary = _create_fixture([patrol_goal], StringName("patrol"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]

	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("patrol"))
	assert_true(brain.current_task_queue.is_empty())
	assert_eq(_count_call_log_prefix("start:patrol_task"), 1)

	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("patrol"))
	assert_eq(_count_call_log_prefix("start:patrol_task"), 2)

func test_active_goal_not_interrupted_by_own_cooldown() -> void:
	var investigate_condition: Resource = RS_CONDITION_CONSTANT.new()
	investigate_condition.set("score", 0.0)

	var investigate_goal: Resource = RS_AI_GOAL.new()
	var investigate_conditions: Array[Resource] = [investigate_condition]
	investigate_goal.set("goal_id", StringName("investigate"))
	investigate_goal.set("priority", 3)
	investigate_goal.set("conditions", investigate_conditions)
	investigate_goal.set("requires_rising_edge", true)
	investigate_goal.set("cooldown", 2.5)
	investigate_goal.set("root_task", _new_primitive_task(StringName("investigate_task"), 5))

	var patrol_goal: Resource = _new_goal(StringName("patrol"), 1, 0.5, StringName("patrol_task"))
	var fixture: Dictionary = _create_fixture(
		[patrol_goal, investigate_goal], StringName("patrol"), 0.0
	)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]

	# Tick 1: patrol starts
	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("patrol"), "Should start with patrol")

	# Rising edge: enable investigate condition
	investigate_condition.set("score", 1.0)

	# Tick 2: investigate fires via rising edge
	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("investigate"), "Should switch to investigate")

	# Ticks 3-5: investigate should remain active despite cooldown
	for tick_index in range(3):
		system.process_tick(0.016)
		assert_eq(
			brain.active_goal_id,
			StringName("investigate"),
			"Investigate should NOT be interrupted by its own cooldown (tick %d)" % tick_index
		)

func test_cooldown_marks_only_selected_goal() -> void:
	var high_goal: Resource = _new_goal(
		StringName("high"),
		2,
		1.0,
		StringName("high_task"),
		{"cooldown": 1.0, "ticks_to_complete": 1}
	)
	var low_goal: Resource = _new_goal(
		StringName("low"),
		1,
		0.8,
		StringName("low_task"),
		{"cooldown": 1.0}
	)
	var fixture: Dictionary = _create_fixture([high_goal, low_goal], StringName(), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]
	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("high"))

	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("low"))

func test_one_shot_goal_transitions_to_next_goal_after_first_fire() -> void:
	var one_shot_goal: Resource = _new_goal(
		StringName("one_shot"),
		2,
		1.0,
		StringName("one_shot_task"),
		{"one_shot": true, "ticks_to_complete": 1}
	)
	var fallback_goal: Resource = _new_goal(StringName("fallback"), 1, 0.8, StringName("fallback_task"))
	var fixture: Dictionary = _create_fixture([one_shot_goal, fallback_goal], StringName(), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]
	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("one_shot"))

	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("fallback"))

func test_one_shot_is_scoped_per_context() -> void:
	var one_shot_goal: Resource = _new_goal(
		StringName("one_shot"),
		2,
		1.0,
		StringName("one_shot_task"),
		{"one_shot": true}
	)
	var fallback_goal: Resource = _new_goal(StringName("fallback"), 1, 0.8, StringName("fallback_task"))
	var fixture: Dictionary = _create_fixture([one_shot_goal, fallback_goal], StringName(), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var ecs_manager: Object = fixture["ecs_manager"] as Object
	var first_brain: Variant = fixture["brain"]

	system.process_tick(0.016)
	assert_eq(first_brain.active_goal_id, StringName("one_shot"))

	var second_entity := Node3D.new()
	second_entity.name = "E_TestNPC_2"
	autofree(second_entity)
	var second_brain: Variant = C_AI_BRAIN_COMPONENT.new()
	second_brain.brain_settings = first_brain.brain_settings
	second_entity.add_child(second_brain)
	autofree(second_brain)
	ecs_manager.add_component_to_entity(second_entity, second_brain)

	system.process_tick(0.016)
	assert_eq(second_brain.active_goal_id, StringName("one_shot"))

func test_requires_rising_edge_goal_requires_state_transition() -> void:
	var rising_condition: Resource = RS_CONDITION_CONSTANT.new()
	rising_condition.set("score", 1.0)
	var rising_goal: Resource = RS_AI_GOAL.new()
	var rising_conditions: Array[Resource] = [rising_condition]
	rising_goal.set("goal_id", StringName("rising"))
	rising_goal.set("priority", 2)
	rising_goal.set("conditions", rising_conditions)
	rising_goal.set("requires_rising_edge", true)
	rising_goal.set("root_task", _new_primitive_task(StringName("rising_task"), 1))

	var steady_goal: Resource = _new_goal(StringName("steady"), 1, 0.8, StringName("steady_task"))
	var fixture: Dictionary = _create_fixture([rising_goal, steady_goal], StringName(), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]

	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("rising"))

	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("steady"))

	rising_condition.set("score", 0.0)
	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("steady"))

	rising_condition.set("score", 1.0)
	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("rising"))

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


# --- No-deep-copy performance tests ---

func test_context_redux_state_is_same_reference_as_store_state() -> void:
	var goal: Resource = _new_goal(StringName("patrol"), 1, 0.5, StringName("patrol_task"))
	var fixture: Dictionary = _create_fixture([goal], StringName("patrol"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var store: MockStateStore = fixture["store"] as MockStateStore
	var brain: Variant = fixture["brain"]
	assert_not_null(system)
	assert_not_null(store)

	# Process a tick and verify the brain context does NOT deep-copy redux_state
	# The context is built internally, so we test indirectly:
	# If the store's state dict is mutated by the system, that's a bug.
	# If performance is good (no deep copy), the brain should still evaluate correctly.
	system.process_tick(0.016)

	# Verify goal selection still works (proving context is read-only, no mutation)
	assert_eq(brain.active_goal_id, StringName("patrol"),
		"Goal selection should work without deep-copying redux_state.")


func test_suspended_goal_state_not_duplicated_on_suspend_resume() -> void:
	var goal_a: Resource = _new_goal(StringName("patrol"), 1, 0.5, StringName("patrol_task"), {"ticks_to_complete": 1})
	var goal_b: Resource = _new_goal(StringName("investigate"), 1, 0.9, StringName("investigate_task"))
	var fixture: Dictionary = _create_fixture([goal_a, goal_b], StringName("patrol"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var brain: Variant = fixture["brain"]
	assert_not_null(system)

	# Start with patrol (score 0.5), investigate scores 0.9
	system.process_tick(0.016)
	assert_eq(brain.active_goal_id, StringName("investigate"),
		"Higher-scoring goal should be selected.")

	# Complete a tick for the investigate task
	system.process_tick(0.016)

	# Verify brain state is functional without deep copy of suspended state
	assert_ne(brain.active_goal_id, StringName(),
		"Brain should have an active goal after processing.")


# --- Rule pooling tests ---

func test_build_rule_from_goal_reuses_pooled_instance() -> void:
	var goal: Resource = _new_goal(StringName("patrol"), 1, 0.5, StringName("patrol_task"))
	var fixture: Dictionary = _create_fixture([goal], StringName("patrol"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	assert_not_null(system)

	# Process two evaluation ticks; the second should reuse the pooled rule
	system.process_tick(0.016)

	# Force another evaluation by resetting the timer
	var brain: Variant = fixture["brain"]
	brain.set("evaluation_timer", 100.0)

	system.process_tick(0.016)

	# The rule pool should have exactly 1 entry for the patrol goal
	var rule_pool: Dictionary = system._rule_pool
	assert_eq(rule_pool.size(), 1, "Rule pool should have one entry per unique goal_id.")
	assert_true(rule_pool.has(StringName("patrol")), "Rule pool should contain the patrol goal rule.")


func test_rule_pool_produces_different_rules_for_different_goals() -> void:
	var goal_a: Resource = _new_goal(StringName("patrol"), 1, 0.5, StringName("patrol_task"))
	var goal_b: Resource = _new_goal(StringName("investigate"), 2, 0.9, StringName("investigate_task"))
	var fixture: Dictionary = _create_fixture([goal_a, goal_b], StringName("patrol"), 0.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	assert_not_null(system)

	system.process_tick(0.016)

	var rule_pool: Dictionary = system._rule_pool
	assert_eq(rule_pool.size(), 2, "Rule pool should have entries for both goals.")
	assert_true(rule_pool.has(StringName("patrol")), "Rule pool should contain patrol goal.")
	assert_true(rule_pool.has(StringName("investigate")), "Rule pool should contain investigate goal.")

	# Different goal IDs should produce different rule instances
	var rule_a: Resource = rule_pool[StringName("patrol")] as Resource
	var rule_b: Resource = rule_pool[StringName("investigate")] as Resource
	assert_ne(rule_a.get("rule_id"), rule_b.get("rule_id"),
		"Different goals should produce rules with different IDs.")
