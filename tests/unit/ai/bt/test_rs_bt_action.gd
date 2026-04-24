extends GutTest

const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"
const RS_BT_ACTION_PATH := "res://scripts/core/resources/ai/bt/rs_bt_action.gd"
const TEST_COUNTING_ACTION_PATH := "res://tests/unit/ai/bt/helpers/test_bt_counting_action.gd"
const U_AI_TASK_STATE_KEYS_PATH := "res://scripts/utils/ai/u_ai_task_state_keys.gd"

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to load: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _status(name: String) -> int:
	var node_script: Script = _load_script(RS_BT_NODE_PATH)
	if node_script == null:
		return -1
	var status_enum: Variant = node_script.get("Status")
	if not (status_enum is Dictionary):
		return -1
	return int((status_enum as Dictionary).get(name, -1))

func _new_bt_action(action: Resource) -> Resource:
	var bt_action_script: Script = _load_script(RS_BT_ACTION_PATH)
	if bt_action_script == null:
		return null
	var bt_action_variant: Variant = bt_action_script.new()
	assert_not_null(bt_action_variant, "Expected RS_BTAction.new() to succeed")
	if bt_action_variant == null:
		return null
	var bt_action: Resource = bt_action_variant as Resource
	bt_action.set("action", action)
	return bt_action

func _new_counting_action(ticks_until_complete: int) -> Resource:
	var action_script: Script = _load_script(TEST_COUNTING_ACTION_PATH)
	if action_script == null:
		return null
	var action_variant: Variant = action_script.new()
	assert_not_null(action_variant, "Expected counting action test helper to instantiate")
	if action_variant == null:
		return null
	var action: Resource = action_variant as Resource
	action.set("ticks_until_complete", ticks_until_complete)
	return action

func test_action_script_exists_and_loads() -> void:
	var bt_action_script: Script = _load_script(RS_BT_ACTION_PATH)
	assert_not_null(bt_action_script, "RS_BTAction script must exist and load")

func test_action_returns_running_while_incomplete_and_starts_once() -> void:
	var action: Resource = _new_counting_action(2)
	if action == null:
		return
	var bt_action: Resource = _new_bt_action(action)
	if bt_action == null:
		return

	var state_bag: Dictionary = {}
	var status: Variant = bt_action.call("tick", {}, state_bag)
	assert_eq(status, _status("RUNNING"), "Incomplete action should return RUNNING")
	assert_eq(action.get("start_count"), 1, "Action.start should be called on first tick only")
	assert_eq(action.get("tick_count"), 1, "Action.tick should run on first tick")
	assert_eq(action.get("is_complete_count"), 1, "Action.is_complete should be polled each tick")
	assert_true(bool(action.get("last_tick_saw_action_started")), "ACTION_STARTED should be set before action.tick")

func test_action_completes_and_clears_local_state() -> void:
	var action: Resource = _new_counting_action(2)
	if action == null:
		return
	var bt_action: Resource = _new_bt_action(action)
	if bt_action == null:
		return

	var bt_action_script: Script = _load_script(RS_BT_ACTION_PATH)
	var keys_script: Script = _load_script(U_AI_TASK_STATE_KEYS_PATH)
	if bt_action_script == null or keys_script == null:
		return

	var state_bag: Dictionary = {}
	var first_status: Variant = bt_action.call("tick", {}, state_bag)
	assert_eq(first_status, _status("RUNNING"))
	var node_id: int = int(bt_action.get("node_id"))
	assert_true(state_bag.has(node_id), "Running action should persist local state in state bag")

	var local_state: Dictionary = state_bag.get(node_id, {}) as Dictionary
	var bag_key: StringName = bt_action_script.get("BT_ACTION_STATE_BAG")
	assert_true(local_state.has(bag_key), "Local state should store nested task-state bag")
	var task_state: Dictionary = local_state.get(bag_key, {}) as Dictionary
	assert_true(
		bool(task_state.get(keys_script.get("ACTION_STARTED"), false)),
		"Task state bag should include ACTION_STARTED after first start() call"
	)

	var second_status: Variant = bt_action.call("tick", {}, state_bag)
	assert_eq(second_status, _status("SUCCESS"), "Action should return SUCCESS when complete")
	assert_eq(action.get("start_count"), 1, "Action.start should not repeat while action is running")
	assert_eq(action.get("tick_count"), 2, "Action.tick should run again on second frame")
	assert_eq(action.get("is_complete_count"), 2, "Action.is_complete should be called on completion frame")
	assert_false(state_bag.has(node_id), "Completed action should clear local state from state bag")

func test_action_restarts_after_successful_completion() -> void:
	var action: Resource = _new_counting_action(2)
	if action == null:
		return
	var bt_action: Resource = _new_bt_action(action)
	if bt_action == null:
		return

	var state_bag: Dictionary = {}
	var first_status: Variant = bt_action.call("tick", {}, state_bag)
	assert_eq(first_status, _status("RUNNING"))
	var second_status: Variant = bt_action.call("tick", {}, state_bag)
	assert_eq(second_status, _status("SUCCESS"))
	var third_status: Variant = bt_action.call("tick", {}, state_bag)
	assert_eq(third_status, _status("RUNNING"), "Action should restart after previous completion")

	assert_eq(action.get("start_count"), 2, "Action.start should run again after state reset")
	assert_eq(action.get("tick_count"), 3, "Third entry should perform a fresh first tick")
	assert_eq(action.get("is_complete_count"), 3, "Action.is_complete should continue polling on each tick")
