@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "NPC_BodyMeshRoot")

	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	visual.transform = Transform3D.IDENTITY.translated(Vector3(0, 1.1, 0))
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.8
	sphere_mesh.height = 1.6
	visual.mesh = sphere_mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.9490196, 0.70980394, 0.21568628)
	visual.material_override = mat
	builder.add_child_to(".", visual)

	var ground: Sprite3D = Sprite3D.new()
	ground.name = "GroundIndicator"
	ground.transform = Transform3D(0.2, 0, 0, 0, -8.742278e-09, -0.2, 0, 0.2, -8.742278e-09, 0, -2.3227184, 0)
	ground.modulate = Color(1, 1, 1, 0.49803922)
	ground.texture = load("res://assets/core/textures/tex_shadow_blob.png")
	builder.add_child_to(".", ground)

	builder.save("res://scenes/demo/prefabs/prefab_demo_npc_body.tscn")
	print("prefab_demo_npc_body rebuilt.")
