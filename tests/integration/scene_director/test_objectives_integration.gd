extends GutTest

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_OBJECTIVES_MANAGER := preload("res://scripts/managers/m_objectives_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const OBJECTIVE_DEFINITION := preload("res://scripts/resources/scene_director/rs_objective_definition.gd")
const OBJECTIVE_SET := preload("res://scripts/resources/scene_director/rs_objective_set.gd")
const CONDITION_REDUX_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_redux_field.gd")
const CONDITION_EVENT_PAYLOAD := preload("res://scripts/resources/qb/conditions/rs_condition_event_payload.gd")
const EFFECT_DISPATCH_ACTION := preload("res://scripts/resources/qb/effects/rs_effect_dispatch_action.gd")
const CFG_OBJSET_DEFAULT := preload("res://resources/scene_director/sets/cfg_objset_default.tres")
const U_SCENE_TEST_HELPERS := preload("res://tests/helpers/u_scene_test_helpers.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

var _root: Node
var _state_store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _objectives_manager: M_OBJECTIVES_MANAGER

func before_each() -> void:
	U_STATE_HANDOFF.clear_all()
	U_ServiceLocator.clear()
	U_ECS_EVENT_BUS.reset()

	var root_ctx: Dictionary = U_SCENE_TEST_HELPERS.create_root_with_containers(true)
	_root = root_ctx.get("root")
	add_child_autofree(_root)

	_state_store = M_STATE_STORE.new()
	_state_store.settings = RS_STATE_STORE_SETTINGS.new()
	_state_store.settings.enable_persistence = false
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_root.add_child(_state_store)
	U_ServiceLocator.register(StringName("state_store"), _state_store)
	U_SCENE_TEST_HELPERS.register_scene_manager_dependencies(_root)

	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root.add_child(_scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager)

	_objectives_manager = M_OBJECTIVES_MANAGER.new()
	_objectives_manager.state_store = _state_store
	_objectives_manager.objective_sets = [_build_test_objective_set()]
	_root.add_child(_objectives_manager)
	U_ServiceLocator.register(StringName("objectives_manager"), _objectives_manager)

	await get_tree().process_frame
	await wait_physics_frames(1)

func after_each() -> void:
	if _scene_manager != null and is_instance_valid(_scene_manager):
		await U_SCENE_TEST_HELPERS.wait_for_transition_idle(_scene_manager)
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame

	U_ServiceLocator.clear()
	U_ECS_EVENT_BUS.reset()
	U_STATE_HANDOFF.clear_all()

	_root = null
	_state_store = null
	_scene_manager = null
	_objectives_manager = null

func test_victory_executed_transitions_scene_via_objectives_manager() -> void:
	var captured_actions: Array[Dictionary] = []
	_state_store.action_dispatched.connect(func(action: Dictionary) -> void:
		if action.get("type", StringName("")) == U_GAMEPLAY_ACTIONS.ACTION_TRIGGER_VICTORY_ROUTING:
			captured_actions.append(action.duplicate(true))
	)

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.mark_area_complete("alleyway"))
	await wait_physics_frames(1)
	assert_eq(_objectives_manager.get_objective_status(StringName("bar_complete")), "completed")
	assert_eq(_objectives_manager.get_objective_status(StringName("final_complete")), "active")

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.trigger_victory(StringName("final_goal")))

	await U_SCENE_TEST_HELPERS.wait_for_transition_idle(_scene_manager)

	assert_eq(captured_actions.size(), 1, "Expected a single trigger_victory_routing action")
	if captured_actions.size() > 0:
		assert_eq(captured_actions[0].get("target_scene", StringName("")), StringName("victory"))
	assert_eq(_scene_manager.get_current_scene(), StringName("victory"))
	assert_eq(_objectives_manager.get_objective_status(StringName("final_complete")), "completed")

func test_default_objective_set_requires_final_trigger_before_victory_transition() -> void:
	assert_not_null(CFG_OBJSET_DEFAULT)

	if _objectives_manager != null and is_instance_valid(_objectives_manager):
		_objectives_manager.queue_free()
		await get_tree().process_frame

	_objectives_manager = M_OBJECTIVES_MANAGER.new()
	_objectives_manager.state_store = _state_store
	var default_set: Resource = (CFG_OBJSET_DEFAULT as Resource).duplicate(true)
	_objectives_manager.objective_sets = [default_set]
	_root.add_child(_objectives_manager)
	U_ServiceLocator.register_or_replace(StringName("objectives_manager"), _objectives_manager)

	await get_tree().process_frame
	await wait_physics_frames(1)

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.trigger_victory(StringName("goal_bar")))
	await U_SCENE_TEST_HELPERS.wait_for_transition_idle(_scene_manager)

	assert_eq(_objectives_manager.get_objective_status(StringName("bar_complete")), "completed")
	assert_eq(
		_objectives_manager.get_objective_status(StringName("final_complete")),
		"active",
		"Default objective set should keep final objective active after bar trigger"
	)
	assert_eq(
		_scene_manager.get_current_scene(),
		StringName("alleyway"),
		"Default objective set should route back to alleyway after bar objective completion"
	)

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.trigger_victory(StringName("goal_bar")))
	await wait_physics_frames(1)

	assert_eq(
		_objectives_manager.get_objective_status(StringName("final_complete")),
		"active",
		"Victory event without final trigger payload should not complete final objective"
	)
	assert_eq(_scene_manager.get_current_scene(), StringName("alleyway"))

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.trigger_victory(StringName("final_goal")))
	await U_SCENE_TEST_HELPERS.wait_for_transition_idle(_scene_manager)

	assert_eq(_objectives_manager.get_objective_status(StringName("final_complete")), "completed")
	assert_eq(_scene_manager.get_current_scene(), StringName("victory"))
	var gameplay_state: Dictionary = _state_store.get_slice(StringName("gameplay"))
	assert_true(bool(gameplay_state.get("game_completed", false)))

func _build_test_objective_set() -> Resource:
	var level_condition := CONDITION_REDUX_FIELD.new()
	level_condition.state_path = "gameplay.completed_areas.0"
	level_condition.match_mode = "not_equals"
	level_condition.match_value_string = ""

	var game_condition := CONDITION_EVENT_PAYLOAD.new()
	game_condition.field_path = "trigger_node.objective_id"
	game_condition.match_mode = "equals"
	game_condition.match_value_string = "final_goal"

	var game_effect := EFFECT_DISPATCH_ACTION.new()
	game_effect.action_type = U_GAMEPLAY_ACTIONS.ACTION_GAME_COMPLETE

	var bar_objective: Resource = OBJECTIVE_DEFINITION.new()
	bar_objective.objective_id = StringName("bar_complete")
	bar_objective.auto_activate = true
	var bar_conditions: Array[I_Condition] = [level_condition]
	bar_objective.conditions = bar_conditions

	var final_objective: Resource = OBJECTIVE_DEFINITION.new()
	final_objective.objective_id = StringName("final_complete")
	final_objective.objective_type = OBJECTIVE_DEFINITION.ObjectiveType.VICTORY
	var dependencies: Array[StringName] = [StringName("bar_complete")]
	final_objective.dependencies = dependencies
	var final_conditions: Array[I_Condition] = [game_condition]
	final_objective.conditions = final_conditions
	var final_effects: Array[I_Effect] = [game_effect]
	final_objective.completion_effects = final_effects
	final_objective.completion_event_payload = {
		"target_scene": StringName("victory"),
	}

	var objective_set: Resource = OBJECTIVE_SET.new()
	objective_set.set_id = StringName("set_integration")
	var objectives: Array[RS_ObjectiveDefinition] = [bar_objective, final_objective]
	objective_set.objectives = objectives
	return objective_set
