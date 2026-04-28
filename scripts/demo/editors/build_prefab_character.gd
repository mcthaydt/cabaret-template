@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"character")
	builder.set_tags([&"character"])
	builder.add_child_scene("res://assets/core/models/mdl_new_character.glb", "Character")
	builder.save("res://scenes/core/prefabs/prefab_character.tscn")
	print("prefab_character rebuilt.")
