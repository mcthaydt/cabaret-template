extends BaseTest

const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_AI_GOAL := preload("res://scripts/resources/ai/rs_ai_goal.gd")
const RS_AI_PRIMITIVE_TASK := preload("res://scripts/resources/ai/rs_ai_primitive_task.gd")
const I_AI_ACTION := preload("res://scripts/interfaces/i_ai_action.gd")
const U_HTN_PLANNER := preload("res://scripts/utils/ai/u_htn_planner.gd")

const PATROL_BRAIN_PATH := "res://resources/ai/patrol_drone/cfg_patrol_drone_brain.tres"
const SENTRY_BRAIN_PATH := "res://resources/ai/sentry/cfg_sentry_brain.tres"
const GUIDE_BRAIN_PATH := "res://resources/ai/guide_prism/cfg_guide_brain.tres"

const POWER_CORE_SCENE_PATH := "res://scenes/gameplay/gameplay_power_core.tscn"
const COMMS_ARRAY_SCENE_PATH := "res://scenes/gameplay/gameplay_comms_array.tscn"
const NAV_NEXUS_SCENE_PATH := "res://scenes/gameplay/gameplay_nav_nexus.tscn"

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

func test_patrol_drone_brain_has_expected_goals_and_tasks() -> void:
	_assert_brain_goals(
		PATROL_BRAIN_PATH,
		StringName("patrol"),
		[
			StringName("patrol"),
			StringName("investigate"),
		]
	)

func test_sentry_brain_has_expected_goals_and_tasks() -> void:
	_assert_brain_goals(
		SENTRY_BRAIN_PATH,
		StringName("guard"),
		[
			StringName("guard"),
			StringName("investigate_disturbance"),
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
