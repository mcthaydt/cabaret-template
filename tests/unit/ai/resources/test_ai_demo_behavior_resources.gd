extends BaseTest

const RS_AI_BRAIN_SETTINGS := preload("res://scripts/core/resources/ai/brain/rs_ai_brain_settings.gd")

const PATROL_BRAIN_PATH := "res://resources/ai/patrol_drone/cfg_patrol_drone_brain.tres"
const SENTRY_BRAIN_PATH := "res://resources/ai/sentry/cfg_sentry_brain.tres"
const GUIDE_BRAIN_PATH := "res://resources/ai/guide_prism/cfg_guide_brain.tres"

const POWER_CORE_SCENE_PATH := "res://scenes/gameplay/gameplay_power_core.tscn"
const COMMS_ARRAY_SCENE_PATH := "res://scenes/gameplay/gameplay_comms_array.tscn"
const NAV_NEXUS_SCENE_PATH := "res://scenes/gameplay/gameplay_nav_nexus.tscn"
const INTER_AI_DEMO_FLAG_ZONE_SCRIPT_PATH := "res://scripts/demo/gameplay/inter_ai_demo_flag_zone.gd"
const INTER_HAZARD_ZONE_SCRIPT_PATH := "res://scripts/core/gameplay/inter_hazard_zone.gd"
const NAV_FALL_HAZARD_CONFIG_PATH := "res://resources/interactions/hazards/cfg_hazard_nav_nexus_fall.tres"

const BT_UTILITY_SELECTOR_SCRIPT_PATH := "res://scripts/core/resources/bt/rs_bt_utility_selector.gd"
const BT_SELECTOR_SCRIPT_PATH := "res://scripts/core/resources/bt/rs_bt_selector.gd"
const BT_SEQUENCE_SCRIPT_PATH := "res://scripts/core/resources/bt/rs_bt_sequence.gd"
const AI_SCORER_CONDITION_SCRIPT_PATH := "res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_condition.gd"
const AI_SCORER_CONSTANT_SCRIPT_PATH := "res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_constant.gd"
const QB_REDUX_FIELD_CONDITION_SCRIPT_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd"

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
	"Components/C_SpawnRecoveryComponent",
	"Components/C_InputComponent",
	"Components/C_AIBrainComponent",
]

func _load_brain(path: String) -> RS_AIBrainSettings:
	var resource_variant: Variant = load(path)
	assert_not_null(resource_variant, "Expected brain resource to exist: %s" % path)
	if not (resource_variant is RS_AI_BRAIN_SETTINGS):
		assert_true(false, "%s should be an RS_AIBrainSettings resource" % path)
		return null
	return resource_variant as RS_AIBrainSettings

func _assert_script_path(resource: Resource, expected_path: String, message: String) -> void:
	assert_not_null(resource, message)
	if resource == null:
		return
	var script_variant: Variant = resource.get_script()
	assert_true(script_variant is Script, "%s should have script %s" % [message, expected_path])
	if not (script_variant is Script):
		return
	var script: Script = script_variant as Script
	assert_eq(script.resource_path, expected_path, message)

func _assert_condition_scorer_state_path(
	scorer: Resource,
	expected_state_path: String,
	label: String
) -> void:
	_assert_script_path(scorer, AI_SCORER_CONDITION_SCRIPT_PATH, "%s scorer type" % label)
	if scorer == null:
		return
	var condition_variant: Variant = scorer.get("condition")
	assert_true(condition_variant is Resource, "%s scorer should hold a condition resource" % label)
	if not (condition_variant is Resource):
		return
	var condition: Resource = condition_variant as Resource
	_assert_script_path(condition, QB_REDUX_FIELD_CONDITION_SCRIPT_PATH, "%s scorer condition type" % label)
	assert_eq(String(condition.get("state_path")), expected_state_path, "%s scorer condition path" % label)

func _assert_brain_root_contract(
	brain_path: String,
	expected_root_name: String,
	expected_condition_paths: Array[String]
) -> void:
	var brain: RS_AIBrainSettings = _load_brain(brain_path)
	if brain == null:
		return

	var root_variant: Variant = brain.get("root")
	assert_true(root_variant is Resource, "%s root should be a BT resource" % brain_path)
	if not (root_variant is Resource):
		return
	var root: Resource = root_variant as Resource

	_assert_script_path(root, BT_UTILITY_SELECTOR_SCRIPT_PATH, "%s root must be RS_BTUtilitySelector" % brain_path)
	assert_eq(String(root.resource_name), expected_root_name, "%s root resource_name" % brain_path)

	var scorers_variant: Variant = root.get("child_scorers")
	assert_true(scorers_variant is Array, "%s root child_scorers should be an array" % brain_path)
	if not (scorers_variant is Array):
		return
	var scorers: Array = scorers_variant as Array
	assert_eq(scorers.size(), 3, "%s root should define three scorer branches" % brain_path)
	if scorers.size() != 3:
		return

	assert_true(
		expected_condition_paths.size() == 2,
		"Internal test contract: expected_condition_paths must contain two condition paths"
	)
	if expected_condition_paths.size() != 2:
		return
	_assert_condition_scorer_state_path(scorers[0] as Resource, expected_condition_paths[0], "%s scorer[0]" % brain_path)
	_assert_condition_scorer_state_path(scorers[1] as Resource, expected_condition_paths[1], "%s scorer[1]" % brain_path)
	_assert_script_path(
		scorers[2] as Resource,
		AI_SCORER_CONSTANT_SCRIPT_PATH,
		"%s scorer[2] type" % brain_path
	)
	if scorers[2] is Resource:
		var scorer_constant: Resource = scorers[2] as Resource
		assert_almost_eq(float(scorer_constant.get("value")), 1.0, 0.0001, "%s scorer[2] constant value" % brain_path)

	var children_variant: Variant = root.get("children")
	assert_true(children_variant is Array, "%s root children should be an array" % brain_path)
	if not (children_variant is Array):
		return
	var children: Array = children_variant as Array
	assert_eq(children.size(), 3, "%s root should define three child branches" % brain_path)
	if children.size() != 3:
		return

	_assert_script_path(children[0] as Resource, BT_SELECTOR_SCRIPT_PATH, "%s child[0] should be selector" % brain_path)
	_assert_script_path(children[1] as Resource, BT_SELECTOR_SCRIPT_PATH, "%s child[1] should be selector" % brain_path)
	_assert_script_path(children[2] as Resource, BT_SEQUENCE_SCRIPT_PATH, "%s child[2] should be sequence" % brain_path)

func _assert_scene_brain_path(scene_path: String, npc_brain_node_path: NodePath, expected_brain_path: String) -> void:
	var packed_scene_variant: Variant = load(scene_path)
	assert_true(packed_scene_variant is PackedScene, "Expected PackedScene at %s" % scene_path)
	if not (packed_scene_variant is PackedScene):
		return
	var packed_scene: PackedScene = packed_scene_variant as PackedScene
	var root_variant: Variant = packed_scene.instantiate()
	assert_true(root_variant is Node, "Expected scene instance to be a Node for %s" % scene_path)
	if not (root_variant is Node):
		return
	var root: Node = root_variant as Node
	add_child_autofree(root)

	var brain_node: Node = root.get_node_or_null(npc_brain_node_path)
	assert_not_null(brain_node, "Expected AI brain node at %s in %s" % [String(npc_brain_node_path), scene_path])
	if brain_node == null:
		return

	var brain_settings_variant: Variant = brain_node.get("brain_settings")
	assert_true(brain_settings_variant is Resource, "Expected brain_settings Resource on %s" % String(npc_brain_node_path))
	if not (brain_settings_variant is Resource):
		return
	var brain_settings: Resource = brain_settings_variant as Resource
	assert_eq(brain_settings.resource_path, expected_brain_path)

func _load_scene_root(scene_path: String) -> Node:
	var packed_scene_variant: Variant = load(scene_path)
	assert_true(packed_scene_variant is PackedScene, "Expected PackedScene at %s" % scene_path)
	if not (packed_scene_variant is PackedScene):
		return null
	var packed_scene: PackedScene = packed_scene_variant as PackedScene
	var root_variant: Variant = packed_scene.instantiate()
	assert_true(root_variant is Node, "Expected scene instance to be a Node for %s" % scene_path)
	if not (root_variant is Node):
		return null
	var root: Node = root_variant as Node
	add_child_autofree(root)
	return root

func _assert_npc_visual_exists(scene_path: String, visual_path: NodePath) -> void:
	var root: Node = _load_scene_root(scene_path)
	if root == null:
		return
	var visual_variant: Variant = root.get_node_or_null(visual_path)
	assert_not_null(visual_variant, "Expected visual node at %s in %s" % [String(visual_path), scene_path])
	assert_true(visual_variant is MeshInstance3D, "Expected MeshInstance3D visual at %s in %s" % [String(visual_path), scene_path])

func _assert_demo_npc_component_stack(scene_path: String, npc_path: NodePath) -> void:
	var root: Node = _load_scene_root(scene_path)
	if root == null:
		return
	var npc: Node = root.get_node_or_null(npc_path)
	assert_not_null(npc, "Expected NPC root at %s in %s" % [String(npc_path), scene_path])
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
	assert_null(
		npc.get_node_or_null("Components/C_SurfaceDetectorComponent"),
		"NPC should not include C_SurfaceDetectorComponent"
	)

func test_patrol_drone_brain_has_expected_bt_root_and_branches() -> void:
	_assert_brain_root_contract(
		PATROL_BRAIN_PATH,
		"patrol_drone_bt_root",
		[
			"gameplay.ai_demo_flags.power_core_proximity",
			"gameplay.ai_demo_flags.power_core_activated",
		]
	)

func test_sentry_brain_has_expected_bt_root_and_branches() -> void:
	_assert_brain_root_contract(
		SENTRY_BRAIN_PATH,
		"sentry_bt_root",
		[
			"gameplay.ai_demo_flags.comms_disturbance_proximity",
			"gameplay.ai_demo_flags.comms_disturbance_heard",
		]
	)

func test_guide_prism_brain_has_expected_bt_root_and_branches() -> void:
	_assert_brain_root_contract(
		GUIDE_BRAIN_PATH,
		"guide_prism_bt_root",
		[
			"gameplay.ai_demo_flags.nav_goal_reached",
			"gameplay.entities.player.is_on_floor",
		]
	)

func test_demo_scenes_wire_npcs_to_m10_brain_resources() -> void:
	_assert_scene_brain_path(
		POWER_CORE_SCENE_PATH,
		NodePath("Entities/NPCs/E_PatrolDrone/Components/C_AIBrainComponent"),
		PATROL_BRAIN_PATH
	)
	_assert_scene_brain_path(
		COMMS_ARRAY_SCENE_PATH,
		NodePath("Entities/NPCs/E_Sentry/Components/C_AIBrainComponent"),
		SENTRY_BRAIN_PATH
	)
	_assert_scene_brain_path(
		NAV_NEXUS_SCENE_PATH,
		NodePath("Entities/NPCs/E_GuidePrism/Components/C_AIBrainComponent"),
		GUIDE_BRAIN_PATH
	)

func test_demo_npc_visual_exists() -> void:
	_assert_npc_visual_exists(
		POWER_CORE_SCENE_PATH,
		NodePath("Entities/NPCs/E_PatrolDrone/Player_Body/Body_Mesh/Visual")
	)
	_assert_npc_visual_exists(
		COMMS_ARRAY_SCENE_PATH,
		NodePath("Entities/NPCs/E_Sentry/Player_Body/Body_Mesh/Visual")
	)
	_assert_npc_visual_exists(
		NAV_NEXUS_SCENE_PATH,
		NodePath("Entities/NPCs/E_GuidePrism/Player_Body/Body_Mesh/Visual")
	)

func test_demo_scenes_use_unified_npc_component_stack() -> void:
	_assert_demo_npc_component_stack(
		POWER_CORE_SCENE_PATH,
		NodePath("Entities/NPCs/E_PatrolDrone")
	)
	_assert_demo_npc_component_stack(
		COMMS_ARRAY_SCENE_PATH,
		NodePath("Entities/NPCs/E_Sentry")
	)
	_assert_demo_npc_component_stack(
		NAV_NEXUS_SCENE_PATH,
		NodePath("Entities/NPCs/E_GuidePrism")
	)

func test_demo_goal_conditions_use_durable_ai_demo_flags() -> void:
	_assert_brain_root_contract(
		PATROL_BRAIN_PATH,
		"patrol_drone_bt_root",
		[
			"gameplay.ai_demo_flags.power_core_proximity",
			"gameplay.ai_demo_flags.power_core_activated",
		]
	)
	_assert_brain_root_contract(
		SENTRY_BRAIN_PATH,
		"sentry_bt_root",
		[
			"gameplay.ai_demo_flags.comms_disturbance_proximity",
			"gameplay.ai_demo_flags.comms_disturbance_heard",
		]
	)
	_assert_brain_root_contract(
		GUIDE_BRAIN_PATH,
		"guide_prism_bt_root",
		[
			"gameplay.ai_demo_flags.nav_goal_reached",
			"gameplay.entities.player.is_on_floor",
		]
	)

func test_demo_scenes_wire_trigger_zones_to_runtime_scripts() -> void:
	var power_root: Node = _load_scene_root(POWER_CORE_SCENE_PATH)
	if power_root != null:
		var power_trigger := power_root.get_node_or_null("Entities/Interactions/Inter_ActivatableNode") as Area3D
		assert_not_null(power_trigger, "Power Core activatable trigger should exist")
		if power_trigger != null:
			var power_script := power_trigger.get_script() as Script
			assert_not_null(power_script)
			if power_script != null:
				assert_eq(power_script.resource_path, INTER_AI_DEMO_FLAG_ZONE_SCRIPT_PATH)
			assert_eq(power_trigger.get("ai_flag_id"), StringName("power_core_activated"))

	var comms_root: Node = _load_scene_root(COMMS_ARRAY_SCENE_PATH)
	if comms_root != null:
		var noise_a := comms_root.get_node_or_null("Entities/NoiseSources/Inter_NoiseSourceA") as Area3D
		assert_not_null(noise_a, "Comms noise source A should exist")
		if noise_a != null:
			var noise_a_script := noise_a.get_script() as Script
			assert_not_null(noise_a_script)
			if noise_a_script != null:
				assert_eq(noise_a_script.resource_path, INTER_AI_DEMO_FLAG_ZONE_SCRIPT_PATH)
			assert_eq(noise_a.get("ai_flag_id"), StringName("comms_disturbance_heard"))

	var nav_root: Node = _load_scene_root(NAV_NEXUS_SCENE_PATH)
	if nav_root != null:
		var victory_trigger := nav_root.get_node_or_null("Entities/Triggers/Inter_VictoryZone") as Area3D
		assert_not_null(victory_trigger, "Nav Nexus victory trigger should exist")
		if victory_trigger != null:
			var victory_script := victory_trigger.get_script() as Script
			assert_not_null(victory_script)
			if victory_script != null:
				assert_eq(victory_script.resource_path, INTER_AI_DEMO_FLAG_ZONE_SCRIPT_PATH)
			assert_eq(victory_trigger.get("ai_flag_id"), StringName("nav_goal_reached"))

		var fall_trigger := nav_root.get_node_or_null("Entities/Triggers/Inter_FallDetectionArea") as Area3D
		assert_not_null(fall_trigger, "Nav Nexus fall trigger should exist")
		if fall_trigger != null:
			var fall_script := fall_trigger.get_script() as Script
			assert_not_null(fall_script)
			if fall_script != null:
				assert_eq(fall_script.resource_path, INTER_HAZARD_ZONE_SCRIPT_PATH)
			var config_variant: Variant = fall_trigger.get("config")
			assert_true(config_variant is Resource, "Fall trigger should expose hazard config")
			if config_variant is Resource:
				var config_resource: Resource = config_variant as Resource
				assert_eq(config_resource.resource_path, NAV_FALL_HAZARD_CONFIG_PATH)
