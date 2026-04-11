extends GutTest

const U_AI_TASK_RUNNER_PATH := "res://scripts/utils/ai/u_ai_task_runner.gd"
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/tasks/rs_ai_primitive_task.gd")
const MOCK_AI_ACTION_TRACK := preload("res://tests/mocks/mock_ai_action_track.gd")

func before_each() -> void:
	MOCK_AI_ACTION_TRACK.clear_call_log()

func after_each() -> void:
	MOCK_AI_ACTION_TRACK.clear_call_log()

func _load_runner_script() -> Script:
	var script_variant: Variant = load(U_AI_TASK_RUNNER_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % U_AI_TASK_RUNNER_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_brain() -> C_AIBrainComponent:
	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	autofree(brain)
	brain.brain_settings = RS_AI_BRAIN_SETTINGS.new()
	return brain

func _new_task(label: String, ticks_to_complete: int = 1) -> RS_AIPrimitiveTask:
	var action: Resource = MOCK_AI_ACTION_TRACK.new()
	action.set("label", label)
	action.set("ticks_to_complete", ticks_to_complete)
	var task: RS_AIPrimitiveTask = RS_AI_PRIMITIVE_TASK.new()
	task.task_id = StringName(label)
	task.action = action as I_AIAction
	return task

func _new_move_target_component() -> Variant:
	return C_MOVE_TARGET_COMPONENT.new()

func test_tick_starts_action_on_first_call() -> void:
	var runner_script: Script = _load_runner_script()
	if runner_script == null:
		return
	var runner: Variant = runner_script.new()
	var brain: C_AIBrainComponent = _new_brain()
	brain.current_task_queue = [_new_task("one", 2)]
	brain.current_task_index = 0
	brain.task_state = {}

	runner.tick(brain, 0.1, {})

	var task: RS_AIPrimitiveTask = brain.current_task_queue[0]
	var action: Resource = task.action as Resource
	assert_eq(action.get("start_calls"), 1)
	assert_eq(bool(brain.task_state.get(U_AI_TASK_STATE_KEYS.ACTION_STARTED, false)), true)

func test_tick_invokes_action_tick() -> void:
	var runner_script: Script = _load_runner_script()
	if runner_script == null:
		return
	var runner: Variant = runner_script.new()
	var brain: C_AIBrainComponent = _new_brain()
	brain.current_task_queue = [_new_task("one", 3)]
	brain.current_task_index = 0
	brain.task_state = {}

	runner.tick(brain, 0.1, {})
	runner.tick(brain, 0.1, {})

	var task: RS_AIPrimitiveTask = brain.current_task_queue[0]
	var action: Resource = task.action as Resource
	assert_eq(action.get("tick_calls"), 2)

func test_advances_on_complete() -> void:
	var runner_script: Script = _load_runner_script()
	if runner_script == null:
		return
	var runner: Variant = runner_script.new()
	var brain: C_AIBrainComponent = _new_brain()
	brain.current_task_queue = [_new_task("first", 1), _new_task("second", 5)]
	brain.current_task_index = 0
	brain.task_state = {"legacy": true}

	runner.tick(brain, 0.1, {})

	assert_eq(brain.current_task_index, 1)
	assert_true(brain.task_state.is_empty())

func test_finishes_queue_and_clears_state() -> void:
	var runner_script: Script = _load_runner_script()
	if runner_script == null:
		return
	var runner: Variant = runner_script.new()
	var brain: C_AIBrainComponent = _new_brain()
	brain.active_goal_id = &"patrol"
	brain.current_task_queue = [_new_task("one", 1)]
	brain.current_task_index = 0
	brain.task_state = {"legacy": true}

	var finished_goal_id: StringName = runner.tick(brain, 0.1, {})

	assert_eq(finished_goal_id, &"patrol")
	assert_true(brain.current_task_queue.is_empty())
	assert_eq(brain.current_task_index, 0)
	assert_true(brain.task_state.is_empty())

func test_advancing_to_next_task_deactivates_move_target_component() -> void:
	var runner_script: Script = _load_runner_script()
	if runner_script == null:
		return
	var runner: Variant = runner_script.new()
	var brain: C_AIBrainComponent = _new_brain()
	brain.current_task_queue = [_new_task("first", 1), _new_task("second", 5)]
	brain.current_task_index = 0
	brain.task_state = {"legacy": true}
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	move_target_component.set("is_active", true)
	var context: Dictionary = {
		"components": {
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}

	runner.tick(brain, 0.1, context)

	assert_eq(brain.current_task_index, 1)
	var is_active_variant: Variant = move_target_component.get("is_active")
	assert_true(is_active_variant is bool and not bool(is_active_variant))

func test_finishing_queue_deactivates_move_target_component() -> void:
	var runner_script: Script = _load_runner_script()
	if runner_script == null:
		return
	var runner: Variant = runner_script.new()
	var brain: C_AIBrainComponent = _new_brain()
	brain.active_goal_id = &"patrol"
	brain.current_task_queue = [_new_task("one", 1)]
	brain.current_task_index = 0
	brain.task_state = {"legacy": true}
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)
	move_target_component.set("is_active", true)
	var context: Dictionary = {
		"components": {
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}

	runner.tick(brain, 0.1, context)

	assert_true(brain.current_task_queue.is_empty())
	var is_active_variant: Variant = move_target_component.get("is_active")
	assert_true(is_active_variant is bool and not bool(is_active_variant))

func test_skips_invalid_primitive_tasks() -> void:
	var runner_script: Script = _load_runner_script()
	if runner_script == null:
		return
	var runner: Variant = runner_script.new()
	var brain: C_AIBrainComponent = _new_brain()
	var invalid_task: RS_AIPrimitiveTask = RS_AI_PRIMITIVE_TASK.new()
	invalid_task.task_id = &"invalid"
	var valid_task: RS_AIPrimitiveTask = _new_task("valid", 1)
	brain.current_task_queue = [invalid_task, valid_task]
	brain.current_task_index = 0
	brain.task_state = {"legacy": true}

	runner.tick(brain, 0.1, {})
	assert_eq(brain.current_task_index, 1)
	assert_true(brain.task_state.is_empty())
	assert_true(MOCK_AI_ACTION_TRACK.call_log.is_empty())
