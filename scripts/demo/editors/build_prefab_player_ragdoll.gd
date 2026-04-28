@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character_ragdoll.tscn")
	builder.save("res://scenes/core/prefabs/prefab_player_ragdoll.tscn")
	print("prefab_player_ragdoll rebuilt.")
