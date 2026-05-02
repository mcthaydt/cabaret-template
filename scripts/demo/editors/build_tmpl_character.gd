@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/templates/tmpl_character.tscn"

func _run() -> void:
	var builder := U_TmplCharacterBuilder.new()
	builder.create_root()
	builder.add_character_body()
	builder.add_hover_rays()
	builder.add_components()
	if builder.save(OUTPUT_PATH):
		print("tmpl_character built: %s" % OUTPUT_PATH)
	else:
		printerr("Failed to build tmpl_character")
