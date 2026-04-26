extends BaseTest

const BUILDER_SCRIPT_PATH := "res://scripts/demo/ai/trees/builder_behavior.gd"

const RS_BT_NODE := preload("res://scripts/core/resources/bt/rs_bt_node.gd")
const RS_BT_UTILITY_SELECTOR := preload("res://scripts/core/resources/bt/rs_bt_utility_selector.gd")
const RS_AI_SCORER_CONDITION := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_condition.gd")
const RS_AI_SCORER_CONSTANT := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_constant.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/core/resources/ecs/rs_needs_settings.gd")
const RS_INVENTORY_SETTINGS := preload("res://scripts/demo/resources/ai/world/rs_inventory_settings.gd")
const RS_BUILD_SITE_SETTINGS := preload("res://scripts/demo/resources/ai/world/rs_build_site_settings.gd")
const RS_BUILD_STAGE := preload("res://scripts/demo/resources/ai/world/rs_build_stage.gd")

const C_NEEDS_COMPONENT := preload("res://scripts/demo/ecs/components/c_needs_component.gd")
const C_INVENTORY_COMPONENT := preload("res://scripts/demo/ecs/components/c_inventory_component.gd")
const C_BUILD_SITE_COMPONENT := preload("res://scripts/demo/ecs/components/c_build_site_component.gd")

const BRANCH_DRINK := 0
const BRANCH_GATHER := 1
const BRANCH_HAUL := 2
const BRANCH_BUILD := 3
const BRANCH_WANDER := 4

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
	assert_true(builder.has_method("build"), "builder_behavior should have build() method")
	if not builder.has_method("build"):
		return null
	var result: Variant = builder.call("build")
	assert_not_null(result, "build() should return a non-null RS_BTNode")
	if result == null or not (result is RS_BTNode):
		return null
	return result as RS_BTNode

func _make_needs_component(thirst: float = 1.0) -> C_NeedsComponent:
	var needs: C_NeedsComponent = C_NeedsComponent.new()
	var settings := RS_NeedsSettings.new()
	settings.initial_thirst = thirst
	needs.settings = settings
	needs._on_required_settings_ready()
	autofree(needs)
	return needs

func _make_inventory_component(fill_count: int = 0, capacity: int = 4) -> C_InventoryComponent:
	var inv: C_InventoryComponent = C_InventoryComponent.new()
	var settings := RS_INVENTORY_SETTINGS.new()
	settings.capacity = capacity
	inv.settings = settings
	autofree(inv)
	for i in range(fill_count):
		inv.add(&"wood", 1)
	return inv

func _make_build_site_component(materials_ready: bool = false, completed: bool = false) -> C_BuildSiteComponent:
	var site: C_BuildSiteComponent = C_BuildSiteComponent.new()
	var settings := RS_BUILD_SITE_SETTINGS.new()
	var stage := RS_BuildStage.new()
	stage.stage_id = &"foundation"
	stage.required_materials = {&"wood": 2}
	stage.build_seconds = 3.0
	settings.stages = [stage]
	site.settings = settings
	autofree(site)
	if materials_ready:
		site.placed_materials = {&"wood": 2}
		site.materials_ready = true
	if completed:
		site.completed = true
		site.current_stage_index = site.settings.stages.size()
		site.materials_ready = false
	return site

func _build_context(
	needs: C_NeedsComponent = null,
	inventory: C_InventoryComponent = null,
	build_site: C_BuildSiteComponent = null
) -> Dictionary:
	var components: Dictionary = {}
	if needs != null:
		components[C_NeedsComponent.COMPONENT_TYPE] = needs
	if inventory != null:
		components[C_InventoryComponent.COMPONENT_TYPE] = inventory
	if build_site != null:
		components[C_BuildSiteComponent.COMPONENT_TYPE] = build_site
	return {"components": components, "entity_id": &"builder"}

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

func test_builder_behavior_builder_exists() -> void:
	assert_true(
		FileAccess.file_exists(BUILDER_SCRIPT_PATH),
		"builder_behavior.gd should exist at scripts/demo/ai/trees/"
	)

func test_builder_behavior_returns_utility_selector_root() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null:
		return
	assert_not_null(
		root as RS_BTUtilitySelector,
		"builder root should be an RS_BTUtilitySelector"
	)

func test_builder_behavior_root_has_five_scorer_child_pairs() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	assert_eq(selector.child_scorers.size(), 5, "Builder BT should have 5 scorers")
	assert_eq(selector.children.size(), 5, "Builder BT should have 5 children")

func test_builder_with_empty_inventory_selects_gather_wood() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	var needs := _make_needs_component(1.0)
	var inventory := _make_inventory_component(0, 4)
	var context := _build_context(needs, inventory)
	var branch := _find_highest_scoring_branch(selector, context)
	assert_eq(branch, BRANCH_GATHER, "Empty inventory should select gather_wood branch")

func test_builder_with_full_inventory_selects_haul() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	var needs := _make_needs_component(1.0)
	var inventory := _make_inventory_component(4, 4)
	var context := _build_context(needs, inventory)
	var branch := _find_highest_scoring_branch(selector, context)
	assert_eq(branch, BRANCH_HAUL, "Full inventory should select haul branch")

func test_builder_with_placed_materials_selects_build_stage() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	var needs := _make_needs_component(1.0)
	var inventory := _make_inventory_component(0, 4)
	var build_site := _make_build_site_component(true)
	var context := _build_context(needs, inventory, build_site)
	var branch := _find_highest_scoring_branch(selector, context)
	assert_eq(branch, BRANCH_BUILD, "Placed materials should select build_stage branch")

func test_builder_with_low_thirst_selects_drink() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	var needs := _make_needs_component(0.1)
	var inventory := _make_inventory_component(0, 4)
	var context := _build_context(needs, inventory)
	var branch := _find_highest_scoring_branch(selector, context)
	assert_eq(branch, BRANCH_DRINK, "Low thirst should select drink branch")

func test_builder_completed_site_falls_back_to_wander() -> void:
	var root: RS_BTNode = _build_tree()
	if root == null or not (root is RS_BTUtilitySelector):
		return
	var selector: RS_BTUtilitySelector = root as RS_BTUtilitySelector
	var needs := _make_needs_component(1.0)
	var inventory := _make_inventory_component(4, 4)
	var build_site := _make_build_site_component(false, true)
	var context := _build_context(needs, inventory, build_site)
	var branch := _find_highest_scoring_branch(selector, context)
	assert_eq(branch, BRANCH_WANDER, "Completed build site should fall back to wander")
