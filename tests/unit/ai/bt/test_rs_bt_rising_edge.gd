extends GutTest

const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"
const RS_BT_RISING_EDGE_PATH := "res://scripts/resources/bt/rs_bt_rising_edge.gd"
const TEST_STATUS_NODE_PATH := "res://tests/unit/ai/bt/helpers/test_bt_status_node.gd"
const RS_CONDITION_CONSTANT_PATH := "res://scripts/resources/qb/conditions/rs_condition_constant.gd"

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

func _new_rising_edge() -> Resource:
	var rising_edge_script: Script = _load_script(RS_BT_RISING_EDGE_PATH)
	if rising_edge_script == null:
		return null
	var rising_edge_variant: Variant = rising_edge_script.new()
	assert_not_null(rising_edge_variant, "Expected RS_BTRisingEdge.new() to succeed")
	if rising_edge_variant == null:
		return null
	return rising_edge_variant as Resource

func _new_status_node(status: int) -> Resource:
	var node_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if node_script == null:
		return null
	var node_variant: Variant = node_script.new(status)
	assert_not_null(node_variant, "Expected status stub node to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func _new_gate_condition(score: float) -> Resource:
	var condition_script: Script = _load_script(RS_CONDITION_CONSTANT_PATH)
	if condition_script == null:
		return null
	var condition_variant: Variant = condition_script.new()
	assert_not_null(condition_variant, "Expected condition resource to instantiate")
	if condition_variant == null:
		return null
	var condition: Resource = condition_variant as Resource
	condition.set("score", score)
	return condition

func test_rising_edge_script_exists_and_loads() -> void:
	var rising_edge_script: Script = _load_script(RS_BT_RISING_EDGE_PATH)
	assert_not_null(rising_edge_script, "RS_BTRisingEdge script must exist and load")

func test_rising_edge_runs_only_on_false_to_true_transitions() -> void:
	var rising_edge: Resource = _new_rising_edge()
	if rising_edge == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	var gate_condition: Resource = _new_gate_condition(0.0)
	if child == null or gate_condition == null:
		return
	rising_edge.set("child", child)
	rising_edge.set("gate_condition", gate_condition)

	var state_bag: Dictionary = {}
	var first_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(first_status, _status("FAILURE"), "Decorator should fail while gate remains false")
	assert_eq(child.get("tick_count"), 0, "Child should not run while gate is false")

	gate_condition.set("score", 1.0)
	var second_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(second_status, _status("SUCCESS"), "Decorator should run child on false->true transition")
	assert_eq(child.get("tick_count"), 1, "Child should run once on first rising edge")

	var third_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(third_status, _status("FAILURE"), "Decorator should not re-enter while gate stays true")
	assert_eq(child.get("tick_count"), 1, "Child should not rerun without a new rising edge")

func test_rising_edge_rearms_after_gate_returns_false() -> void:
	var rising_edge: Resource = _new_rising_edge()
	if rising_edge == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	var gate_condition: Resource = _new_gate_condition(1.0)
	if child == null or gate_condition == null:
		return
	rising_edge.set("child", child)
	rising_edge.set("gate_condition", gate_condition)

	var state_bag: Dictionary = {}
	var first_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(first_status, _status("SUCCESS"), "First true gate should run child")
	assert_eq(child.get("tick_count"), 1)

	var held_true_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(held_true_status, _status("FAILURE"), "Held true gate should not retrigger")

	gate_condition.set("score", 0.0)
	var reset_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(reset_status, _status("FAILURE"), "False gate should reset edge detection")

	gate_condition.set("score", 1.0)
	var second_edge_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(second_edge_status, _status("SUCCESS"), "Gate false->true cycle should rearm decorator")
	assert_eq(child.get("tick_count"), 2, "Child should run again after rearm")

func test_rising_edge_reticks_running_child_until_completion_even_if_gate_falls() -> void:
	var rising_edge: Resource = _new_rising_edge()
	if rising_edge == null:
		return
	var child: Resource = _new_status_node(_status("RUNNING"))
	var gate_condition: Resource = _new_gate_condition(1.0)
	if child == null or gate_condition == null:
		return
	rising_edge.set("child", child)
	rising_edge.set("gate_condition", gate_condition)

	var state_bag: Dictionary = {}
	var running_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(running_status, _status("RUNNING"), "Child should start on rising edge and return RUNNING")
	assert_eq(child.get("tick_count"), 1)

	gate_condition.set("score", 0.0)
	child.set("fixed_status", _status("SUCCESS"))
	var completion_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(completion_status, _status("SUCCESS"), "Running child should complete even if gate falls false")
	assert_eq(child.get("tick_count"), 2, "Running child should be re-ticked while active")

	var blocked_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(blocked_status, _status("FAILURE"), "After completion, false gate should block re-entry")
	assert_eq(child.get("tick_count"), 2)

	gate_condition.set("score", 1.0)
	var rearmed_status: Variant = rising_edge.call("tick", {}, state_bag)
	assert_eq(rearmed_status, _status("SUCCESS"), "New rising edge should allow fresh entry after completion")
	assert_eq(child.get("tick_count"), 3, "Child should run again after a new rising edge")
