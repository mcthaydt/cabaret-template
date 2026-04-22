extends BaseTest

const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
const RS_BUILD_SITE_SETTINGS := preload("res://scripts/resources/ai/world/rs_build_site_settings.gd")
const RS_BUILD_STAGE := preload("res://scripts/resources/ai/world/rs_build_stage.gd")

func _make_stages(count: int, required: Dictionary = {}) -> Array[RS_BuildStage]:
	var stages: Array[RS_BuildStage] = []
	for i in count:
		var stage: RS_BuildStage = RS_BUILD_STAGE.new()
		stage.stage_id = StringName("stage_%d" % i)
		stage.required_materials = required.duplicate()
		stage.build_seconds = 2.0
		stages.append(stage)
	return stages

func _instantiate(stages: Array[RS_BuildStage] = []) -> Variant:
	var settings: RS_BuildSiteSettings = RS_BUILD_SITE_SETTINGS.new()
	if stages.is_empty():
		stages = _make_stages(1)
	settings.stages = stages
	var component := C_BUILD_SITE_COMPONENT.new()
	component.settings = settings
	add_child_autofree(component)
	return component

func test_component_type_constant() -> void:
	assert_eq(C_BUILD_SITE_COMPONENT.COMPONENT_TYPE, StringName("C_BuildSiteComponent"))

func test_init_sets_component_type() -> void:
	var component: Variant = _instantiate()
	assert_eq(component.get_component_type(), C_BUILD_SITE_COMPONENT.COMPONENT_TYPE)

func test_defaults() -> void:
	var component: Variant = _instantiate()
	assert_eq(component.current_stage_index, 0)
	assert_eq(component.placed_materials.size(), 0)
	assert_eq(component.current_build_elapsed, 0.0)
	assert_false(component.completed)
	assert_eq(component.reserved_by_entity_id, StringName(""))

func test_current_stage_returns_stage_at_index() -> void:
	var stages := _make_stages(2)
	var component: Variant = _instantiate(stages)
	var stage: Variant = component.current_stage()
	assert_not_null(stage)
	assert_eq(stage.stage_id, StringName("stage_0"))

func test_required_materials_met_true_when_placed_sufficient() -> void:
	var stages := _make_stages(1, {&"wood": 3})
	var component: Variant = _instantiate(stages)
	component.placed_materials[&"wood"] = 3
	assert_true(component.required_materials_met())

func test_required_materials_met_false_when_deficit() -> void:
	var stages := _make_stages(1, {&"wood": 3})
	var component: Variant = _instantiate(stages)
	component.placed_materials[&"wood"] = 1
	assert_false(component.required_materials_met())

func test_advance_stage_increments_index() -> void:
	var stages := _make_stages(3)
	var component: Variant = _instantiate(stages)
	assert_true(component.advance_stage())
	assert_eq(component.current_stage_index, 1)
	assert_eq(component.current_build_elapsed, 0.0)

func test_advance_stage_marks_completed_at_last_stage() -> void:
	var stages := _make_stages(2)
	var component: Variant = _instantiate(stages)
	component.advance_stage()
	assert_true(component.advance_stage())
	assert_true(component.completed)
	assert_eq(component.current_stage_index, 2)

func test_advance_stage_returns_false_when_completed() -> void:
	var stages := _make_stages(1)
	var component: Variant = _instantiate(stages)
	component.advance_stage()
	assert_false(component.advance_stage())

func test_refresh_materials_ready_updates_flag() -> void:
	var stages := _make_stages(1, {&"wood": 2})
	var component: Variant = _instantiate(stages)
	assert_false(component.materials_ready)
	component.placed_materials[&"wood"] = 2
	component.refresh_materials_ready()
	assert_true(component.materials_ready)

func test_advance_stage_resets_materials_ready() -> void:
	var stages := _make_stages(2, {&"wood": 1})
	var component: Variant = _instantiate(stages)
	component.materials_ready = true
	component.advance_stage()
	assert_false(component.materials_ready)

func test_get_current_stage_missing_materials_returns_positive_deficits_only() -> void:
	var stages := _make_stages(1, {&"wood": 2, &"stone": 1})
	var component: Variant = _instantiate(stages)
	component.placed_materials = {&"wood": 3, &"stone": 0}
	var missing: Dictionary = component.get_current_stage_missing_materials()
	assert_eq(missing.size(), 1)
	assert_eq(int(missing.get(&"stone", 0)), 1)

func test_get_next_missing_material_type_prefers_highest_deficit() -> void:
	var stages := _make_stages(1, {&"wood": 3, &"stone": 1})
	var component: Variant = _instantiate(stages)
	component.placed_materials = {&"wood": 1}
	assert_eq(component.get_next_missing_material_type(), &"wood")
