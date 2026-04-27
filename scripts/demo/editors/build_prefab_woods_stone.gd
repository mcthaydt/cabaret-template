@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder
		.create_root("StaticBody3D", "E_WoodsStone")
		.add_csg_sphere("Mesh", 0.6, Color(0.55, 0.55, 0.55))
		.add_collision_box("CollisionShape3D", Vector3(1.5, 1, 1.5))
		.add_ecs_component_by_path(
			"res://scripts/demo/ecs/components/c_resource_node_component.gd",
			"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_resource_node_stone.tres",
			{})
		.save("res://scenes/demo/prefabs/prefab_woods_stone.tscn")
	print("prefab_woods_stone rebuilt.")
