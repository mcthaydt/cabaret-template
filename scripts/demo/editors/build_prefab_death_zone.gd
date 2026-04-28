@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "E_DeathZone")
	builder.set_entity_id(&"deathzone")
	builder.set_tags([&"hazard", &"death"])
	builder.add_ecs_component_by_path(
		"res://scripts/core/gameplay/inter_hazard_zone.gd",
		"res://resources/core/interactions/hazards/cfg_hazard_default.tres",
		{})
	builder.save("res://scenes/core/prefabs/prefab_death_zone.tscn")
	print("prefab_death_zone rebuilt.")
