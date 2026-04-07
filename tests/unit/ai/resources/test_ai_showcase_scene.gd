extends BaseTest

const AI_SHOWCASE_SCENE_PATH := "res://scenes/gameplay/gameplay_ai_showcase.tscn"
const PATROL_BRAIN_PATH := "res://resources/ai/patrol_drone/cfg_patrol_drone_brain.tres"
const SENTRY_BRAIN_PATH := "res://resources/ai/sentry/cfg_sentry_brain.tres"
const GUIDE_BRAIN_PATH := "res://resources/ai/guide_prism/cfg_guide_brain.tres"

const REQUIRED_NPC_COMPONENT_PATHS: Array[String] = [
	"Components/C_SpawnStateComponent",
	"Components/C_CharacterStateComponent",
	"Components/C_MovementComponent",
	"Components/C_JumpComponent",
	"Components/C_RotateToInputComponent",
	"Components/C_FloatingComponent",
	"Components/C_AlignWithSurfaceComponent",
	"Components/C_LandingIndicatorComponent",
	"Components/C_HealthComponent",
	"Components/C_InputComponent",
	"Components/C_AIBrainComponent",
]

func _load_scene_root() -> Node:
	var packed_scene_variant: Variant = load(AI_SHOWCASE_SCENE_PATH)
	assert_true(packed_scene_variant is PackedScene, "Expected PackedScene at %s" % AI_SHOWCASE_SCENE_PATH)
	if not (packed_scene_variant is PackedScene):
		return null
	var packed_scene: PackedScene = packed_scene_variant as PackedScene
	var root_variant: Variant = packed_scene.instantiate()
	assert_true(root_variant is Node, "Expected scene instance to be a Node")
	if not (root_variant is Node):
		return null
	var root: Node = root_variant as Node
	add_child_autofree(root)
	return root

func _assert_npc_brain(root: Node, npc_path: NodePath, expected_brain_path: String) -> void:
	var npc: Node = root.get_node_or_null(npc_path)
	assert_not_null(npc, "Expected NPC at %s" % String(npc_path))
	if npc == null:
		return

	var brain_node: Node = npc.get_node_or_null("Components/C_AIBrainComponent")
	assert_not_null(brain_node, "Expected C_AIBrainComponent on NPC at %s" % String(npc_path))
	if brain_node == null:
		return

	var brain_settings_variant: Variant = brain_node.get("brain_settings")
	assert_true(brain_settings_variant is Resource, "Expected brain_settings Resource")
	if not (brain_settings_variant is Resource):
		return
	var brain_settings: Resource = brain_settings_variant as Resource
	assert_eq(brain_settings.resource_path, expected_brain_path,
		"NPC at %s should use brain resource %s" % [String(npc_path), expected_brain_path])

func _assert_npc_component_stack(root: Node, npc_path: NodePath) -> void:
	var npc: Node = root.get_node_or_null(npc_path)
	assert_not_null(npc, "Expected NPC at %s" % String(npc_path))
	if npc == null:
		return

	for component_path in REQUIRED_NPC_COMPONENT_PATHS:
		var component: Node = npc.get_node_or_null(component_path)
		assert_not_null(component, "Expected component at %s/%s" % [String(npc_path), component_path])

	assert_null(
		npc.get_node_or_null("Components/C_PlayerTagComponent"),
		"NPC should not include C_PlayerTagComponent"
	)
	assert_null(
		npc.get_node_or_null("Components/C_GamepadComponent"),
		"NPC should not include C_GamepadComponent"
	)

func test_showcase_scene_loads() -> void:
	var root: Node = _load_scene_root()
	assert_not_null(root, "Expected showcase scene to load without errors")

func test_showcase_has_four_npcs() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	var npcs_group: Node = root.get_node_or_null("Entities/NPCs")
	assert_not_null(npcs_group, "Expected Entities/NPCs group in showcase scene")
	if npcs_group == null:
		return
	var npc_count: int = 0
	for child in npcs_group.get_children():
		if child is Node3D:
			npc_count += 1
	assert_true(npc_count >= 4, "Expected at least 4 NPCs in showcase, found %d" % npc_count)

func test_showcase_patrol_drones_use_patrol_brain() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	_assert_npc_brain(root, NodePath("Entities/NPCs/E_PatrolDroneA"), PATROL_BRAIN_PATH)
	_assert_npc_brain(root, NodePath("Entities/NPCs/E_PatrolDroneB"), PATROL_BRAIN_PATH)

func test_showcase_sentry_uses_sentry_brain() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	_assert_npc_brain(root, NodePath("Entities/NPCs/E_Sentry"), SENTRY_BRAIN_PATH)

func test_showcase_guide_prism_uses_guide_brain() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	_assert_npc_brain(root, NodePath("Entities/NPCs/E_GuidePrism"), GUIDE_BRAIN_PATH)

func test_showcase_npcs_have_unified_component_stack() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	_assert_npc_component_stack(root, NodePath("Entities/NPCs/E_PatrolDroneA"))
	_assert_npc_component_stack(root, NodePath("Entities/NPCs/E_PatrolDroneB"))
	_assert_npc_component_stack(root, NodePath("Entities/NPCs/E_Sentry"))
	_assert_npc_component_stack(root, NodePath("Entities/NPCs/E_GuidePrism"))

func test_showcase_has_patrol_waypoints() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	for waypoint_name in ["WaypointA", "WaypointB", "WaypointC", "WaypointD"]:
		var path := NodePath("Entities/Waypoints/" + waypoint_name)
		assert_not_null(root.get_node_or_null(path), "Expected %s in showcase scene" % waypoint_name)

func test_showcase_has_guard_waypoints() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	for waypoint_name in ["WaypointGuardA", "WaypointGuardB", "WaypointGuardC"]:
		var path := NodePath("Entities/Waypoints/" + waypoint_name)
		assert_not_null(root.get_node_or_null(path), "Expected %s in showcase scene" % waypoint_name)

func test_showcase_has_path_markers() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	for marker_name in ["PathMarkerA", "PathMarkerB", "PathMarkerC", "PathMarkerD"]:
		var path := NodePath("Entities/PathMarkers/" + marker_name)
		assert_not_null(root.get_node_or_null(path), "Expected %s in showcase scene" % marker_name)

func test_showcase_has_interaction_and_noise_nodes() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	assert_not_null(
		root.get_node_or_null("Entities/Interactions/Inter_ActivatableNode"),
		"Expected Entities/Interactions/Inter_ActivatableNode in showcase"
	)
	assert_not_null(
		root.get_node_or_null("Entities/NoiseSources/Inter_NoiseSourceA"),
		"Expected Entities/NoiseSources/Inter_NoiseSourceA in showcase"
	)

func test_showcase_has_room_fade_shell() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	var shell: Node = root.get_node_or_null("SceneObjects/SO_RoomFadeShell")
	assert_not_null(shell, "Expected SceneObjects/SO_RoomFadeShell for room/wall fading")
	if shell == null:
		return
	var component: Node = shell.get_node_or_null("C_RoomFadeGroupComponent")
	assert_not_null(component, "SO_RoomFadeShell should have a C_RoomFadeGroupComponent child")
	for wall_name in [
		"SO_WallNorth", "SO_WallSouth", "SO_WallEast", "SO_WallWest", "SO_Ceiling",
		"SO_ZoneDividerWestNorth", "SO_ZoneDividerWestSouth",
		"SO_ZoneDividerEastNorth", "SO_ZoneDividerEastSouth",
	]:
		assert_not_null(
			shell.get_node_or_null(wall_name),
			"Expected %s under SO_RoomFadeShell" % wall_name
		)

func test_showcase_has_wall_visibility_system() -> void:
	var root: Node = _load_scene_root()
	if root == null:
		return
	var system: Node = root.get_node_or_null("Systems/Core/S_WallVisibilitySystem")
	assert_not_null(system, "Expected Systems/Core/S_WallVisibilitySystem in showcase scene")

func test_showcase_registered_in_scene_registry() -> void:
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("ai_showcase"))
	assert_false(scene_data.is_empty(), "ai_showcase should be registered in scene registry")
	assert_eq(String(scene_data.get("path", "")), AI_SHOWCASE_SCENE_PATH)
	assert_eq(scene_data.get("scene_type", -1), U_SceneRegistry.SceneType.GAMEPLAY)
