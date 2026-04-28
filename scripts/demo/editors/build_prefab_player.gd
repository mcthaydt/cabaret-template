@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"player")
	builder.set_tags([&"player", &"character"])

	builder.add_child_scene_to("Player_Body", "res://scenes/core/prefabs/prefab_player_body.tscn", "Body_Mesh")

	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_gamepad_component.gd",
		"res://resources/core/input/gamepad_settings/cfg_default_gamepad_settings.tres")
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_player_tag_component.gd")
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_surface_detector_component.gd", "", {
		"character_body_path": NodePath("../../Player_Body"),
	})
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_spawn_recovery_component.gd",
		"res://resources/core/base_settings/gameplay/cfg_spawn_recovery_player_default.tres")
	builder.save("res://scenes/core/prefabs/prefab_player.tscn")
	print("prefab_player rebuilt.")
