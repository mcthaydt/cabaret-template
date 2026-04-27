extends BaseTest

const BUILDER_SCRIPT_PATH := "res://scripts/demo/ai/trees/guide_showcase_behavior.gd"

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
	assert_true(builder.has_method("build"), "guide_showcase_behavior should have build() method")
	if not builder.has_method("build"):
		return null
	var result: Variant = builder.call("build")
	assert_not_null(result, "build() should return a non-null RS_BTNode")
	if result == null or not (result is RS_BTNode):
		return null
	return result as RS_BTNode

func test_guide_showcase_behavior_builder_exists() -> void:
	assert_true(
		FileAccess.file_exists(BUILDER_SCRIPT_PATH),
		"guide_showcase_behavior.gd should exist at scripts/demo/ai/trees/"
	)

func test_guide_showcase_builder_returns_utility_selector_root() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null:
		return
	assert_not_null(
		root as RS_BTUtilitySelector,
		"guide_showcase root should be an RS_BTUtilitySelector"
	)

func test_guide_showcase_builder_has_four_children_and_four_scorers() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	assert_eq(selector.child_scorers.size(), 4, "Guide showcase BT should have 4 scorers")
	assert_eq(selector.children.size(), 4, "Guide showcase BT should have 4 children")

func test_guide_showcase_celebrate_scorer_is_condition_twelve() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	if selector.child_scorers.size() < 1:
		return
	var scorer: Resource = selector.child_scorers[0]
	assert_not_null(scorer, "Celebrate scorer should not be null")
	if scorer == null:
		return
	assert_true(scorer is RS_AIScorerCondition, "Celebrate scorer should be RS_AIScorerCondition")
	if not (scorer is RS_AIScorerCondition):
		return
	assert_eq((scorer as RS_AIScorerCondition).if_true, 12.0, "Celebrate scorer if_true should be 12.0")

func test_guide_showcase_encourage_scorer_is_condition_eight() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	if selector.child_scorers.size() < 2:
		return
	var scorer: Resource = selector.child_scorers[1]
	assert_not_null(scorer, "Encourage scorer should not be null")
	if scorer == null:
		return
	assert_true(scorer is RS_AIScorerCondition, "Encourage scorer should be RS_AIScorerCondition")
	if not (scorer is RS_AIScorerCondition):
		return
	assert_eq((scorer as RS_AIScorerCondition).if_true, 8.0, "Encourage scorer if_true should be 8.0")

func test_guide_showcase_show_path_scorer_is_condition_four() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	if selector.child_scorers.size() < 3:
		return
	var scorer: Resource = selector.child_scorers[2]
	assert_not_null(scorer, "Show-path scorer should not be null")
	if scorer == null:
		return
	assert_true(scorer is RS_AIScorerCondition, "Show-path scorer should be RS_AIScorerCondition")
	if not (scorer is RS_AIScorerCondition):
		return
	assert_eq((scorer as RS_AIScorerCondition).if_true, 4.0, "Show-path scorer if_true should be 4.0")

func test_guide_showcase_idle_scorer_is_constant_one() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	if selector.child_scorers.size() < 4:
		return
	var scorer: Resource = selector.child_scorers[3]
	assert_not_null(scorer, "Idle scorer should not be null")
	if scorer == null:
		return
	assert_true(scorer is RS_AIScorerConstant, "Idle scorer should be RS_AIScorerConstant")
	if not (scorer is RS_AIScorerConstant):
		return
	assert_eq((scorer as RS_AIScorerConstant).value, 1.0, "Idle scorer value should be 1.0")
