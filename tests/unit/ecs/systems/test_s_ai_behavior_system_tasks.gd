extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_AI_ACTION_TRACK := preload("res://tests/mocks/mock_ai_action_track.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_AI_TASK := preload("res://scripts/resources/ai/rs_ai_task.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/rs_ai_primitive_task.gd")

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

func _new_action(label: String, ticks_to_complete: int = 1) -> Resource:
	var action: Resource = MOCK_AI_ACTION_TRACK.new()
	action.set("label", label)
	action.set("ticks_to_complete", ticks_to_complete)
	return action

func _new_primitive_task(task_id: StringName, action: Resource) -> Resource:
	var task: Resource = RS_AI_PRIMITIVE_TASK.new()
	task.set("task_id", task_id)
	task.set("action", action)
	return task

func _create_fixture(evaluation_interval: float = 1.0) -> Dictionary:
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
	brain_settings.set("goals", [])
	brain_settings.set("default_goal_id", StringName())
	brain_settings.set("evaluation_interval", evaluation_interval)

	var entity := Node3D.new()
	entity.name = "E_TestNPC"
	autofree(entity)

	var brain: Variant = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = brain_settings
	brain.active_goal_id = StringName("existing_goal")
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

func test_task_runner_dispatches_via_i_ai_action() -> void:
	var fixture: Dictionary = _create_fixture(1.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var action: Resource = _new_action("one", 2)
	var brain: Variant = fixture["brain"]
	var queue: Array[Resource] = [_new_primitive_task(StringName("task_0"), action)]
	brain.current_task_queue = queue
	brain.current_task_index = 0
	brain.task_state = {}

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	system.process_tick(0.1)

	assert_eq(action.get("start_calls"), 1)
	assert_eq(action.get("tick_calls"), 1)
	var complete_checks_variant: Variant = action.get("complete_checks")
	var complete_checks: int = int(complete_checks_variant) if complete_checks_variant is int else 0
	assert_true(complete_checks >= 1)

func test_task_queue_advances_sequentially() -> void:
	var fixture: Dictionary = _create_fixture(1.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var first_action: Resource = _new_action("first", 1)
	var second_action: Resource = _new_action("second", 1)

	var brain: Variant = fixture["brain"]
	var queue: Array[Resource] = [
		_new_primitive_task(StringName("task_first"), first_action),
		_new_primitive_task(StringName("task_second"), second_action),
	]
	brain.current_task_queue = queue
	brain.current_task_index = 0
	brain.task_state = {}

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	system.process_tick(0.1)
	system.process_tick(0.1)

	assert_eq(MOCK_AI_ACTION_TRACK.call_log, ["start:first", "tick:first", "start:second", "tick:second"])

func test_task_queue_completion_resets_state() -> void:
	var fixture: Dictionary = _create_fixture(1.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var action: Resource = _new_action("one", 1)
	var brain: Variant = fixture["brain"]
	var queue: Array[Resource] = [_new_primitive_task(StringName("task_0"), action)]
	brain.current_task_queue = queue
	brain.current_task_index = 0
	brain.task_state = {"legacy": true}

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	system.process_tick(0.1)

	assert_eq(brain.current_task_index, 0)
	assert_true(brain.current_task_queue.is_empty())
	assert_true(brain.task_state.is_empty())

func test_empty_queue_does_nothing() -> void:
	var fixture: Dictionary = _create_fixture(1.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var brain: Variant = fixture["brain"]
	var empty_queue: Array[Resource] = []
	brain.current_task_queue = empty_queue
	brain.current_task_index = 3
	brain.task_state = {"keep": true}

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	system.process_tick(0.1)

	assert_eq(brain.current_task_index, 3)
	assert_eq(brain.task_state.get("keep", false), true)

func test_invalid_queue_entry_is_skipped_instead_of_stalling() -> void:
	var fixture: Dictionary = _create_fixture(1.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var invalid_task: Resource = RS_AI_TASK.new()
	invalid_task.set("task_id", StringName("invalid"))
	var valid_action: Resource = _new_action("valid", 1)
	var valid_task: Resource = _new_primitive_task(StringName("valid_task"), valid_action)

	var brain: Variant = fixture["brain"]
	var queue: Array[Resource] = [invalid_task, valid_task]
	brain.current_task_queue = queue
	brain.current_task_index = 0
	brain.task_state = {"legacy": true}

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	system.process_tick(0.1)
	assert_eq(brain.current_task_index, 1)
	assert_true(brain.task_state.is_empty())

	system.process_tick(0.1)
	assert_eq(MOCK_AI_ACTION_TRACK.call_log, ["start:valid", "tick:valid"])

func test_primitive_task_without_action_is_skipped_instead_of_stalling() -> void:
	var fixture: Dictionary = _create_fixture(1.0)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var invalid_primitive: Resource = RS_AI_PRIMITIVE_TASK.new()
	invalid_primitive.set("task_id", StringName("missing_action"))
	var valid_action: Resource = _new_action("second", 1)
	var valid_task: Resource = _new_primitive_task(StringName("second_task"), valid_action)

	var brain: Variant = fixture["brain"]
	var queue: Array[Resource] = [invalid_primitive, valid_task]
	brain.current_task_queue = queue
	brain.current_task_index = 0
	brain.task_state = {"legacy": true}

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	system.process_tick(0.1)
	assert_eq(brain.current_task_index, 1)
	assert_true(brain.task_state.is_empty())

	system.process_tick(0.1)
	assert_eq(MOCK_AI_ACTION_TRACK.call_log, ["start:second", "tick:second"])
