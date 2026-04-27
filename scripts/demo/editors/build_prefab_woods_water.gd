@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("StaticBody3D", "E_WoodsWater")
	builder.add_csg_box("Mesh", Vector3(2, 0.15, 2), Color(0.2, 0.4, 0.8, 0.7))
	builder.add_collision_box("CollisionShape3D", Vector3(3, 0.3, 3))
	builder.add_ecs_component_by_path(
		"res://scripts/demo/ecs/components/c_resource_node_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_resource_node_water.tres",
		{})
	builder.save("res://scenes/demo/prefabs/prefab_woods_water.tscn")
	print("prefab_woods_water rebuilt.")
