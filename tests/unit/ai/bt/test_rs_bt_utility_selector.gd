extends GutTest

const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"
const RS_BT_UTILITY_SELECTOR_PATH := "res://scripts/resources/bt/rs_bt_utility_selector.gd"
const TEST_STATUS_NODE_PATH := "res://tests/unit/ai/bt/helpers/test_bt_status_node.gd"
const RS_AI_SCORER_CONSTANT_PATH := "res://scripts/resources/ai/bt/scorers/rs_ai_scorer_constant.gd"

class ScoreStub extends RefCounted:
	var score_value: float = 0.0
	var call_count: int = 0

	func _init(initial_score: float = 0.0) -> void:
		score_value = initial_score

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

func _new_utility_selector() -> Resource:
	var selector_script: Script = _load_script(RS_BT_UTILITY_SELECTOR_PATH)
	if selector_script == null:
		return null
	var selector_variant: Variant = selector_script.new()
	assert_not_null(selector_variant, "Expected RS_BTUtilitySelector.new() to succeed")
	if selector_variant == null:
		return null
	return selector_variant as Resource

func _new_status_node(status: int) -> Resource:
	var node_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if node_script == null:
		return null
	var node_variant: Variant = node_script.new(status)
	assert_not_null(node_variant, "Expected status stub node to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func _set_children_for_test(selector: Resource, child_nodes: Array) -> void:
	var coerced_children: Variant = selector.call("_coerce_children", child_nodes)
	selector.set("_children", coerced_children)

func _set_scorers_for_test(selector: Resource, score_stubs: Array[ScoreStub]) -> void:
	var scorer_callables: Array[Callable] = []
	for scorer in score_stubs:
		scorer_callables.append(Callable(scorer, "score"))
	selector.set("scorer_callables", scorer_callables)

func _set_child_scorers_for_test(selector: Resource, scorers: Array) -> void:
	var coerced_scorers: Variant = selector.call("_coerce_child_scorers", scorers)
	selector.set("_child_scorers", coerced_scorers)

func _new_constant_scorer(value: float) -> Resource:
	var scorer_script: Script = _load_script(RS_AI_SCORER_CONSTANT_PATH)
	if scorer_script == null:
		return null
	var scorer_variant: Variant = scorer_script.new()
	assert_not_null(scorer_variant, "Expected RS_AIScorerConstant.new() to succeed")
	if scorer_variant == null:
		return null
	var scorer: Resource = scorer_variant as Resource
	scorer.set("value", value)
	return scorer

func test_utility_selector_script_exists_and_loads() -> void:
	var selector_script: Script = _load_script(RS_BT_UTILITY_SELECTOR_PATH)
	assert_not_null(selector_script, "RS_BTUtilitySelector script must exist and load")

func test_utility_selector_without_children_returns_failure() -> void:
	var selector: Resource = _new_utility_selector()
	if selector == null:
		return
	_set_children_for_test(selector, [])
	_set_scorers_for_test(selector, [])
	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("FAILURE"), "Empty utility selector should return FAILURE")

func test_utility_selector_selects_highest_score_child() -> void:
	var selector: Resource = _new_utility_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null:
		return
	_set_children_for_test(selector, [first, second])
	_set_scorers_for_test(selector, [ScoreStub.new(0.1), ScoreStub.new(0.9)])

	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "Utility selector should return selected child status")
	assert_eq(first.get("tick_count"), 0, "Lower score child should not be ticked")
	assert_eq(second.get("tick_count"), 1, "Highest score child should be ticked once")

func test_utility_selector_skips_non_positive_scores() -> void:
	var selector: Resource = _new_utility_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null:
		return
	_set_children_for_test(selector, [first, second])
	_set_scorers_for_test(selector, [ScoreStub.new(0.0), ScoreStub.new(-2.0)])

	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("FAILURE"), "All non-positive scores should produce FAILURE")
	assert_eq(first.get("tick_count"), 0, "Non-viable child should not be ticked")
	assert_eq(second.get("tick_count"), 0, "Non-viable child should not be ticked")

func test_utility_selector_uses_first_child_for_score_ties() -> void:
	var selector: Resource = _new_utility_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null:
		return
	_set_children_for_test(selector, [first, second])
	_set_scorers_for_test(selector, [ScoreStub.new(1.0), ScoreStub.new(1.0)])

	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "Tied highest score should still yield SUCCESS")
	assert_eq(first.get("tick_count"), 1, "Earlier tied child should win")
	assert_eq(second.get("tick_count"), 0, "Later tied child should not be ticked")

func test_utility_selector_re_scores_each_tick_when_not_running() -> void:
	var selector: Resource = _new_utility_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null:
		return
	_set_children_for_test(selector, [first, second])
	var first_score := ScoreStub.new(2.0)
	var second_score := ScoreStub.new(0.1)
	_set_scorers_for_test(selector, [first_score, second_score])

	var state_bag := {}
	var first_tick: Variant = selector.call("tick", {}, state_bag)
	assert_eq(first_tick, _status("SUCCESS"))
	assert_eq(first.get("tick_count"), 1)
	assert_eq(second.get("tick_count"), 0)

	first_score.score_value = 0.2
	second_score.score_value = 2.5
	var second_tick: Variant = selector.call("tick", {}, state_bag)
	assert_eq(second_tick, _status("SUCCESS"))
	assert_eq(first.get("tick_count"), 1, "First child should not be reselected after score drops")
	assert_eq(second.get("tick_count"), 1, "Second child should be selected after score increases")
	assert_gte(first_score.call_count, 2, "Selector should re-score first child on subsequent non-running ticks")
	assert_gte(second_score.call_count, 2, "Selector should re-score second child on subsequent non-running ticks")

func test_utility_selector_pins_running_child_until_completion() -> void:
	var selector: Resource = _new_utility_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("RUNNING"))
	var second: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null:
		return
	_set_children_for_test(selector, [first, second])
	var first_score := ScoreStub.new(2.0)
	var second_score := ScoreStub.new(0.1)
	_set_scorers_for_test(selector, [first_score, second_score])

	var state_bag := {}
	var first_tick: Variant = selector.call("tick", {}, state_bag)
	assert_eq(first_tick, _status("RUNNING"), "Initial tick should run highest-score child")
	assert_eq(first.get("tick_count"), 1)
	assert_eq(second.get("tick_count"), 0)
	var first_calls_after_tick_one: int = first_score.call_count
	var second_calls_after_tick_one: int = second_score.call_count

	first.set("fixed_status", _status("SUCCESS"))
	first_score.score_value = 0.1
	second_score.score_value = 10.0
	var second_tick: Variant = selector.call("tick", {}, state_bag)
	assert_eq(second_tick, _status("SUCCESS"), "Running child should be resumed until completion")
	assert_eq(first.get("tick_count"), 2, "Pinned running child should be re-ticked")
	assert_eq(second.get("tick_count"), 0, "Higher-score sibling should be ignored while pinned child resolves")
	assert_eq(first_score.call_count, first_calls_after_tick_one, "Pinned tick should not re-score first child")
	assert_eq(second_score.call_count, second_calls_after_tick_one, "Pinned tick should not re-score second child")

func test_utility_selector_supports_child_scorer_resources() -> void:
	var selector: Resource = _new_utility_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("SUCCESS"))
	var first_scorer: Resource = _new_constant_scorer(0.1)
	var second_scorer: Resource = _new_constant_scorer(0.9)
	if first == null or second == null or first_scorer == null or second_scorer == null:
		return
	_set_children_for_test(selector, [first, second])
	_set_child_scorers_for_test(selector, [first_scorer, second_scorer])

	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "Selector should return selected child status with resource scorers")
	assert_eq(first.get("tick_count"), 0, "Lower score child should not be ticked")
	assert_eq(second.get("tick_count"), 1, "Highest score child should be ticked once")
