extends GutTest

const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"
const RS_BT_DECORATOR_PATH := "res://scripts/core/resources/bt/rs_bt_decorator.gd"
const RS_BT_SCORED_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_scored_node.gd"
const TEST_STATUS_NODE_PATH := "res://tests/unit/ai/bt/helpers/test_bt_status_node.gd"

class ScoreStub extends Resource:
	var score_value: float = 1.0
	var call_count: int = 0

	func score(_context: Dictionary) -> float:
		call_count += 1
		return score_value

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

func _new_scored_node() -> Resource:
	var script: Script = _load_script(RS_BT_SCORED_NODE_PATH)
	if script == null:
		return null
	var instance_variant: Variant = script.new()
	assert_not_null(instance_variant, "Expected RS_BTScoredNode.new() to succeed")
	if instance_variant == null:
		return null
	return instance_variant as Resource

func _new_status_node(status: int) -> Resource:
	var script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if script == null:
		return null
	var node_variant: Variant = script.new(status)
	assert_not_null(node_variant, "Expected status stub node to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func test_rs_bt_scored_node_script_exists_and_loads() -> void:
	var script: Script = _load_script(RS_BT_SCORED_NODE_PATH)
	assert_not_null(script, "RS_BTScoredNode script must exist and load")

func test_rs_bt_scored_node_extends_rs_bt_decorator() -> void:
	var node: Resource = _new_scored_node()
	if node == null:
		return
	assert_true(node.get("child") != ERR_INVALID_PARAMETER, "RS_BTScoredNode must inherit 'child' from RS_BTDecorator")
	assert_null(node.get("child"), "child should default to null")

func test_rs_bt_scored_node_has_scorer_export_defaulting_null() -> void:
	var node: Resource = _new_scored_node()
	if node == null:
		return
	assert_true("scorer" in node, "RS_BTScoredNode must have a 'scorer' property")
	assert_null(node.get("scorer"), "scorer must default to null")

func test_rs_bt_scored_node_without_child_returns_failure() -> void:
	var node: Resource = _new_scored_node()
	if node == null:
		return
	var status: Variant = node.call("tick", {}, {})
	assert_eq(status, _status("FAILURE"), "RS_BTScoredNode with null child must return FAILURE")

func test_rs_bt_scored_node_delegates_tick_to_child_success() -> void:
	var node: Resource = _new_scored_node()
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if node == null or child == null:
		return
	node.set("child", child)
	var status: Variant = node.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "RS_BTScoredNode must pass through child SUCCESS")
	assert_eq(child.get("tick_count"), 1, "Child must be ticked exactly once")

func test_rs_bt_scored_node_delegates_tick_to_child_running() -> void:
	var node: Resource = _new_scored_node()
	var child: Resource = _new_status_node(_status("RUNNING"))
	if node == null or child == null:
		return
	node.set("child", child)
	var status: Variant = node.call("tick", {}, {})
	assert_eq(status, _status("RUNNING"), "RS_BTScoredNode must pass through child RUNNING")

func test_rs_bt_scored_node_scorer_is_not_called_during_tick() -> void:
	var node: Resource = _new_scored_node()
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if node == null or child == null:
		return
	node.set("child", child)
	var stub := ScoreStub.new()
	node.set("scorer", stub)
	node.call("tick", {}, {})
	assert_eq(stub.call_count, 0, "scorer must NOT be called by tick — it is read by RS_BTUtilitySelector only")
