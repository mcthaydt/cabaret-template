@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder
		.create_root("StaticBody3D", "E_WoodsStockpile")
		.add_csg_box("Mesh", Vector3(1.5, 0.5, 1.5), Color(0.6, 0.45, 0.25))
		.add_collision_box("CollisionShape3D", Vector3(2, 1, 2))
		.add_ecs_component_by_path(
			"res://scripts/demo/ecs/components/c_inventory_component.gd",
			"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_inventory_stockpile.tres",
			{})
		.save("res://scenes/demo/prefabs/prefab_woods_stockpile.tscn")
	print("prefab_woods_stockpile rebuilt.")
