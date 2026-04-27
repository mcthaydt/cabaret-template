extends SceneTree

func _init() -> void:
	run()
	quit()

func run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("StaticBody3D", "E_WoodsTree")
	builder.add_csg_cylinder("Trunk", 0.3, 3.0, Color(0.4, 0.26, 0.13))
	builder.add_csg_sphere("Foliage", 1.2, Color(0.2, 0.55, 0.15))
	builder.override_property("Foliage", "position", Vector3(0, 2, 0))
	builder.add_collision_box("CollisionShape3D", Vector3(1.5, 3, 1.5))
	builder.add_ecs_component_by_path(
		"res://scripts/demo/ecs/components/c_resource_node_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_resource_node_wood.tres",
		{})
	builder.save("res://scenes/demo/prefabs/prefab_woods_tree.tscn")
	print("Tree regenerated.")

	builder = U_EditorPrefabBuilder.new()
	builder.create_root("StaticBody3D", "E_WoodsConstructionSite")
	builder.add_csg_box("Foundation", Vector3(3, 0.3, 3), Color(0.65, 0.6, 0.55))
	builder.override_property("Foundation", "visible", false)
	builder.add_csg_box("Frame", Vector3(3, 2, 0.1), Color(0.55, 0.4, 0.2))
	builder.override_property("Frame", "visible", false)
	builder.override_property("Frame", "position", Vector3(0, 1, 0))
	builder.add_csg_box("Walls", Vector3(3, 2.5, 3), Color(0.85, 0.8, 0.7))
	builder.override_property("Walls", "visible", false)
	builder.add_csg_box("Roof", Vector3(3.5, 0.2, 3.5), Color(0.5, 0.3, 0.15))
	builder.override_property("Roof", "visible", false)
	builder.override_property("Roof", "position", Vector3(0, 2.8, 0))
	builder.add_collision_box("CollisionShape3D", Vector3(3, 2, 3))
	builder.add_ecs_component_by_path(
		"res://scripts/demo/ecs/components/c_build_site_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_build_site_house.tres",
		{})
	builder.add_child_scene("res://scenes/demo/debug/debug_woods_build_site_label.tscn", "DebugWoodsBuildSiteLabel")
	builder.save("res://scenes/demo/prefabs/prefab_woods_construction_site.tscn")
	print("Construction site regenerated.")
