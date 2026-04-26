extends BaseTest

const BUILDER_SCRIPT_PATH := "res://scripts/demo/ai/trees/guide_prism_behavior.gd"

const RS_BT_NODE := preload("res://scripts/core/resources/bt/rs_bt_node.gd")
const RS_BT_UTILITY_SELECTOR := preload("res://scripts/core/resources/bt/rs_bt_utility_selector.gd")
const RS_AI_SCORER_CONDITION := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_condition.gd")
const RS_AI_SCORER_CONSTANT := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_constant.gd")

func _load_builder_script() -> Script:
	assert_true(
		FileAccess.file_exists(BUILDER_SCRIPT_PATH),
		"Builder script should exist: %s" % BUILDER_SCRIPT_PATH
	)
	if not FileAccess.file_exists(BUILDER_SCRIPT_PATH):
		return null
	var script_variant: Variant = load(BUILDER_SCRIPT_PATH)
	assert_not_null(script_variant, "Builder script should load from: %s" % BUILDER_SCRIPT_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _build_tree() -> RS_BTNode:
	var script: Script = _load_builder_script()
	if script == null:
		return null
	var builder: Object = script.new()
	assert_true(builder.has_method("build"), "guide_prism_behavior should have build() method")
	if not builder.has_method("build"):
		return null
	var result: Variant = builder.call("build")
	assert_not_null(result, "build() should return a non-null RS_BTNode")
	if result == null or not (result is RS_BTNode):
		return null
	return result as RS_BTNode

func test_guide_prism_behavior_builder_exists() -> void:
	assert_true(
		FileAccess.file_exists(BUILDER_SCRIPT_PATH),
		"guide_prism_behavior.gd should exist at scripts/demo/ai/trees/"
	)

func test_guide_prism_builder_returns_utility_selector_root() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null:
		return
	assert_not_null(
		root as RS_BTUtilitySelector,
		"guide_prism root should be an RS_BTUtilitySelector"
	)

func test_guide_prism_builder_root_has_three_scorer_child_pairs() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	assert_eq(selector.child_scorers.size(), 3, "Guide prism BT should have 3 scorers")
	assert_eq(selector.children.size(), 3, "Guide prism BT should have 3 children")

func test_guide_prism_builder_first_scorer_if_true_is_twelve() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	if selector.child_scorers.is_empty():
		return
	var scorer: Resource = selector.child_scorers[0]
	assert_not_null(scorer, "First scorer should not be null")
	if scorer == null:
		return
	assert_true(
		scorer is RS_AIScorerCondition,
		"First scorer should be RS_AIScorerCondition (celebrate)"
	)
	if not (scorer is RS_AIScorerCondition):
		return
	var condition_scorer: RS_AIScorerCondition = scorer as RS_AIScorerCondition
	assert_eq(
		condition_scorer.if_true,
		12.0,
		"Celebrate scorer should have if_true=12.0"
	)

func test_guide_prism_builder_last_scorer_is_constant_one() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	if selector.child_scorers.size() < 3:
		return
	var scorer: Resource = selector.child_scorers[2]
	assert_not_null(scorer, "Last scorer should not be null")
	if scorer == null:
		return
	assert_true(
		scorer is RS_AIScorerConstant,
		"Last scorer should be RS_AIScorerConstant (show_path fallback)"
	)
	if not (scorer is RS_AIScorerConstant):
		return
	var const_scorer: RS_AIScorerConstant = scorer as RS_AIScorerConstant
	assert_eq(const_scorer.value, 1.0, "Show-path fallback scorer should have value=1.0")
