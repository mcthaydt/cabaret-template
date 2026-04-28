@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"builder")
	builder.set_tags([&"ai", &"woods", &"builder"])

	var body_mesh: CSGBox3D = CSGBox3D.new()
	body_mesh.name = "Body_Mesh"
	body_mesh.transform = Transform3D(0.6, 0.0, 0.0, 0.0, 1.8, 0.0, 0.0, 0.0, 0.5, 0.0, 1.0, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.55, 0.35, 0.15)
	body_mesh.material = mat
	builder.add_child_to("Player_Body", body_mesh)

	builder.override_property("Components/C_MovementComponent", "settings", load("res://resources/demo/base_settings/ai_woods/ai_woods/cfg_movement_woods.tres"))
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_detection_component.gd", "", {
		"detection_radius": 10.0,
		"detection_exit_radius": 15.0,
		"target_tag": &"predator",
	})
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_move_target_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_ai_brain_component.gd",
		"res://resources/demo/ai/woods/builder/cfg_builder_brain_script.tres")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_needs_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_needs_builder.tres")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_inventory_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_inventory_builder.tres")
	builder.add_child_scene("res://scenes/demo/debug/debug_woods_agent_label.tscn", "DebugWoodsAgentLabel")
	builder.save("res://scenes/demo/prefabs/prefab_woods_builder.tscn")
	print("prefab_woods_builder rebuilt.")
