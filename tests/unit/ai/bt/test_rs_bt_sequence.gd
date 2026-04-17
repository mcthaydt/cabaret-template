extends GutTest

const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"
const RS_BT_SEQUENCE_PATH := "res://scripts/resources/bt/rs_bt_sequence.gd"
const TEST_STATUS_NODE_PATH := "res://tests/unit/ai/bt/helpers/test_bt_status_node.gd"

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

func _new_sequence() -> Resource:
	var sequence_script: Script = _load_script(RS_BT_SEQUENCE_PATH)
	if sequence_script == null:
		return null
	var sequence_variant: Variant = sequence_script.new()
	assert_not_null(sequence_variant, "Expected RS_BTSequence.new() to succeed")
	if sequence_variant == null:
		return null
	return sequence_variant as Resource

func _new_status_node(status: int) -> Resource:
	var node_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if node_script == null:
		return null
	var node_variant: Variant = node_script.new(status)
	assert_not_null(node_variant, "Expected status stub node to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func _set_children_for_test(sequence: Resource, child_nodes: Array) -> void:
	var coerced_children: Variant = sequence.call("_coerce_children", child_nodes)
	sequence.set("_children", coerced_children)

func test_sequence_script_exists_and_loads() -> void:
	var sequence_script: Script = _load_script(RS_BT_SEQUENCE_PATH)
	assert_not_null(sequence_script, "RS_BTSequence script must exist and load")

func test_sequence_returns_success_when_all_children_succeed() -> void:
	var sequence: Resource = _new_sequence()
	if sequence == null:
		return

	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null:
		return
	var child_nodes: Array = [first, second]
	_set_children_for_test(sequence, child_nodes)

	var status: Variant = sequence.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "Sequence should return SUCCESS when all children succeed")
	assert_eq(first.get("tick_count"), 1, "First child should be ticked exactly once")
	assert_eq(second.get("tick_count"), 1, "Second child should be ticked exactly once")

func test_sequence_returns_running_and_stops_after_running_child() -> void:
	var sequence: Resource = _new_sequence()
	if sequence == null:
		return

	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("RUNNING"))
	var third: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null or third == null:
		return
	var child_nodes: Array = [first, second, third]
	_set_children_for_test(sequence, child_nodes)

	var status: Variant = sequence.call("tick", {}, {})
	assert_eq(status, _status("RUNNING"), "Sequence should return RUNNING on first RUNNING child")
	assert_eq(first.get("tick_count"), 1, "First child should be ticked")
	assert_eq(second.get("tick_count"), 1, "Second child should be ticked")
	assert_eq(third.get("tick_count"), 0, "Sequence should stop before ticking later children")

func test_sequence_returns_failure_and_stops_after_failure_child() -> void:
	var sequence: Resource = _new_sequence()
	if sequence == null:
		return

	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("FAILURE"))
	var third: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null or third == null:
		return
	var child_nodes: Array = [first, second, third]
	_set_children_for_test(sequence, child_nodes)

	var status: Variant = sequence.call("tick", {}, {})
	assert_eq(status, _status("FAILURE"), "Sequence should return FAILURE on first FAILURE child")
	assert_eq(first.get("tick_count"), 1, "First child should be ticked")
	assert_eq(second.get("tick_count"), 1, "Second child should be ticked")
	assert_eq(third.get("tick_count"), 0, "Sequence should stop before ticking later children")

func test_sequence_without_children_returns_success() -> void:
	var sequence: Resource = _new_sequence()
	if sequence == null:
		return
	_set_children_for_test(sequence, [])
	var status: Variant = sequence.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "Empty sequence should return SUCCESS")
