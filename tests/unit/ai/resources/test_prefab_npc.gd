extends BaseTest

const NPC_PREFAB_PATH := "res://scenes/demo/prefabs/prefab_demo_npc.tscn"
const CHARACTER_TEMPLATE_PATH := "res://scenes/core/templates/tmpl_character.tscn"

const REQUIRED_COMPONENT_PATHS: Array[String] = [
	"Components/C_SpawnStateComponent",
	"Components/C_CharacterStateComponent",
	"Components/C_MovementComponent",
	"Components/C_JumpComponent",
	"Components/C_RotateToInputComponent",
	"Components/C_FloatingComponent",
	"Components/C_AlignWithSurfaceComponent",
	"Components/C_LandingIndicatorComponent",
	"Components/C_HealthComponent",
	"Components/C_SpawnRecoveryComponent",
]

func _instantiate_npc_prefab() -> Node:
	var packed_scene_variant: Variant = load(NPC_PREFAB_PATH)
	assert_true(packed_scene_variant is PackedScene, "Expected PackedScene at %s" % NPC_PREFAB_PATH)
	if not (packed_scene_variant is PackedScene):
		return null

	var packed_scene: PackedScene = packed_scene_variant as PackedScene
	var root_variant: Variant = packed_scene.instantiate()
	assert_true(root_variant is Node, "Expected npc prefab to instantiate as Node")
	if not (root_variant is Node):
		return null

	var root: Node = root_variant as Node
	add_child_autofree(root)
	return root

func _instantiate_character_template() -> Node:
	var packed_scene_variant: Variant = load(CHARACTER_TEMPLATE_PATH)
	assert_true(packed_scene_variant is PackedScene, "Expected PackedScene at %s" % CHARACTER_TEMPLATE_PATH)
	if not (packed_scene_variant is PackedScene):
		return null

	var packed_scene: PackedScene = packed_scene_variant as PackedScene
	var root_variant: Variant = packed_scene.instantiate()
	assert_true(root_variant is Node, "Expected character template to instantiate as Node")
	if not (root_variant is Node):
		return null

	var root: Node = root_variant as Node
	add_child_autofree(root)
	return root

func test_npc_prefab_has_all_base_character_components() -> void:
	var root: Node = _instantiate_npc_prefab()
	if root == null:
		return

	for component_path in REQUIRED_COMPONENT_PATHS:
		var component: Node = root.get_node_or_null(component_path)
		assert_not_null(component, "Expected component at %s" % component_path)

func test_npc_has_ai_brain() -> void:
	var root: Node = _instantiate_npc_prefab()
	if root == null:
		return
	assert_not_null(root.get_node_or_null("Components/C_AIBrainComponent"))

func test_npc_has_input() -> void:
	var root: Node = _instantiate_npc_prefab()
	if root == null:
		return
	assert_not_null(root.get_node_or_null("Components/C_InputComponent"))

func test_npc_no_player_tag() -> void:
	var root: Node = _instantiate_npc_prefab()
	if root == null:
		return
	assert_null(root.get_node_or_null("Components/C_PlayerTagComponent"))

func test_npc_no_gamepad() -> void:
	var root: Node = _instantiate_npc_prefab()
	if root == null:
		return
	assert_null(root.get_node_or_null("Components/C_GamepadComponent"))

func test_npc_prefab_body_mesh_has_visual() -> void:
	var root: Node = _instantiate_npc_prefab()
	if root == null:
		return
	var body_mesh := root.get_node_or_null("Player_Body/Body_Mesh") as Node3D
	assert_not_null(body_mesh, "Expected Body_Mesh node in prefab_demo_npc")
	if body_mesh == null:
		return
	var visual := body_mesh.get_node_or_null("Visual") as MeshInstance3D
	assert_not_null(visual, "prefab_demo_npc body should include a Visual MeshInstance3D node")

func test_character_template_has_no_body_mesh_instance() -> void:
	var root: Node = _instantiate_character_template()
	if root == null:
		return
	assert_null(
		root.get_node_or_null("Player_Body/Body_Mesh"),
		"tmpl_character should not include body mesh visuals; prefabs should own visual meshes"
	)
