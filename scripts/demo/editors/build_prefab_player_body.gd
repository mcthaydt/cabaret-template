@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "PlayerBodyVisualRoot")

	builder.add_child_scene("res://scenes/core/prefabs/prefab_character.tscn", "CharacterMesh")
	builder.override_property("CharacterMesh", "transform", Transform3D.IDENTITY.translated(Vector3(0, -0.5, 0)))

	var direction: MeshInstance3D = MeshInstance3D.new()
	direction.name = "Direction_Mesh"
	direction.transform = Transform3D(0.39169633, 0, 0, 0, 0.15378642, 0, 0, 0, 0.36884245, -0.019476414, 2.6623948, -0.4746977)
	var box: BoxMesh = BoxMesh.new()
	direction.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.08627451, 0.3529412, 0.29803923)
	direction.material_override = mat
	builder.add_child_to(".", direction)

	builder.override_property("Direction_Mesh", "visible", false)

	var ground: Sprite3D = Sprite3D.new()
	ground.name = "GroundIndicator"
	ground.transform = Transform3D(0.2, 0, 0, 0, -8.742278e-09, -0.2, 0, 0.2, -8.742278e-09, 0, -2.3227184, 0)
	ground.modulate = Color(1, 1, 1, 0.49803922)
	ground.texture = load("res://assets/core/textures/tex_shadow_blob.png")
	builder.add_child_to(".", ground)

	builder.save("res://scenes/core/prefabs/prefab_player_body.tscn")
	print("prefab_player_body rebuilt.")
