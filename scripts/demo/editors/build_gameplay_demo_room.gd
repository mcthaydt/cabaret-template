@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/demo/gameplay/gameplay_demo_room.tscn"

func _run() -> void:
	var builder := U_TemplateBaseSceneBuilder.new()
	builder.create_root()
	builder.build_scene_objects()
	builder.build_environment()
	builder.build_systems()
	builder.build_managers()
	builder.build_entities()

	var root: Node3D = builder.build()
	var spawn_points: Node = root.get_node_or_null("Entities/SpawnPoints")
	if spawn_points != null:
		var spawn := Marker3D.new()
		spawn.name = "sp_default"
		spawn.position = Vector3(0, 0.0, 0)
		spawn_points.add_child(spawn)

	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		printerr("Failed to pack scene: %d" % pack_result)
		return

	var save_result := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_result != OK:
		printerr("Failed to save scene: %d" % save_result)
	else:
		print("Scene saved: %s" % OUTPUT_PATH)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.set_owner(owner)
	if not node.get_scene_file_path().is_empty():
		return
	for child in node.get_children():
		_set_owner_recursive(child, owner)
