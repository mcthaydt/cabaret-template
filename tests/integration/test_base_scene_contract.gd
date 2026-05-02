extends BaseTest

const BASE_SCENE_PATH := "res://scenes/core/templates/tmpl_base_scene.tscn"
const PLAYER_PATH := "res://scenes/core/prefabs/prefab_player.tscn"
const PLAYER_BODY_PATH := "res://scenes/core/prefabs/prefab_player_body.tscn"

func _load_scene(path: String) -> Node:
	var packed_variant: Variant = load(path)
	if not (packed_variant is PackedScene):
		return null
	var packed: PackedScene = packed_variant as PackedScene
	var root_variant: Variant = packed.instantiate()
	if not (root_variant is Node):
		return null
	var root: Node = root_variant as Node
	add_child_autofree(root)
	return root

func _load_base_scene() -> Node:
	return _load_scene(BASE_SCENE_PATH)


func test_base_scene_has_node3d_world_container() -> void:
	var root: Node = _load_base_scene()
	assert_not_null(root, "Base scene must load")
	if root == null:
		return
	assert_true(root is Node3D, "Base scene root must be Node3D for hybrid world")
	assert_eq(root.name, "GameplayRoot", "Base scene root must be named GameplayRoot")


func test_base_scene_has_scene_objects_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var scene_objects: Node = root.get_node_or_null("SceneObjects")
	assert_not_null(scene_objects, "Base scene must have SceneObjects container")
	if scene_objects != null:
		assert_true(scene_objects is Node3D, "SceneObjects must be Node3D")


func test_base_scene_has_environment_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var env: Node = root.get_node_or_null("Environment")
	assert_not_null(env, "Base scene must have Environment container")


func test_base_scene_has_systems_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var systems: Node = root.get_node_or_null("Systems")
	assert_not_null(systems, "Base scene must have Systems container")


func test_base_scene_has_managers_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var managers: Node = root.get_node_or_null("Managers")
	assert_not_null(managers, "Base scene must have Managers container")


func test_base_scene_has_spawn_points_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var spawns: Node = root.get_node_or_null("Entities/SpawnPoints")
	assert_not_null(spawns, "Base scene must have SpawnPoints under Entities")


func test_base_scene_has_no_demo_specific_systems() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	assert_null(root.get_node_or_null("Systems/Core/S_AIBehaviorSystem"),
		"Base scene must not contain demo AI behavior system")
	assert_null(root.get_node_or_null("Systems/Core/S_MoveTargetFollowerSystem"),
		"Base scene must not contain demo move target follower system")


func test_base_scene_has_camera_template_entity() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var camera: Node = root.get_node_or_null("Entities/E_CameraRoot")
	assert_not_null(camera, "Base scene must have E_CameraRoot camera entity")


func test_canonical_base_scene_loads_with_shared_structure() -> void:
	var root: Node = _load_scene(BASE_SCENE_PATH)
	assert_not_null(root, "Canonical base scene must load")
	if root == null:
		return
	assert_true(root is Node3D, "Canonical base scene root must be Node3D")
	assert_eq(root.name, "GameplayRoot", "Canonical base scene root must be named GameplayRoot")
	assert_not_null(root.get_node_or_null("SceneObjects"), "Canonical base scene must have SceneObjects")
	assert_not_null(root.get_node_or_null("Systems/Core/S_VCamSystem"), "Canonical base scene must reuse vCam system")
	assert_not_null(root.get_node_or_null("Systems/Movement/S_MovementSystem"), "Canonical base scene must reuse movement system")
	assert_not_null(root.get_node_or_null("Managers/M_ECSManager"), "Canonical base scene must have scene-local ECS manager")
	assert_not_null(root.get_node_or_null("Entities/E_CameraRoot"), "Canonical base scene must reuse camera template")
	assert_not_null(root.get_node_or_null("Entities/SpawnPoints"), "Canonical base scene must include SpawnPoints")


func test_canonical_base_scene_uses_positive_floor_size() -> void:
	var root: Node = _load_scene(BASE_SCENE_PATH)
	if root == null:
		return
	var floor_node: Node = root.get_node_or_null("SceneObjects/SO_Floor")
	assert_not_null(floor_node, "Canonical base scene must have SO_Floor")
	assert_true(floor_node is CSGBox3D, "Canonical floor must be a CSGBox3D")
	if floor_node is CSGBox3D:
		var floor_size: Vector3 = (floor_node as CSGBox3D).size
		assert_gt(floor_size.x, 0.0, "Canonical floor width must be positive")
		assert_gt(floor_size.z, 0.0, "Canonical floor depth must be positive")


func test_canonical_base_scene_matches_2_5d_room_scale() -> void:
	var root: Node = _load_scene(BASE_SCENE_PATH)
	if root == null:
		return
	var floor_node := root.get_node_or_null("SceneObjects/SO_Floor") as CSGBox3D
	var ceiling_node := root.get_node_or_null("SceneObjects/SO_Ceiling") as CSGBox3D
	var west_wall := root.get_node_or_null("SceneObjects/SO_Wall_West") as CSGBox3D
	var north_wall := root.get_node_or_null("SceneObjects/SO_Wall_North") as CSGBox3D
	assert_not_null(floor_node, "Canonical floor must exist")
	assert_not_null(ceiling_node, "Canonical ceiling must exist")
	assert_not_null(west_wall, "Canonical west wall must exist")
	assert_not_null(north_wall, "Canonical north wall must exist")
	if floor_node == null or ceiling_node == null or west_wall == null or north_wall == null:
		return

	assert_eq(floor_node.size, Vector3(5.0, 0.01, 5.0),
		"Canonical floor must use 1 unit per tile over a 5 x 5 room")
	assert_eq(ceiling_node.position, Vector3(0.0, 5.0, 0.0),
		"Canonical ceiling must align with the standard 5-unit wall height")
	assert_eq(west_wall.position, Vector3(-2.5, 2.5, 0.0),
		"Canonical west wall must sit on the 5-tile room edge")
	assert_eq(west_wall.size, Vector3(0.01, 5.0, 5.0),
		"Canonical west wall must use 5-unit height and 5-unit depth")
	assert_eq(north_wall.position, Vector3(0.0, 2.5, -2.5),
		"Canonical north wall must sit on the 5-tile room edge")
	assert_eq(north_wall.size, Vector3(5.0, 5.0, 0.01),
		"Canonical north wall must use 5-unit height and 5-unit width")


func test_canonical_base_scene_uses_positive_wall_heights() -> void:
	var root: Node = _load_scene(BASE_SCENE_PATH)
	if root == null:
		return
	for wall_name in ["SO_Wall_West", "SO_Wall_East", "SO_Wall_North", "SO_Wall_South"]:
		var wall_node: Node = root.get_node_or_null("SceneObjects/%s" % wall_name)
		assert_not_null(wall_node, "Canonical base scene must include %s" % wall_name)
		assert_true(wall_node is CSGBox3D, "%s must be a CSGBox3D" % wall_name)
		if wall_node is CSGBox3D:
			assert_gt((wall_node as CSGBox3D).size.y, 0.0,
				"%s must use a positive wall height" % wall_name)


func test_canonical_base_scene_uses_canonical_player_prefab() -> void:
	var root: Node = _load_scene(BASE_SCENE_PATH)
	if root == null:
		return
	var player: Node = root.get_node_or_null("Entities/E_Player")
	assert_not_null(player, "Canonical base scene must have E_Player")
	if player == null:
		return
	assert_eq(player.get_scene_file_path(), PLAYER_PATH,
		"Canonical base scene must instance the canonical player prefab")


func test_canonical_player_prefab_reuses_shared_ecs_components() -> void:
	var player: Node = _load_scene(PLAYER_PATH)
	assert_not_null(player, "Canonical player prefab must load")
	if player == null:
		return
	for component_path in [
		"Components/C_MovementComponent",
		"Components/C_InputComponent",
		"Components/C_SpawnStateComponent",
		"Components/C_SpawnRecoveryComponent",
		"Components/C_HealthComponent",
		"Components/C_PlayerTagComponent",
	]:
		assert_not_null(player.get_node_or_null(component_path),
			"Canonical player prefab must reuse %s" % component_path)


func test_canonical_player_prefab_uses_sprite_body_visual() -> void:
	var player: Node = _load_scene(PLAYER_PATH)
	if player == null:
		return
	var body_mesh: Node = player.get_node_or_null("Player_Body/Body_Mesh")
	assert_not_null(body_mesh, "Canonical player prefab must attach Body_Mesh under Player_Body")
	if body_mesh == null:
		return
	assert_eq(body_mesh.get_scene_file_path(), PLAYER_BODY_PATH,
		"Canonical player Body_Mesh must instance the canonical body visual prefab")
	var sprite: Node = body_mesh.get_node_or_null("DirectionalSprite")
	assert_not_null(sprite, "Canonical body visual must expose DirectionalSprite")
	assert_true(sprite is Sprite3D, "DirectionalSprite must be Sprite3D")
	if sprite is Sprite3D:
		assert_almost_eq((sprite as Sprite3D).pixel_size, 1.0 / 384.0, 0.0000001,
			"canonical sprite pixel size must match 384px = 1 world unit for Xenogears scale")
		assert_eq((sprite as Sprite3D).hframes, 3,
			"canonical sprite must split the 384px sheet into 128px-wide cells")
		assert_eq((sprite as Sprite3D).vframes, 3,
			"canonical sprite must split the 384px sheet into 128px-tall cells")
		assert_eq((sprite as Sprite3D).scale, Vector3.ONE,
			"canonical 128px sprite cell must display as 0.33 x 0.33 world units")
		assert_eq((sprite as Sprite3D).position, Vector3(0.0, 0.165, 0.0),
			"canonical one-third-tile sprite should sit on the floor with its center at half height")
		assert_eq((sprite as Sprite3D).billboard, BaseMaterial3D.BILLBOARD_ENABLED,
			"canonical sprite must billboard to face camera")
		assert_eq((sprite as Sprite3D).texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST,
			"canonical sprite must use nearest-neighbor filtering for pixel art")


func test_canonical_player_collision_uses_smaller_2_5d_footprint() -> void:
	var player: Node = _load_scene(PLAYER_PATH)
	if player == null:
		return
	var collision := player.get_node_or_null("Player_Body/CollisionShape3D") as CollisionShape3D
	assert_not_null(collision, "Canonical player prefab must have collision shape")
	if collision == null:
		return
	assert_eq(collision.position, Vector3(0.0, 0.165, 0.0),
		"Canonical player capsule must be centered on the one-third-tile visual")
	assert_true(collision.shape is CapsuleShape3D,
		"Canonical player collision must use a capsule footprint")
	if collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		assert_almost_eq(capsule.radius, 0.12, 0.001,
			"Canonical player collision radius must stay smaller than the one-third-tile visual")
		assert_almost_eq(capsule.height, 0.33, 0.001,
			"Canonical player collision height must match the one-third-tile visual height")


func test_canonical_player_prefab_does_not_reserialize_body_visual_children() -> void:
	var scene_text := FileAccess.get_file_as_string(PLAYER_PATH)
	assert_false(
		scene_text.contains('parent="Player_Body/Body_Mesh"'),
		"prefab_player.tscn must keep prefab_player_body children inside the nested instance to avoid Godot load-name clashes"
	)
