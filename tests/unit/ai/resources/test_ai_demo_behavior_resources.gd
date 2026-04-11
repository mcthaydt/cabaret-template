extends BaseTest

const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")
const RS_AI_GOAL := preload("res://scripts/resources/ai/goals/rs_ai_goal.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/tasks/rs_ai_primitive_task.gd")
const I_AI_ACTION := preload("res://scripts/interfaces/i_ai_action.gd")
const U_HTN_PLANNER := preload("res://scripts/utils/ai/u_htn_planner.gd")

const PATROL_BRAIN_PATH := "res://resources/ai/patrol_drone/cfg_patrol_drone_brain.tres"
const SENTRY_BRAIN_PATH := "res://resources/ai/sentry/cfg_sentry_brain.tres"
const GUIDE_BRAIN_PATH := "res://resources/ai/guide_prism/cfg_guide_brain.tres"

const POWER_CORE_SCENE_PATH := "res://scenes/gameplay/gameplay_power_core.tscn"
const COMMS_ARRAY_SCENE_PATH := "res://scenes/gameplay/gameplay_comms_array.tscn"
const NAV_NEXUS_SCENE_PATH := "res://scenes/gameplay/gameplay_nav_nexus.tscn"
const INTER_AI_DEMO_FLAG_ZONE_SCRIPT_PATH := "res://scripts/gameplay/inter_ai_demo_flag_zone.gd"
const INTER_HAZARD_ZONE_SCRIPT_PATH := "res://scripts/gameplay/inter_hazard_zone.gd"
const NAV_FALL_HAZARD_CONFIG_PATH := "res://resources/interactions/hazards/cfg_hazard_nav_nexus_fall.tres"

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

func _load_brain(path: String) -> Resource:
	var resource_variant: Variant = load(path)
	assert_not_null(resource_variant, "Expected brain resource to exist: %s" % path)
	if not (resource_variant is Resource):
		return null
	return resource_variant as Resource

func _find_goal_by_id(goals: Array[Resource], goal_id: StringName) -> Resource:
	for goal in goals:
		if goal == null:
			continue
		var current_goal_id: Variant = goal.get("goal_id")
		if current_goal_id == goal_id:
			return goal
	return null

func _assert_goal_has_actions(goal: Resource, context: Dictionary = {}) -> void:
	assert_not_null(goal, "Expected goal resource to be non-null")
	if goal == null:
		return

	var root_task: Variant = goal.get("root_task")
	assert_not_null(root_task, "Goal should have a root_task")
	if root_task == null:
		return

	var queue: Array[Resource] = U_HTN_PLANNER.decompose(root_task, context)
	assert_false(queue.is_empty(), "Goal root_task should decompose into at least one primitive task")
	for task_variant in queue:
		assert_true(task_variant is RS_AI_PRIMITIVE_TASK, "Decomposed tasks should be RS_AIPrimitiveTask")
		if not (task_variant is RS_AI_PRIMITIVE_TASK):
			continue
		var task: Resource = task_variant as Resource
		var action_variant: Variant = task.get("action")
		assert_true(action_variant is I_AI_ACTION, "Primitive task action must implement I_AIAction")

func _assert_brain_goals(path: String, default_goal_id: StringName, expected_goal_ids: Array[StringName]) -> void:
	var brain: Resource = _load_brain(path)
	if brain == null:
		return
	assert_true(brain is RS_AI_BRAIN_SETTINGS, "%s should be an RS_AIBrainSettings resource" % path)
	if not (brain is RS_AI_BRAIN_SETTINGS):
		return

	var actual_default_goal_id: Variant = brain.get("default_goal_id")
	assert_eq(actual_default_goal_id, default_goal_id)

	var goals_variant: Variant = brain.get("goals")
	assert_true(goals_variant is Array, "Brain goals should be an array")
	if not (goals_variant is Array):
		return
	var goals_untyped: Array = goals_variant as Array
	var goals: Array[Resource] = []
	for goal_variant in goals_untyped:
		assert_true(goal_variant is RS_AI_GOAL, "Each goal should be RS_AIGoal")
		if goal_variant is Resource:
			goals.append(goal_variant as Resource)

	assert_eq(goals.size(), expected_goal_ids.size())
	for goal_id in expected_goal_ids:
		var goal: Resource = _find_goal_by_id(goals, goal_id)
		assert_not_null(goal, "Expected goal %s in %s" % [String(goal_id), path])
		_assert_goal_has_actions(goal)

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

func _assert_goal_condition_path(brain_path: String, goal_id: StringName, expected_state_path: String) -> void:
	var brain: Resource = _load_brain(brain_path)
	if brain == null:
		return
	var goals_variant: Variant = brain.get("goals")
	assert_true(goals_variant is Array, "Brain goals should be an array")
	if not (goals_variant is Array):
		return
	var goals_raw: Array = goals_variant as Array
	var goals: Array[Resource] = []
	for goal_variant in goals_raw:
		if goal_variant is Resource:
			goals.append(goal_variant as Resource)

	var goal: Resource = _find_goal_by_id(goals, goal_id)
	assert_not_null(goal, "Expected goal %s in %s" % [String(goal_id), brain_path])
	if goal == null:
		return

	var conditions_variant: Variant = goal.get("conditions")
	assert_true(conditions_variant is Array, "Goal conditions should be an array")
	if not (conditions_variant is Array):
		return
	var conditions: Array = conditions_variant as Array
	assert_false(conditions.is_empty(), "Goal should define at least one condition")
	if conditions.is_empty():
		return
	var condition := conditions[0] as Resource
	assert_not_null(condition, "First condition should be a valid resource")
	if condition == null:
		return
	assert_eq(String(condition.get("state_path")), expected_state_path)

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

func test_patrol_drone_brain_has_expected_goals_and_tasks() -> void:
	_assert_brain_goals(
		PATROL_BRAIN_PATH,
		StringName("patrol"),
		[
			StringName("patrol"),
			StringName("investigate"),
			StringName("investigate_proximity"),
		]
	)

func test_sentry_brain_has_expected_goals_and_tasks() -> void:
	_assert_brain_goals(
		SENTRY_BRAIN_PATH,
		StringName("guard"),
		[
			StringName("guard"),
			StringName("investigate_disturbance"),
			StringName("investigate_disturbance_proximity"),
		]
	)

func test_guide_prism_brain_has_expected_goals_and_tasks() -> void:
	_assert_brain_goals(
		GUIDE_BRAIN_PATH,
		StringName("show_path"),
		[
			StringName("show_path"),
			StringName("encourage"),
			StringName("celebrate"),
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
	_assert_goal_condition_path(
		PATROL_BRAIN_PATH,
		StringName("investigate"),
		"gameplay.ai_demo_flags.power_core_activated"
	)
	_assert_goal_condition_path(
		SENTRY_BRAIN_PATH,
		StringName("investigate_disturbance"),
		"gameplay.ai_demo_flags.comms_disturbance_heard"
	)
	_assert_goal_condition_path(
		GUIDE_BRAIN_PATH,
		StringName("celebrate"),
		"gameplay.ai_demo_flags.nav_goal_reached"
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
