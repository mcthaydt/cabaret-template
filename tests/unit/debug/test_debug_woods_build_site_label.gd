extends BaseTest

const LABEL_SCRIPT_PATH := "res://scripts/debug/debug_woods_build_site_label.gd"
const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
const RS_BUILD_SITE_SETTINGS := preload("res://scripts/resources/ai/world/rs_build_site_settings.gd")
const RS_BUILD_STAGE := preload("res://scripts/resources/ai/world/rs_build_stage.gd")

func _load_label_script() -> Script:
	var script_variant: Variant = load(LABEL_SCRIPT_PATH)
	assert_not_null(script_variant, "Expected label script to exist: %s" % LABEL_SCRIPT_PATH)
	if not (script_variant is Script):
		return null
	return script_variant as Script

func _make_build_site_component() -> C_BuildSiteComponent:
	var build_site: C_BuildSiteComponent = C_BUILD_SITE_COMPONENT.new()
	var settings: RS_BuildSiteSettings = RS_BUILD_SITE_SETTINGS.new()
	var stage_foundation: RS_BuildStage = RS_BUILD_STAGE.new()
	stage_foundation.stage_id = &"foundation"
	stage_foundation.required_materials = {&"wood": 2, &"stone": 1}
	var stage_roof: RS_BuildStage = RS_BUILD_STAGE.new()
	stage_roof.stage_id = &"roof"
	stage_roof.required_materials = {&"wood": 2}
	settings.stages = [stage_foundation, stage_roof]
	build_site.settings = settings
	build_site.placed_materials = {&"wood": 1}
	build_site.refresh_materials_ready()
	return build_site

func _make_label_fixture() -> Dictionary:
	var label_script: Script = _load_label_script()
	if label_script == null:
		return {}
	var root := Node3D.new()
	root.name = "E_WoodsConstructionSite"
	add_child_autofree(root)
	var build_site: C_BuildSiteComponent = _make_build_site_component()
	build_site.name = "C_BuildSiteComponent"
	root.add_child(build_site)
	autofree(build_site)
	var label_variant: Variant = label_script.new()
	assert_true(label_variant is Label3D, "DebugWoodsBuildSiteLabel should extend Label3D.")
	if not (label_variant is Label3D):
		return {}
	var label: Label3D = label_variant as Label3D
	root.add_child(label)
	autofree(label)
	return {"label": label, "build_site": build_site}

func test_label_shows_current_stage_and_missing_materials() -> void:
	var fixture: Dictionary = _make_label_fixture()
	if fixture.is_empty():
		return
	var label: Label3D = fixture.get("label") as Label3D
	var build_site: C_BuildSiteComponent = fixture.get("build_site") as C_BuildSiteComponent
	assert_not_null(label)
	assert_not_null(build_site)
	if label == null or build_site == null:
		return
	label.call("_update_label_text")
	assert_string_contains(label.text, "house: building")
	assert_string_contains(label.text, "stage: 1/2 (foundation)")
	assert_string_contains(label.text, "missing:")
	assert_string_contains(label.text, "wood:1")
	assert_string_contains(label.text, "stone:1")

func test_label_shows_completed_state_when_site_finished() -> void:
	var fixture: Dictionary = _make_label_fixture()
	if fixture.is_empty():
		return
	var label: Label3D = fixture.get("label") as Label3D
	var build_site: C_BuildSiteComponent = fixture.get("build_site") as C_BuildSiteComponent
	assert_not_null(label)
	assert_not_null(build_site)
	if label == null or build_site == null:
		return
	build_site.current_stage_index = build_site.settings.stages.size()
	build_site.completed = true
	build_site.materials_ready = false
	label.call("_update_label_text")
	assert_string_contains(label.text, "house: completed")
	assert_string_contains(label.text, "stage: 2/2")
	assert_string_contains(label.text, "missing: none")
