@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"npc")
	builder.set_tags([&"npc", &"ai", &"character"])

	builder.override_property("Player_Body/CollisionShape3D", "transform", Transform3D.IDENTITY.translated(Vector3(0, 0.96823025, 0)))

	for ray_name in ["Center", "Forward", "Back", "Left", "Right", "ForwardLeft", "ForwardRight", "BackLeft", "BackRight"]:
		builder.override_property("Player_Body/HoverRays/%s" % ray_name, "target_position", Vector3(0, -2.5, 0))

	builder.add_child_scene_to("Player_Body", "res://scenes/demo/prefabs/prefab_demo_npc_body.tscn", "Body_Mesh")

	var floating_settings := load("res://scripts/core/resources/ecs/rs_floating_settings.gd") as Script
	var floating_res := floating_settings.new() as Resource
	builder.override_property("Components/C_FloatingComponent", "settings", floating_res)

	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_detection_component.gd")
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_spawn_recovery_component.gd",
		"res://resources/core/base_settings/gameplay/cfg_spawn_recovery_default.tres")
	builder.save("res://scenes/demo/prefabs/prefab_demo_npc.tscn")
	print("prefab_demo_npc rebuilt.")
