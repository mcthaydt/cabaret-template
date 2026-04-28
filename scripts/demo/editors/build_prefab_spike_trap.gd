@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "E_SpikeTrap")
	builder.set_entity_id(&"spiketrap")
	builder.set_tags([&"hazard", &"trap"])
	builder.add_ecs_component_by_path(
		"res://scripts/core/gameplay/inter_hazard_zone.gd",
		"res://resources/core/interactions/hazards/cfg_hazard_default.tres",
		{
			"visual_paths": [NodePath("MeshInstance3D"), NodePath("SpikeTips")],
		})
	builder.add_csg_box("MeshInstance3D", Vector3(1.5, 0.5, 1.5), Color.WHITE)
	var spikes: Node = U_EditorShapeFactory.create_csg_cylinder("SpikeTips", 0.0, 1.0, Color.WHITE)
	spikes.transform = Transform3D(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.5, 0.0)
	builder.add_child_to(".", spikes)
	builder.save("res://scenes/core/prefabs/prefab_spike_trap.tscn")
	print("prefab_spike_trap rebuilt.")
