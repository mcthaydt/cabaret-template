extends GutTest

const U_AI_RENDER_PROBE_PATH := "res://scripts/utils/debug/u_ai_render_probe.gd"


func _new_probe_script() -> Script:
	var script_variant: Variant = load(U_AI_RENDER_PROBE_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % U_AI_RENDER_PROBE_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script


func test_build_render_probe_null_safe_on_missing_body() -> void:
	var probe_script: Script = _new_probe_script()
	if probe_script == null:
		return
	var entity := Node3D.new()
	autofree(entity)
	var probe: String = probe_script.build_probe_string(entity, null, null)
	assert_string_contains(probe, "body_visible=false")
	assert_string_contains(probe, "body_visible_tree=false")


func test_build_render_probe_null_safe_on_missing_visual() -> void:
	var probe_script: Script = _new_probe_script()
	if probe_script == null:
		return
	var entity := Node3D.new()
	autofree(entity)
	var body := CharacterBody3D.new()
	autofree(body)
	entity.add_child(body)
	var probe: String = probe_script.build_probe_string(entity, body, null)
	assert_string_contains(probe, "visual_path=<null>")
	assert_string_contains(probe, "visual_type=null")


func test_build_render_probe_reports_body_position() -> void:
	var probe_script: Script = _new_probe_script()
	if probe_script == null:
		return
	var entity := Node3D.new()
	autofree(entity)
	var body := CharacterBody3D.new()
	autofree(body)
	entity.add_child(body)
	body.position = Vector3(1.5, 2.0, -3.25)

	var probe: String = probe_script.build_probe_string(entity, body, null)
	assert_string_contains(probe, "body_pos=%s" % str(body.position))


func test_build_render_probe_reports_visual_transparency_when_geometry() -> void:
	var probe_script: Script = _new_probe_script()
	if probe_script == null:
		return
	var entity := Node3D.new()
	autofree(entity)
	var body := CharacterBody3D.new()
	autofree(body)
	var visual := MeshInstance3D.new()
	autofree(visual)

	entity.add_child(body)
	body.add_child(visual)
	visual.name = "Visual"
	visual.transparency = 0.65

	var probe: String = probe_script.build_probe_string(entity, body, null)
	assert_string_contains(probe, "visual_type=MeshInstance3D")
	assert_string_contains(probe, "visual_transparency=%s" % str(visual.transparency))
