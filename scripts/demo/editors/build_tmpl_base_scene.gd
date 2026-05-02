@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/templates/tmpl_base_scene.tscn"

func _run() -> void:
	var builder := U_TemplateBaseSceneBuilder.new()
	builder.create_root()
	builder.build_scene_objects()
	builder.build_environment()
	builder.build_systems()
	builder.build_managers()
	builder.build_entities()
	if builder.save(OUTPUT_PATH):
		print("tmpl_base_scene built: %s" % OUTPUT_PATH)
	else:
		printerr("Failed to build tmpl_base_scene")
