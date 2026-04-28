@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "E_GoalZone")
	builder.set_entity_id(&"goalzone")
	builder.set_tags([&"objective", &"goal"])
	builder.add_ecs_component_by_path(
		"res://scripts/core/gameplay/inter_victory_zone.gd",
		"res://resources/core/interactions/victory/cfg_victory_default.tres",
		{
			"visual_paths": [NodePath("Visual"), NodePath("Sparkles")],
		})
	builder.add_csg_cylinder("Visual", 0.7910156, 2.0715332, Color.WHITE)
	builder.save("res://scenes/core/prefabs/prefab_goal_zone.tscn")
	print("prefab_goal_zone rebuilt.")
