@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/demo/gameplay/gameplay_demo_room.tscn"
const TEMPLATE_PATH := "res://scenes/core/templates/tmpl_base_scene.tscn"

func _run() -> void:
	var packed_variant: Variant = load(TEMPLATE_PATH)
	if not (packed_variant is PackedScene):
		printerr("Failed to load template: %s" % TEMPLATE_PATH)
		return
	var template: PackedScene = packed_variant as PackedScene
	var root: Node = template.instantiate()

	var spawn_points: Node = root.get_node_or_null("Entities/SpawnPoints")
	if spawn_points != null:
		var spawn := Marker3D.new()
		spawn.name = "sp_default"
		spawn.position = Vector3(0, 1.0, 0)
		spawn_points.add_child(spawn)
		_set_owner_recursive(spawn, root)

	var packed: PackedScene = PackedScene.new()
	var pack_result: int = packed.pack(root)
	if pack_result != OK:
		printerr("Failed to pack scene: %d" % pack_result)
		root.queue_free()
		return

	var save_result: int = ResourceSaver.save(packed, OUTPUT_PATH)
	if save_result != OK:
		printerr("Failed to save scene: %d" % save_result)
	else:
		print("Scene saved: %s" % OUTPUT_PATH)

	root.queue_free()


func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)
