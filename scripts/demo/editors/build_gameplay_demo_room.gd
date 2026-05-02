@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/demo/gameplay/gameplay_demo_room.tscn"
const MARKER_LIGHTING_GROUP := preload("res://scripts/core/scene_structure/marker_lighting_group.gd")
const PROFILE_DEMO_DEFAULT := preload("res://resources/demo/lighting/profiles/cfg_character_lighting_profile_demo_default.tres")
const L_GLOBAL_ZONE_SCRIPT := preload("res://scripts/core/gameplay/l_global_zone.gd")

func _run() -> void:
	var builder := U_TemplateBaseSceneBuilder.new()
	builder.create_root()
	builder.build_scene_objects()
	builder.build_environment()
	builder.build_systems()
	builder.build_managers()
	builder.build_entities()

	var root: Node3D = builder.build()
	_build_lighting(root)
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

func _build_lighting(root: Node3D) -> void:
	var lighting := Node.new()
	lighting.name = "Lighting"
	lighting.set_script(MARKER_LIGHTING_GROUP)
	root.add_child(lighting)

	var global_zone := Node3D.new()
	global_zone.name = "L_GlobalZone"
	global_zone.set_script(L_GLOBAL_ZONE_SCRIPT)
	global_zone.profile = PROFILE_DEMO_DEFAULT
	lighting.add_child(global_zone)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.set_owner(owner)
	if not node.get_scene_file_path().is_empty():
		return
	for child in node.get_children():
		_set_owner_recursive(child, owner)
