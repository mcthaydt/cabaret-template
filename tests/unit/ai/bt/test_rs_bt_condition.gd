extends GutTest

const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"
const RS_BT_CONDITION_PATH := "res://scripts/core/resources/ai/bt/rs_bt_condition.gd"
const RS_CONDITION_CONSTANT_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_constant.gd"

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

func _new_constant_condition(score: float) -> Resource:
	var condition_script: Script = _load_script(RS_CONDITION_CONSTANT_PATH)
	if condition_script == null:
		return null
	var condition_variant: Variant = condition_script.new()
	assert_not_null(condition_variant, "Expected RS_ConditionConstant.new() to succeed")
	if condition_variant == null:
		return null
	var condition: Resource = condition_variant as Resource
	condition.set("score", score)
	return condition

func _new_bt_condition_leaf(condition: Resource) -> Resource:
	var bt_condition_script: Script = _load_script(RS_BT_CONDITION_PATH)
	if bt_condition_script == null:
		return null
	var bt_condition_variant: Variant = bt_condition_script.new()
	assert_not_null(bt_condition_variant, "Expected RS_BTCondition.new() to succeed")
	if bt_condition_variant == null:
		return null
	var bt_condition: Resource = bt_condition_variant as Resource
	bt_condition.set("condition", condition)
	return bt_condition

func test_condition_script_exists_and_loads() -> void:
	var bt_condition_script: Script = _load_script(RS_BT_CONDITION_PATH)
	assert_not_null(bt_condition_script, "RS_BTCondition script must exist and load")

func test_condition_returns_success_for_positive_scores() -> void:
	var condition: Resource = _new_constant_condition(0.25)
	if condition == null:
		return
	var bt_condition: Resource = _new_bt_condition_leaf(condition)
	if bt_condition == null:
		return

	var status: Variant = bt_condition.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "Positive condition score should map to SUCCESS")

func test_condition_returns_failure_for_zero_score() -> void:
	var condition: Resource = _new_constant_condition(0.0)
	if condition == null:
		return
	var bt_condition: Resource = _new_bt_condition_leaf(condition)
	if bt_condition == null:
		return

	var status: Variant = bt_condition.call("tick", {}, {})
	assert_eq(status, _status("FAILURE"), "Zero condition score should map to FAILURE")

func test_condition_never_returns_running() -> void:
	var true_condition: Resource = _new_constant_condition(1.0)
	var false_condition: Resource = _new_constant_condition(0.0)
	if true_condition == null or false_condition == null:
		return

	var bt_true: Resource = _new_bt_condition_leaf(true_condition)
	var bt_false: Resource = _new_bt_condition_leaf(false_condition)
	if bt_true == null or bt_false == null:
		return

	var running_status: int = _status("RUNNING")
	var true_status: Variant = bt_true.call("tick", {}, {})
	var false_status: Variant = bt_false.call("tick", {}, {})

	assert_ne(true_status, running_status, "TRUE path must not return RUNNING")
	assert_ne(false_status, running_status, "FALSE path must not return RUNNING")
