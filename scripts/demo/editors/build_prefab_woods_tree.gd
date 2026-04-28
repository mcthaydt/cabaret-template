@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("StaticBody3D", "E_WoodsTree")
	builder.add_csg_cylinder("Trunk", 0.3, 3.0, Color(0.4, 0.26, 0.13))
	var foliage: Node = U_EditorShapeFactory.create_csg_sphere("Foliage", 1.2, Color(0.2, 0.55, 0.15))
	foliage.transform = Transform3D(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, 0.0)
	builder.add_child_to(".", foliage)
	builder.add_collision_box("CollisionShape3D", Vector3(1.5, 3.0, 1.5))
	builder.add_ecs_component_by_path(
		"res://scripts/demo/ecs/components/c_resource_node_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_resource_node_wood.tres",
		{})
	builder.save("res://scenes/demo/prefabs/prefab_woods_tree.tscn")
	print("prefab_woods_tree rebuilt.")
