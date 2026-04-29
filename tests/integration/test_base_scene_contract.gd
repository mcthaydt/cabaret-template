extends BaseTest

const BASE_SCENE_PATH := "res://scenes/core/templates/tmpl_base_scene.tscn"

func _load_base_scene() -> Node:
	var packed_variant: Variant = load(BASE_SCENE_PATH)
	if not (packed_variant is PackedScene):
		return null
	var packed: PackedScene = packed_variant as PackedScene
	var root_variant: Variant = packed.instantiate()
	if not (root_variant is Node):
		return null
	var root: Node = root_variant as Node
	add_child_autofree(root)
	return root


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
