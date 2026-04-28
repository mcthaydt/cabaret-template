@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"wolf")
	builder.set_tags([&"predator", &"ai", &"woods"])

	var body_mesh: CSGBox3D = CSGBox3D.new()
	body_mesh.name = "Body_Mesh"
	body_mesh.transform = Transform3D(Basis(Vector3(0.9, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.4)), Vector3(0.0, 1.0, 0.0))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.24, 0.26, 0.29)
	body_mesh.material = mat
	builder.add_child_to("Player_Body", body_mesh)

	builder.override_property("Components/C_MovementComponent", "settings", load("res://resources/demo/base_settings/ai_woods/ai_woods/cfg_movement_woods_wolf.tres"))
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_detection_component.gd", "", {
		"detection_radius": 14.0,
		"detection_exit_radius": 20.0,
		"target_tag": &"prey",
	})
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_move_target_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_ai_brain_component.gd",
		"res://resources/demo/ai/woods/wolf/cfg_woods_wolf_brain_script.tres")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_needs_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_needs_wolf.tres")
	builder.add_child_scene("res://scenes/demo/debug/debug_woods_agent_label.tscn", "DebugWoodsAgentLabel")
	builder.save("res://scenes/demo/prefabs/prefab_woods_wolf.tscn")
	print("prefab_woods_wolf rebuilt.")
