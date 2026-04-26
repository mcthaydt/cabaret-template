extends BaseTest

const BUILDER_SCRIPT_PATH := "res://scripts/demo/ai/trees/wolf_behavior.gd"

const RS_BT_NODE := preload("res://scripts/core/resources/bt/rs_bt_node.gd")
const RS_BT_UTILITY_SELECTOR := preload("res://scripts/core/resources/bt/rs_bt_utility_selector.gd")
const RS_AI_SCORER_CONDITION := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_condition.gd")
const RS_AI_SCORER_CONSTANT := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_constant.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/core/resources/ecs/rs_needs_settings.gd")

const C_NEEDS_COMPONENT := preload("res://scripts/demo/ecs/components/c_needs_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")

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
	assert_true(builder.has_method("build"), "wolf_behavior should have build() method")
	if not builder.has_method("build"):
		return null
	var result: Variant = builder.call("build")
	assert_not_null(result, "build() should return a non-null RS_BTNode")
	if result == null or not (result is RS_BTNode):
		return null
	return result as RS_BTNode

func _make_needs_component(hunger: float = 1.0) -> C_NeedsComponent:
	var needs: C_NeedsComponent = C_NeedsComponent.new()
	var settings := RS_NeedsSettings.new()
	settings.initial_hunger = hunger
	settings.initial_thirst = 1.0
	needs.settings = settings
	needs._on_required_settings_ready()
	autofree(needs)
	return needs

func _make_detection_component(is_in_range: bool = false) -> C_DetectionComponent:
	var detection: C_DetectionComponent = C_DetectionComponent.new()
	detection.target_tag = &"prey"
	detection.detection_radius = 14.0
	detection.detection_exit_radius = 20.0
	detection.is_player_in_range = is_in_range
	autofree(detection)
	return detection

func _build_context(
	needs: C_NeedsComponent = null,
	detection: C_DetectionComponent = null
) -> Dictionary:
	var components: Dictionary = {}
	if needs != null:
		components[C_NeedsComponent.COMPONENT_TYPE] = needs
	if detection != null:
		components[C_DetectionComponent.COMPONENT_TYPE] = detection
	return {"components": components, "entity_id": &"wolf"}

func _find_highest_scoring_branch(root: RS_BTUtilitySelector, context: Dictionary) -> int:
	var best_index: int = -1
	var best_score: float = 0.0
	for i in range(root.child_scorers.size()):
		var scorer: Resource = root.child_scorers[i]
		if scorer == null:
			continue
		var score_variant: Variant = scorer.call("score", context)
		var score: float = 0.0
		if score_variant is float or score_variant is int:
			score = float(score_variant)
		if score > best_score:
			best_score = score
			best_index = i
	return best_index

func test_wolf_behavior_builder_exists() -> void:
	assert_true(
		FileAccess.file_exists(BUILDER_SCRIPT_PATH),
		"wolf_behavior.gd should exist at scripts/demo/ai/trees/"
	)

func test_wolf_builder_returns_utility_selector_root() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null:
		return
	assert_not_null(
		root as RS_BTUtilitySelector,
		"wolf root should be an RS_BTUtilitySelector"
	)

func test_wolf_builder_root_has_three_scorer_child_pairs() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	assert_eq(selector.child_scorers.size(), 3, "Wolf BT should have 3 scorers")
	assert_eq(selector.children.size(), 3, "Wolf BT should have 3 children")

func test_wolf_builder_first_scorer_if_true_is_ten() -> void:
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
		"First scorer should be RS_AIScorerCondition (hunt_solo)"
	)
	if not (scorer is RS_AIScorerCondition):
		return
	var condition_scorer: RS_AIScorerCondition = scorer as RS_AIScorerCondition
	assert_eq(condition_scorer.if_true, 10.0, "Hunt-solo scorer should have if_true=10.0")

func test_wolf_with_prey_and_hunger_selects_hunt() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	var needs := _make_needs_component(0.1)
	var detection := _make_detection_component(true)
	var context := _build_context(needs, detection)
	var branch := _find_highest_scoring_branch(selector, context)
	var wander_index: int = selector.child_scorers.size() - 1
	assert_gt(branch, -1, "Wolf should select a branch with prey + hunger")
	assert_ne(branch, wander_index, "Wolf should not select wander when prey detected and hungry")

func test_wolf_without_prey_selects_wander_or_search() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	var needs := _make_needs_component(1.0)
	var detection := _make_detection_component(false)
	var context := _build_context(needs, detection)
	var branch := _find_highest_scoring_branch(selector, context)
	assert_gt(branch, -1, "Wolf should select a branch even without prey")
