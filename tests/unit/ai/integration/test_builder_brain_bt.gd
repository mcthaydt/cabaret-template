extends BaseTest

const BUILDER_BT_BRAIN_PATH := "res://resources/ai/woods/builder/cfg_builder_brain.tres"
const WOODS_BUILD_SITE_SETTINGS_PATH := "res://resources/base_settings/ai_woods/cfg_build_site_house.tres"

const RS_BT_UTILITY_SELECTOR := preload("res://scripts/resources/bt/rs_bt_utility_selector.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")
const RS_INVENTORY_SETTINGS := preload("res://scripts/resources/ai/world/rs_inventory_settings.gd")
const RS_BUILD_SITE_SETTINGS := preload("res://scripts/resources/ai/world/rs_build_site_settings.gd")
const RS_BUILD_STAGE := preload("res://scripts/resources/ai/world/rs_build_stage.gd")
const U_AI_CONTEXT_ASSEMBLER := preload("res://scripts/utils/ai/u_ai_context_assembler.gd")
const U_ENTITY_QUERY := preload("res://scripts/ecs/u_entity_query.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")

const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const C_INVENTORY_COMPONENT := preload("res://scripts/ecs/components/c_inventory_component.gd")
const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")

const BRANCH_DRINK := 0
const BRANCH_GATHER := 1
const BRANCH_HAUL := 2
const BRANCH_BUILD := 3
const BRANCH_WANDER := 4

func _load_brain_settings() -> RS_AIBrainSettings:
	assert_true(FileAccess.file_exists(BUILDER_BT_BRAIN_PATH), "Builder brain .tres should exist")
	var brain_variant: Variant = load(BUILDER_BT_BRAIN_PATH)
	assert_not_null(brain_variant, "Builder brain should load")
	if brain_variant == null or not (brain_variant is RS_AIBrainSettings):
		return null
	var settings: RS_AIBrainSettings = brain_variant as RS_AIBrainSettings
	assert_not_null(settings.root, "Builder brain should have a root node")
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
	if fill_count > 0:
		for i in range(fill_count):
			inv.add(&"wood", 1)
	return inv

func _make_build_site_component(materials_ready: bool = false) -> C_BuildSiteComponent:
	var site: C_BuildSiteComponent = C_BuildSiteComponent.new()
	var settings := RS_BUILD_SITE_SETTINGS.new()
	var stage := RS_BuildStage.new()
	stage.stage_id = &"foundation"
	stage.required_materials = { &"wood": 2 }
	stage.build_seconds = 3.0
	settings.stages = [stage]
	site.settings = settings
	autofree(site)
	if materials_ready:
		site.placed_materials = { &"wood": 2 }
		site.materials_ready = true
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

func test_brain_loads_with_condition_scorers() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var root: RS_BTUtilitySelector = brain_settings.root as RS_BTUtilitySelector
	assert_not_null(root, "Root should be a RS_BTUtilitySelector")
	if root == null:
		return
	assert_eq(root.child_scorers.size(), 5, "Builder brain should have 5 scorer-child pairs")

func test_first_woods_build_stage_is_reachable_by_wood_loop() -> void:
	var settings_variant: Variant = load(WOODS_BUILD_SITE_SETTINGS_PATH)
	assert_true(settings_variant is RS_BuildSiteSettings, "Woods build site settings should load.")
	if not (settings_variant is RS_BuildSiteSettings):
		return
	var settings: RS_BuildSiteSettings = settings_variant as RS_BuildSiteSettings
	assert_gt(settings.stages.size(), 0, "Woods build site should have at least one stage.")
	if settings.stages.is_empty():
		return
	var stage: RS_BuildStage = settings.stages[0]
	assert_eq(stage.required_materials.keys(), [&"wood"], "First Woods stage should be wood-only so the current Builder brain can advance it.")

func test_walls_stage_requires_mixed_materials() -> void:
	var settings_variant: Variant = load(WOODS_BUILD_SITE_SETTINGS_PATH)
	assert_true(settings_variant is RS_BuildSiteSettings, "Woods build site settings should load.")
	if not (settings_variant is RS_BuildSiteSettings):
		return
	var settings: RS_BuildSiteSettings = settings_variant as RS_BuildSiteSettings
	assert_gt(settings.stages.size(), 2, "Woods build site should define a walls stage at index 2.")
	if settings.stages.size() <= 2:
		return
	var walls_stage: RS_BuildStage = settings.stages[2]
	assert_eq(int(walls_stage.required_materials.get(&"wood", 0)), 2, "Walls stage should require wood.")
	assert_eq(int(walls_stage.required_materials.get(&"stone", 0)), 1, "Walls stage should require stone.")

func test_ai_context_includes_ecs_manager_for_scan_actions() -> void:
	var assembler: U_AIContextAssembler = U_AI_CONTEXT_ASSEMBLER.new()
	var manager: M_ECSManager = M_ECS_MANAGER.new()
	var entity: Node3D = Node3D.new()
	entity.name = "E_Builder"
	var brain: C_AIBrainComponent = C_AIBrainComponent.new()
	var query: U_EntityQuery = U_ENTITY_QUERY.new()
	query.entity = entity
	query.components = {C_AIBrainComponent.COMPONENT_TYPE: brain}
	autofree(manager)
	autofree(entity)
	autofree(brain)
	var context: Dictionary = assembler.build_context(query, brain, {}, null, manager)
	assert_true(context.has(&"ecs_manager"), "AI BT action context should include ecs_manager for scan/target actions.")
	assert_eq(context.get(&"ecs_manager"), manager, "AI BT action context should pass the active scene ECS manager.")

func test_builder_with_empty_inventory_selects_gather_wood() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var needs := _make_needs_component(1.0)
	var inventory := _make_inventory_component(0, 4)
	var context := _build_context(needs, inventory)
	var branch := _find_highest_scoring_branch(brain_settings, context)
	assert_eq(branch, BRANCH_GATHER, "Empty inventory should select gather_wood branch")

func test_builder_with_full_inventory_selects_haul() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var needs := _make_needs_component(1.0)
	var inventory := _make_inventory_component(4, 4)
	var context := _build_context(needs, inventory)
	var branch := _find_highest_scoring_branch(brain_settings, context)
	assert_eq(branch, BRANCH_HAUL, "Full inventory should select haul branch")

func test_builder_with_placed_materials_selects_build_stage() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var needs := _make_needs_component(1.0)
	var inventory := _make_inventory_component(0, 4)
	var build_site := _make_build_site_component(true)
	var context := _build_context(needs, inventory, build_site)
	var branch := _find_highest_scoring_branch(brain_settings, context)
	assert_eq(branch, BRANCH_BUILD, "Placed materials should select build_stage branch")

func test_builder_with_low_thirst_selects_drink() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var needs := _make_needs_component(0.1)
	var inventory := _make_inventory_component(0, 4)
	var context := _build_context(needs, inventory)
	var branch := _find_highest_scoring_branch(brain_settings, context)
	assert_eq(branch, BRANCH_DRINK, "Low thirst should select drink branch")

func test_builder_with_moderate_thirst_does_not_drink() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var needs := _make_needs_component(0.5)
	var inventory := _make_inventory_component(0, 4)
	var context := _build_context(needs, inventory)
	var branch := _find_highest_scoring_branch(brain_settings, context)
	assert_ne(branch, BRANCH_DRINK, "Moderate thirst should not select drink branch")

func test_builder_full_inventory_beats_gather() -> void:
	var brain_settings := _load_brain_settings()
	if brain_settings == null:
		return
	var needs := _make_needs_component(1.0)
	var inventory := _make_inventory_component(4, 4)
	var context := _build_context(needs, inventory)
	var root: RS_BTUtilitySelector = brain_settings.root as RS_BTUtilitySelector
	var gather_score: float = _get_branch_score(root, BRANCH_GATHER, context)
	var haul_score: float = _get_branch_score(root, BRANCH_HAUL, context)
	assert_true(haul_score > gather_score, "Haul should outscore gather when inventory is full")

func _get_branch_score(root: RS_BTUtilitySelector, index: int, context: Dictionary) -> float:
	if index < 0 or index >= root.child_scorers.size():
		return 0.0
	var scorer: Resource = root.child_scorers[index]
	if scorer == null:
		return 0.0
	var score_variant: Variant = scorer.call("score", context)
	if score_variant is float or score_variant is int:
		return float(score_variant)
	return 0.0
