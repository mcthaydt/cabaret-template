@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "E_Checkpoint_SafeZone")
	builder.set_entity_id(&"checkpoint_safezone")
	builder.set_tags([&"checkpoint", &"objective"])
	builder.add_ecs_component_by_path(
		"res://scripts/core/gameplay/inter_checkpoint_zone.gd",
		"res://resources/core/interactions/checkpoints/cfg_checkpoint_default.tres",
		{})
	builder.save("res://scenes/core/prefabs/prefab_checkpoint_safe_zone.tscn")
	print("prefab_checkpoint_safe_zone rebuilt.")
