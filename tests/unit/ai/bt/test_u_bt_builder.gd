extends GutTest

const U_BT_BUILDER_PATH := "res://scripts/core/utils/bt/u_bt_builder.gd"
const U_BT_RUNNER_PATH := "res://scripts/core/utils/bt/u_bt_runner.gd"
const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"
const RS_AI_SCORER_CONSTANT_PATH := "res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_constant.gd"
const RS_AI_SCORER_CONDITION_PATH := "res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_condition.gd"
const RS_AI_SCORER_CONTEXT_FIELD_PATH := "res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_context_field.gd"
const RS_CONDITION_CONSTANT_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_constant.gd"
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
	var script: Script = _load_script(RS_BT_NODE_PATH)
	if script == null:
		return -1
	var enum_variant: Variant = script.get("Status")
	if not (enum_variant is Dictionary):
		return -1
	return int((enum_variant as Dictionary).get(name, -1))

func _new_builder() -> Object:
	var script: Script = _load_script(U_BT_BUILDER_PATH)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null or not (v is Object):
		return null
	return v as Object

func _new_runner() -> Object:
	var script: Script = _load_script(U_BT_RUNNER_PATH)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null or not (v is Object):
		return null
	return v as Object

func _new_status_node(status: int) -> Resource:
	var script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if script == null:
		return null
	var v: Variant = script.new(status)
	if v == null:
		return null
	return v as Resource

func _new_resource(path: String) -> Resource:
	var script: Script = _load_script(path)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null:
		return null
	return v as Resource

func _new_counting_action() -> Resource:
	var script: Script = _load_script(TEST_COUNTING_ACTION_PATH)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null:
		return null
	return v as Resource

func _new_condition_constant(score: float) -> Resource:
	var cond: Resource = _new_resource(RS_CONDITION_CONSTANT_PATH)
	if cond == null:
		return null
	cond.set("score", score)
	return cond

func test_u_bt_builder_script_exists_and_loads() -> void:
	var script: Script = _load_script(U_BT_BUILDER_PATH)
	assert_not_null(script, "U_BTBuilder script must exist and load")

func test_sequence_creates_node_with_children_set() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child_a: Resource = _new_status_node(_status("SUCCESS"))
	var child_b: Resource = _new_status_node(_status("SUCCESS"))
	if child_a == null or child_b == null:
		return
	var node: Variant = builder.call("sequence", [child_a, child_b])
	assert_not_null(node, "sequence() must return non-null")
	assert_true(node is Resource, "sequence() must return a Resource")
	var children: Variant = (node as Resource).get("children")
	assert_true(children is Array, "sequence node must expose 'children' array")
	assert_eq((children as Array).size(), 2, "sequence children must match input")

func test_selector_creates_node_with_children_set() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child: Resource = _new_status_node(_status("FAILURE"))
	if child == null:
		return
	var node: Variant = builder.call("selector", [child])
	assert_not_null(node, "selector() must return non-null")
	var children: Variant = (node as Resource).get("children")
	assert_true(children is Array, "selector node must expose 'children' array")
	assert_eq((children as Array).size(), 1, "selector children must match input")

func test_utility_selector_accepts_scored_node_children() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	var scorer: Resource = _new_resource(RS_AI_SCORER_CONSTANT_PATH)
	if child == null or scorer == null:
		return
	scorer.set("value", 1.0)
	var scored: Variant = builder.call("scored", child, scorer)
	if scored == null:
		return
	var sel: Variant = builder.call("utility_selector", [scored])
	assert_not_null(sel, "utility_selector() must return non-null")
	var children: Variant = (sel as Resource).get("children")
	assert_true(children is Array, "utility_selector node must expose 'children' array")
	assert_eq((children as Array).size(), 1, "utility_selector must accept RS_BTScoredNode children")

func test_scored_sets_child_and_scorer() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	var scorer: Resource = _new_resource(RS_AI_SCORER_CONSTANT_PATH)
	if child == null or scorer == null:
		return
	scorer.set("value", 0.5)
	var node: Variant = builder.call("scored", child, scorer)
	assert_not_null(node, "scored() must return non-null")
	assert_eq((node as Resource).get("child"), child, "scored child must match input")
	assert_eq((node as Resource).get("scorer"), scorer, "scored scorer must match input")

func test_cooldown_sets_child_and_duration() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if child == null:
		return
	var node: Variant = builder.call("cooldown", child, 2.5)
	assert_not_null(node, "cooldown() must return non-null")
	assert_eq((node as Resource).get("child"), child, "cooldown child must match input")
	assert_eq((node as Resource).get("duration"), 2.5, "cooldown duration must match input")

func test_once_sets_child() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if child == null:
		return
	var node: Variant = builder.call("once", child)
	assert_not_null(node, "once() must return non-null")
	assert_eq((node as Resource).get("child"), child, "once child must match input")

func test_rising_edge_sets_child_and_gate() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	var gate: Resource = _new_condition_constant(1.0)
	if child == null or gate == null:
		return
	var node: Variant = builder.call("rising_edge", child, gate)
	assert_not_null(node, "rising_edge() must return non-null")
	assert_eq((node as Resource).get("child"), child, "rising_edge child must match input")
	assert_eq((node as Resource).get("gate_condition"), gate, "rising_edge gate must match input")

func test_inverter_sets_child() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if child == null:
		return
	var node: Variant = builder.call("inverter", child)
	assert_not_null(node, "inverter() must return non-null")
	assert_eq((node as Resource).get("child"), child, "inverter child must match input")

func test_action_sets_action_resource() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var action: Resource = _new_counting_action()
	if action == null:
		return
	var node: Variant = builder.call("action", action)
	assert_not_null(node, "action() must return non-null")
	assert_eq((node as Resource).get("action"), action, "action node must hold the provided action")

func test_condition_sets_condition_resource() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Resource = _new_condition_constant(1.0)
	if cond == null:
		return
	var node: Variant = builder.call("condition", cond)
	assert_not_null(node, "condition() must return non-null")
	assert_eq((node as Resource).get("condition"), cond, "condition node must hold the provided condition")

func test_score_const_sets_value() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var scorer: Variant = builder.call("score_const", 0.75)
	assert_not_null(scorer, "score_const() must return non-null")
	assert_eq((scorer as Resource).get("value"), 0.75, "score_const must set value")

func test_score_condition_sets_fields() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Resource = _new_condition_constant(1.0)
	if cond == null:
		return
	var scorer: Variant = builder.call("score_condition", cond, 2.0, 0.5)
	assert_not_null(scorer, "score_condition() must return non-null")
	assert_eq((scorer as Resource).get("condition"), cond, "score_condition must set condition")
	assert_eq((scorer as Resource).get("if_true"), 2.0, "score_condition must set if_true")
	assert_eq((scorer as Resource).get("if_false"), 0.5, "score_condition must set if_false")

func test_score_context_field_sets_path_and_multiplier() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var scorer: Variant = builder.call("score_context_field", "health", 0.5)
	assert_not_null(scorer, "score_context_field() must return non-null")
	assert_eq((scorer as Resource).get("path"), "health", "score_context_field must set path")
	assert_eq((scorer as Resource).get("multiplier"), 0.5, "score_context_field must set multiplier")

func test_sequence_of_successes_ticks_success() -> void:
	var builder: Object = _new_builder()
	var runner: Object = _new_runner()
	if builder == null or runner == null:
		return
	var child_a: Resource = _new_status_node(_status("SUCCESS"))
	var child_b: Resource = _new_status_node(_status("SUCCESS"))
	if child_a == null or child_b == null:
		return
	var root: Variant = builder.call("sequence", [child_a, child_b])
	if root == null:
		return
	var state_bag: Dictionary = {}
	var result: Variant = runner.call("tick", root, {}, state_bag)
	assert_eq(result, _status("SUCCESS"), "Sequence of two successes must tick SUCCESS")

func test_utility_selector_with_scored_children_picks_highest_score() -> void:
	var builder: Object = _new_builder()
	var runner: Object = _new_runner()
	if builder == null or runner == null:
		return
	var low_child: Resource = _new_status_node(_status("SUCCESS"))
	var high_child: Resource = _new_status_node(_status("SUCCESS"))
	if low_child == null or high_child == null:
		return
	var low_scorer: Variant = builder.call("score_const", 0.1)
	var high_scorer: Variant = builder.call("score_const", 0.9)
	if low_scorer == null or high_scorer == null:
		return
	var scored_low: Variant = builder.call("scored", low_child, low_scorer)
	var scored_high: Variant = builder.call("scored", high_child, high_scorer)
	if scored_low == null or scored_high == null:
		return
	var root: Variant = builder.call("utility_selector", [scored_low, scored_high])
	if root == null:
		return
	var state_bag: Dictionary = {}
	var result: Variant = runner.call("tick", root, {}, state_bag)
	assert_eq(result, _status("SUCCESS"), "Utility selector must succeed when best-scored child succeeds")
	assert_eq(low_child.get("tick_count"), 0, "Low-scored child must NOT be ticked")
	assert_eq(high_child.get("tick_count"), 1, "High-scored child must be ticked once")
