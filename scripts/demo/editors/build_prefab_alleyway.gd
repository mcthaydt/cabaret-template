@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "NewExterior")

	builder.add_child_scene("res://assets/demo/models/mdl_new_exterior.glb", "ExteriorScene")

	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "StaticBody3D"
	static_body.collision_layer = 33
	builder.add_child_to(".", static_body)

	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.transform = Transform3D.IDENTITY.scaled(Vector3(17, 17, 17)).translated(Vector3(0, 2.4162946, 0))
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.shape = concave
	builder.add_child_to("StaticBody3D", shape)

	builder.save("res://scenes/demo/prefabs/prefab_alleyway.tscn")
	print("prefab_alleyway rebuilt.")
