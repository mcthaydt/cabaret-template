@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/templates/tmpl_base_scene_2_5d.tscn"

func _run() -> void:
	var builder := U_TemplateBaseScene2_5dBuilder.new()
	builder.create_root()
	builder.build_scene_objects()
	builder.build_environment()
	builder.build_systems()
	builder.build_managers()
	builder.build_entities()
	if builder.save(OUTPUT_PATH):
		print("tmpl_base_scene_2_5d built: %s" % OUTPUT_PATH)
	else:
		printerr("Failed to build tmpl_base_scene_2_5d")
