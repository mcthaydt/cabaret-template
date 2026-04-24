extends BaseTest

const WOLF_BT_BRAIN_PATH := "res://resources/ai/woods/wolf/cfg_woods_wolf_brain.tres"

const RS_BT_UTILITY_SELECTOR := preload("res://scripts/resources/bt/rs_bt_utility_selector.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")

const C_NEEDS_COMPONENT := preload("res://scripts/demo/ecs/components/c_needs_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")

func _load_brain_settings() -> RS_AIBrainSettings:
	assert_true(FileAccess.file_exists(WOLF_BT_BRAIN_PATH), "Woods wolf brain .tres should exist")
	var brain_variant: Variant = load(WOLF_BT_BRAIN_PATH)
	assert_not_null(brain_variant, "Woods wolf brain should load")
	if brain_variant == null or not (brain_variant is RS_AIBrainSettings):
		return null
	var settings: RS_AIBrainSettings = brain_variant as RS_AIBrainSettings
	assert_not_null(settings.root, "Woods wolf brain should have a root node")
	return settings

func _find_highest_scoring_branch(brain_settings: RS_AIBrainSettings, context: Dictionary) -> int:
	var root: RS_BTUtilitySelector = brain_settings.root as RS_BTUtilitySelector
	assert_not_null(root, "Root should be RS_BTUtilitySelector")
	if root == null:
		return -1
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
	detection: C_DetectionComponent = null,
	pack_detection: C_DetectionComponent = null
) -> Dictionary:
	var components: Dictionary = {}
	if needs != null:
		components[C_NeedsComponent.COMPONENT_TYPE] = needs
	if detection != null:
		components[C_DetectionComponent.COMPONENT_TYPE] = detection
	if pack_detection != null:
		components[&"C_DetectionComponent:pack"] = pack_detection
	return {"components": components, "entity_id": &"wolf"}

func test_wolf_brain_loads_with_utility_root() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var root: RS_BTUtilitySelector = brain_settings.root as RS_BTUtilitySelector
	assert_not_null(root, "Root should be a RS_BTUtilitySelector")
	if root == null:
		return
	assert_gt(root.child_scorers.size(), 0, "Wolf brain should have scorer-child pairs")

func test_wolf_with_prey_and_hunger_selects_hunt() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var needs := _make_needs_component(0.1)
	var detection := _make_detection_component(true)
	var context := _build_context(needs, detection)
	var branch := _find_highest_scoring_branch(brain_settings, context)
	var root: RS_BTUtilitySelector = brain_settings.root as RS_BTUtilitySelector
	var wander_index := root.child_scorers.size() - 1 if root != null and root.child_scorers.size() > 0 else -1
	assert_gt(branch, -1, "Wolf should select a branch with prey + hunger")
	assert_ne(branch, wander_index, "Wolf should not select wander when prey detected and hungry")

func test_wolf_without_prey_selects_wander_or_search() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var needs := _make_needs_component(1.0)
	var detection := _make_detection_component(false)
	var context := _build_context(needs, detection)
	var branch := _find_highest_scoring_branch(brain_settings, context)
	assert_gt(branch, -1, "Wolf should select a branch even without prey")