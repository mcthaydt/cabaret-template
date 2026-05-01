extends BaseTest

const BASE_SCENE_PATH := "res://scenes/core/templates/tmpl_base_scene.tscn"
const BASE_SCENE_2_5D_PATH := "res://scenes/core/templates/tmpl_base_scene_2_5d.tscn"
const PLAYER_2_5D_PATH := "res://scenes/core/prefabs/prefab_player_2_5d.tscn"
const PLAYER_BODY_2_5D_PATH := "res://scenes/core/prefabs/prefab_player_body_2_5d.tscn"

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
	assert_true(root is Node3D, "Base scene root must be Node3D for 2.5D world")
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


func test_2_5d_base_scene_loads_with_shared_structure() -> void:
	var root: Node = _load_scene(BASE_SCENE_2_5D_PATH)
	assert_not_null(root, "2.5D base scene must load")
	if root == null:
		return
	assert_true(root is Node3D, "2.5D base scene root must be Node3D")
	assert_eq(root.name, "GameplayRoot", "2.5D base scene root must be named GameplayRoot")
	assert_not_null(root.get_node_or_null("SceneObjects"), "2.5D base scene must have SceneObjects")
	assert_not_null(root.get_node_or_null("Systems/Core/S_VCamSystem"), "2.5D base scene must reuse vCam system")
	assert_not_null(root.get_node_or_null("Systems/Movement/S_MovementSystem"), "2.5D base scene must reuse movement system")
	assert_not_null(root.get_node_or_null("Managers/M_ECSManager"), "2.5D base scene must have scene-local ECS manager")
	assert_not_null(root.get_node_or_null("Entities/E_CameraRoot"), "2.5D base scene must reuse camera template")
	assert_not_null(root.get_node_or_null("Entities/SpawnPoints/sp_default"), "2.5D base scene must include a default spawn point")


func test_2_5d_base_scene_uses_five_unit_floor() -> void:
	var root: Node = _load_scene(BASE_SCENE_2_5D_PATH)
	if root == null:
		return
	var floor_node: Node = root.get_node_or_null("SceneObjects/SO_Floor")
	assert_not_null(floor_node, "2.5D base scene must have SO_Floor")
	assert_true(floor_node is CSGBox3D, "2.5D floor must be a CSGBox3D")
	if floor_node is CSGBox3D:
		assert_eq((floor_node as CSGBox3D).size, Vector3(5.0, 0.01, 5.0),
			"2.5D default floor must be 5 x 5 units")


func test_2_5d_base_scene_uses_three_unit_walls() -> void:
	var root: Node = _load_scene(BASE_SCENE_2_5D_PATH)
	if root == null:
		return
	for wall_name in ["SO_Wall_West", "SO_Wall_East", "SO_Wall_North", "SO_Wall_South"]:
		var wall_node: Node = root.get_node_or_null("SceneObjects/%s" % wall_name)
		assert_not_null(wall_node, "2.5D base scene must include %s" % wall_name)
		assert_true(wall_node is CSGBox3D, "%s must be a CSGBox3D" % wall_name)
		if wall_node is CSGBox3D:
			assert_eq((wall_node as CSGBox3D).size.y, 3.0,
				"%s must use the 3-unit standard wall height" % wall_name)


func test_2_5d_base_scene_uses_2_5d_player_prefab() -> void:
	var root: Node = _load_scene(BASE_SCENE_2_5D_PATH)
	if root == null:
		return
	var player: Node = root.get_node_or_null("Entities/E_Player")
	assert_not_null(player, "2.5D base scene must have E_Player")
	if player == null:
		return
	assert_eq(player.get_scene_file_path(), PLAYER_2_5D_PATH,
		"2.5D base scene must instance the 2.5D player prefab")


func test_2_5d_player_prefab_reuses_shared_ecs_components() -> void:
	var player: Node = _load_scene(PLAYER_2_5D_PATH)
	assert_not_null(player, "2.5D player prefab must load")
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
			"2.5D player prefab must reuse %s" % component_path)


func test_2_5d_player_prefab_uses_sprite_body_visual() -> void:
	var player: Node = _load_scene(PLAYER_2_5D_PATH)
	if player == null:
		return
	var body_mesh: Node = player.get_node_or_null("Player_Body/Body_Mesh")
	assert_not_null(body_mesh, "2.5D player prefab must attach Body_Mesh under Player_Body")
	if body_mesh == null:
		return
	assert_eq(body_mesh.get_scene_file_path(), PLAYER_BODY_2_5D_PATH,
		"2.5D player Body_Mesh must instance the 2.5D body visual prefab")
	var sprite: Node = body_mesh.get_node_or_null("DirectionalSprite")
	assert_not_null(sprite, "2.5D body visual must expose DirectionalSprite")
	assert_true(sprite is Sprite3D, "DirectionalSprite must be Sprite3D")
	if sprite is Sprite3D:
		assert_eq((sprite as Sprite3D).pixel_size, 1.0 / 128.0,
			"2.5D sprite pixel size must match 128px = 1 world unit")
