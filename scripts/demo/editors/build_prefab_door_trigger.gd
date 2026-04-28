@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "E_DoorTrigger")
	builder.set_entity_id(&"doortrigger")
	builder.set_tags([&"trigger", &"door"])
	builder.add_ecs_component_by_path(
		"res://scripts/core/gameplay/inter_door_trigger.gd",
		"res://resources/core/interactions/doors/cfg_door_default.tres",
		{})
	var door_visual: Node = U_EditorShapeFactory.create_csg_cylinder("DoorVisual", 0.7910156, 2.0715332, Color.WHITE)
	door_visual.position = Vector3(0.0, -0.40026855, 0.0)
	builder.add_child_to(".", door_visual)
	builder.save("res://scenes/core/prefabs/prefab_door_trigger.tscn")
	print("prefab_door_trigger rebuilt.")
