extends GutTest

const U_BT_RUNNER_PATH := "res://scripts/core/utils/bt/u_bt_runner.gd"
const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"
const RS_BT_ACTION_PATH := "res://scripts/core/resources/ai/bt/rs_bt_action.gd"
const RS_BT_SEQUENCE_PATH := "res://scripts/core/resources/bt/rs_bt_sequence.gd"
const TEST_STATUS_NODE_PATH := "res://tests/unit/ai/bt/helpers/test_bt_status_node.gd"
const TEST_COUNTING_ACTION_PATH := "res://tests/unit/ai/bt/helpers/test_bt_counting_action.gd"

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

func _new_runner() -> Object:
	var runner_script: Script = _load_script(U_BT_RUNNER_PATH)
	if runner_script == null:
		return null
	var runner_variant: Variant = runner_script.new()
	assert_not_null(runner_variant, "Expected U_BTRunner.new() to succeed")
	if runner_variant == null or not (runner_variant is Object):
		return null
	return runner_variant as Object

func _new_status_node(status: int) -> Resource:
	var node_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if node_script == null:
		return null
	var node_variant: Variant = node_script.new(status)
	assert_not_null(node_variant, "Expected status node helper to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func _new_counting_action(ticks_until_complete: int) -> Resource:
	var action_script: Script = _load_script(TEST_COUNTING_ACTION_PATH)
	if action_script == null:
		return null
	var action_variant: Variant = action_script.new()
	assert_not_null(action_variant, "Expected counting action helper to instantiate")
	if action_variant == null:
		return null
	var action: Resource = action_variant as Resource
	action.set("ticks_until_complete", ticks_until_complete)
	return action

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

func _new_sequence(children: Array) -> Resource:
	var sequence_script: Script = _load_script(RS_BT_SEQUENCE_PATH)
	if sequence_script == null:
		return null
	var sequence_variant: Variant = sequence_script.new()
	assert_not_null(sequence_variant, "Expected RS_BTSequence.new() to succeed")
	if sequence_variant == null:
		return null
	var sequence: Resource = sequence_variant as Resource
	var coerced_children: Variant = sequence.call("_coerce_children", children)
	sequence.set("_children", coerced_children)
	return sequence

func test_runner_script_exists_and_loads() -> void:
	var runner_script: Script = _load_script(U_BT_RUNNER_PATH)
	assert_not_null(runner_script, "U_BTRunner script must exist and load")

func test_tick_delegates_to_root_and_returns_status() -> void:
	var runner: Object = _new_runner()
	if runner == null:
		return
	var root: Resource = _new_status_node(_status("SUCCESS"))
	if root == null:
		return

	var state_bag: Dictionary = {}
	var status: Variant = runner.call("tick", root, {}, state_bag)
	assert_eq(status, _status("SUCCESS"), "Runner should return root tick status")
	assert_eq(root.get("tick_count"), 1, "Runner should tick root exactly once")

func test_tick_uses_node_id_integer_keys_for_state_bag() -> void:
	var runner: Object = _new_runner()
	if runner == null:
		return
	var counting_action: Resource = _new_counting_action(3)
	if counting_action == null:
		return
	var bt_action: Resource = _new_bt_action(counting_action)
	if bt_action == null:
		return
	var root: Resource = _new_sequence([bt_action])
	if root == null:
		return

	var state_bag: Dictionary = {}
	var status: Variant = runner.call("tick", root, {"delta": 0.016}, state_bag)
	assert_eq(status, _status("RUNNING"), "Runner should surface RUNNING while action remains incomplete")
	assert_false(state_bag.is_empty(), "Running tree should persist per-node state in bag")
	for key_variant in state_bag.keys():
		assert_true(key_variant is int, "State bag keys should be integer node instance IDs")
	assert_true(state_bag.has(root.get("node_id")), "State bag should include root node state")
	assert_true(state_bag.has(bt_action.get("node_id")), "State bag should include leaf node state")

func test_tick_action_lifecycle_restarts_after_parent_success() -> void:
	var runner: Object = _new_runner()
	if runner == null:
		return
	var counting_action: Resource = _new_counting_action(2)
	if counting_action == null:
		return
	var bt_action: Resource = _new_bt_action(counting_action)
	var trailing_success: Resource = _new_status_node(_status("SUCCESS"))
	if bt_action == null or trailing_success == null:
		return
	var root: Resource = _new_sequence([bt_action, trailing_success])
	if root == null:
		return

	var state_bag: Dictionary = {}

	var tick1: Variant = runner.call("tick", root, {"delta": 0.016}, state_bag)
	assert_eq(tick1, _status("RUNNING"), "First tick should enter action and report RUNNING")
	assert_eq(counting_action.get("start_count"), 1, "Action.start should run once on first entry")
	assert_eq(counting_action.get("tick_count"), 1, "Action.tick should run on first entry")
	assert_eq(trailing_success.get("tick_count"), 0, "Sequence should not continue past running action")

	var tick2: Variant = runner.call("tick", root, {"delta": 0.016}, state_bag)
	assert_eq(tick2, _status("SUCCESS"), "Second tick should complete sequence")
	assert_eq(counting_action.get("start_count"), 1, "Running action should not restart before completion")
	assert_eq(counting_action.get("tick_count"), 2, "Action should tick again on completion frame")
	assert_eq(trailing_success.get("tick_count"), 1, "Sequence should continue once action succeeds")
	assert_true(state_bag.is_empty(), "Successful completion should clear transient state")

	var tick3: Variant = runner.call("tick", root, {"delta": 0.016}, state_bag)
	assert_eq(tick3, _status("RUNNING"), "Next frame should re-enter parent from the beginning")
	assert_eq(counting_action.get("start_count"), 2, "Action.start should run again after prior completion")
	assert_eq(counting_action.get("tick_count"), 3, "Action should begin a new lifecycle after reset")
	assert_eq(trailing_success.get("tick_count"), 1, "Trailing node should not tick while action is running")

func test_tick_state_is_isolated_between_sequence_subtrees() -> void:
	var runner: Object = _new_runner()
	if runner == null:
		return

	var action_a: Resource = _new_counting_action(4)
	var action_b: Resource = _new_counting_action(4)
	if action_a == null or action_b == null:
		return
	var bt_action_a: Resource = _new_bt_action(action_a)
	var bt_action_b: Resource = _new_bt_action(action_b)
	if bt_action_a == null or bt_action_b == null:
		return
	var sequence_a: Resource = _new_sequence([bt_action_a])
	var sequence_b: Resource = _new_sequence([bt_action_b])
	if sequence_a == null or sequence_b == null:
		return

	var state_bag: Dictionary = {}
	var status_a: Variant = runner.call("tick", sequence_a, {"delta": 0.016}, state_bag)
	var status_b: Variant = runner.call("tick", sequence_b, {"delta": 0.016}, state_bag)
	assert_eq(status_a, _status("RUNNING"))
	assert_eq(status_b, _status("RUNNING"))
	assert_eq(action_a.get("start_count"), 1, "First subtree should start its own action once")
	assert_eq(action_b.get("start_count"), 1, "Second subtree should start its own action once")
	assert_eq(action_a.get("tick_count"), 1, "First subtree should have one tick")
	assert_eq(action_b.get("tick_count"), 1, "Second subtree should have one tick")
	assert_true(state_bag.has(sequence_a.get("node_id")), "State bag should preserve first subtree state")
	assert_true(state_bag.has(sequence_b.get("node_id")), "State bag should preserve second subtree state")
	assert_true(state_bag.has(bt_action_a.get("node_id")), "State bag should preserve first action state")
	assert_true(state_bag.has(bt_action_b.get("node_id")), "State bag should preserve second action state")

func test_tick_null_root_pushes_error_and_returns_failure() -> void:
	var runner: Object = _new_runner()
	if runner == null:
		return
	var state_bag: Dictionary = {}
	var status: Variant = runner.call("tick", null, {}, state_bag)
	assert_push_error("U_BTRunner.tick: root is null")
	assert_eq(status, _status("FAILURE"), "Null root should fail loudly and return FAILURE")
	assert_true(state_bag.is_empty(), "Null root should not mutate state bag")
