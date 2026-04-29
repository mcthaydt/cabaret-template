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

	var scene_objects: Node = root.get_node_or_null("SceneObjects")
	if scene_objects == null:
		printerr("SceneObjects node not found in template")
		root.queue_free()
		return

	# Remove existing template geometry (floor + blocks)
	for child in scene_objects.get_children():
		scene_objects.remove_child(child)
		child.queue_free()

	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.45, 0.45, 0.5, 1.0)

	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.25, 0.2, 1.0)

	var roof_mat: StandardMaterial3D = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.35, 0.3, 0.25, 1.0)

	var WALL_THICKNESS: float = 0.2
	var WALL_HEIGHT: float = 3.0
	var ROOM_WIDTH: float = 10.0
	var ROOM_DEPTH: float = 10.0
	var HALF_W: float = ROOM_WIDTH / 2.0
	var HALF_D: float = ROOM_DEPTH / 2.0

	# Floor
	var floor := CSGBox3D.new()
	floor.name = "SO_Floor"
	floor.size = Vector3(ROOM_WIDTH, 0.1, ROOM_DEPTH)
	floor.position = Vector3(0, 0, 0)
	floor.material = floor_mat
	scene_objects.add_child(floor)
	_set_owner_recursive(floor, root)

	# Walls
	var wall_north := CSGBox3D.new()
	wall_north.name = "SO_Wall_North"
	wall_north.size = Vector3(ROOM_WIDTH, WALL_HEIGHT, WALL_THICKNESS)
	wall_north.position = Vector3(0, WALL_HEIGHT / 2.0, -HALF_D)
	wall_north.material = wall_mat
	scene_objects.add_child(wall_north)
	_set_owner_recursive(wall_north, root)

	var wall_south := CSGBox3D.new()
	wall_south.name = "SO_Wall_South"
	wall_south.size = Vector3(ROOM_WIDTH, WALL_HEIGHT, WALL_THICKNESS)
	wall_south.position = Vector3(0, WALL_HEIGHT / 2.0, HALF_D)
	wall_south.material = wall_mat
	scene_objects.add_child(wall_south)
	_set_owner_recursive(wall_south, root)

	var wall_east := CSGBox3D.new()
	wall_east.name = "SO_Wall_East"
	wall_east.size = Vector3(WALL_THICKNESS, WALL_HEIGHT, ROOM_DEPTH)
	wall_east.position = Vector3(HALF_W, WALL_HEIGHT / 2.0, 0)
	wall_east.material = wall_mat
	scene_objects.add_child(wall_east)
	_set_owner_recursive(wall_east, root)

	var wall_west := CSGBox3D.new()
	wall_west.name = "SO_Wall_West"
	wall_west.size = Vector3(WALL_THICKNESS, WALL_HEIGHT, ROOM_DEPTH)
	wall_west.position = Vector3(-HALF_W, WALL_HEIGHT / 2.0, 0)
	wall_west.material = wall_mat
	scene_objects.add_child(wall_west)
	_set_owner_recursive(wall_west, root)

	# Roof
	var roof := CSGBox3D.new()
	roof.name = "SO_Roof"
	roof.size = Vector3(ROOM_WIDTH, 0.1, ROOM_DEPTH)
	roof.position = Vector3(0, WALL_HEIGHT, 0)
	roof.material = roof_mat
	scene_objects.add_child(roof)
	_set_owner_recursive(roof, root)

	# Default spawn point
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
