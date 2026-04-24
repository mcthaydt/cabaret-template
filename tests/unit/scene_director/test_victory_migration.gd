extends GutTest

const M_SCENE_MANAGER := preload("res://scripts/core/managers/m_scene_manager.gd")
const M_OBJECTIVES_MANAGER := preload("res://scripts/core/managers/m_objectives_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const I_STATE_STORE := preload("res://scripts/core/interfaces/i_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const OBJECTIVE_DEFINITION := preload("res://scripts/resources/scene_director/rs_objective_definition.gd")
const OBJECTIVE_SET := preload("res://scripts/resources/scene_director/rs_objective_set.gd")
const OBJECTIVES_REDUCER := preload("res://scripts/state/reducers/u_objectives_reducer.gd")
const OBJECTIVES_ACTIONS := preload("res://scripts/state/actions/u_objectives_actions.gd")
const U_SCENE_TEST_HELPERS := preload("res://tests/helpers/u_scene_test_helpers.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")

class ObjectivesStoreStub extends I_STATE_STORE:
	signal action_dispatched(action: Dictionary)
	signal store_ready()

	var _state: Dictionary = {
		"objectives": {
			"statuses": {},
			"active_set_id": StringName(""),
			"active_set_ids": [],
			"event_log": [],
		},
		"gameplay": {
			"completed_areas": [],
		},
	}

	func dispatch(action: Dictionary) -> void:
		var action_copy: Dictionary = action.duplicate(true)
		var objectives_slice: Dictionary = _state.get("objectives", {}).duplicate(true)
		_state["objectives"] = OBJECTIVES_REDUCER.reduce(objectives_slice, action_copy)
		action_dispatched.emit(action_copy)

	func subscribe(_callback: Callable) -> Callable:
		return func() -> void:
			pass

	func get_state() -> Dictionary:
		return _state.duplicate(true)

	func get_slice(slice_name: StringName) -> Dictionary:
		return _state.get(slice_name, {}).duplicate(true)

	func is_ready() -> bool:
		return true

	func apply_loaded_state(loaded_state: Dictionary) -> void:
		_state = loaded_state.duplicate(true)

class ConditionStub extends I_Condition:
	var response_value: float = 1.0

	func _init(initial_response: float = 1.0) -> void:
		response_value = initial_response

	func evaluate(_context: Dictionary) -> float:
		return response_value

func before_each() -> void:
	U_ServiceLocator.clear()
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_ServiceLocator.clear()
	U_ECS_EVENT_BUS.reset()

func test_final_complete_dependency_is_enforced_before_victory_completion() -> void:
	var store := ObjectivesStoreStub.new()
	autofree(store)
	var level_condition := ConditionStub.new(0.0)
	var game_condition := ConditionStub.new(1.0)
	var objective_set: Resource = _objective_set(
		StringName("set_default"),
		[
			_objective(
				StringName("bar_complete"),
				[],
				true,
				[level_condition],
				[],
				OBJECTIVE_DEFINITION.ObjectiveType.STANDARD
			),
			_objective(
				StringName("final_complete"),
				[StringName("bar_complete")],
				false,
				[game_condition],
				[],
				OBJECTIVE_DEFINITION.ObjectiveType.VICTORY,
				{"target_scene": StringName("victory")}
			),
		]
	)

	var captured_actions: Array[Dictionary] = []
	store.action_dispatched.connect(func(action: Dictionary) -> void:
		if action.get("type", StringName("")) == U_GAMEPLAY_ACTIONS.ACTION_TRIGGER_VICTORY_ROUTING:
			captured_actions.append(action.duplicate(true))
	)

	var manager := M_OBJECTIVES_MANAGER.new()
	manager.state_store = store
	manager.objective_sets = [objective_set]
	add_child_autofree(manager)
	await get_tree().process_frame

	store.dispatch(U_GAMEPLAY_ACTIONS.trigger_victory(StringName("goal_bar")))
	assert_eq(manager.get_objective_status(StringName("bar_complete")), "active")
	assert_eq(manager.get_objective_status(StringName("final_complete")), "inactive")
	assert_eq(captured_actions.size(), 0, "Victory objective should not complete before dependency")

	level_condition.response_value = 1.0
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATED, {})

	assert_eq(manager.get_objective_status(StringName("bar_complete")), "completed")
	assert_eq(manager.get_objective_status(StringName("final_complete")), "completed")
	assert_eq(captured_actions.size(), 1, "Victory objective should complete once dependency is completed")

func test_scene_manager_no_longer_listens_to_victory_executed() -> void:
	var fixture: Dictionary = await _spawn_scene_manager_fixture()
	var scene_manager: M_SCENE_MANAGER = fixture.get("scene_manager")
	var state_store: M_STATE_STORE = fixture.get("state_store")
	assert_not_null(scene_manager)

	state_store.dispatch(U_GAMEPLAY_ACTIONS.trigger_victory_routing(StringName("alleyway")))
	await U_SCENE_TEST_HELPERS.wait_for_transition_idle(scene_manager)
	assert_eq(
		scene_manager.get_current_scene(),
		StringName("alleyway"),
		"Scene manager should transition on trigger_victory_routing action"
	)

func _spawn_scene_manager_fixture() -> Dictionary:
	var root_ctx: Dictionary = U_SCENE_TEST_HELPERS.create_root_with_containers(true)
	var root: Node = root_ctx.get("root")
	add_child_autofree(root)

	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	var nav_initial := RS_NAVIGATION_INITIAL_STATE.new()
	nav_initial.shell = StringName("gameplay")
	nav_initial.base_scene_id = StringName("")
	store.navigation_initial_state = nav_initial
	root.add_child(store)
	U_ServiceLocator.register(StringName("state_store"), store)
	U_SCENE_TEST_HELPERS.register_scene_manager_dependencies(root)

	var scene_manager := M_SCENE_MANAGER.new()
	scene_manager.skip_initial_scene_load = true
	root.add_child(scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), scene_manager)

	await get_tree().process_frame
	await wait_physics_frames(1)

	return {
		"root": root,
		"state_store": store,
		"scene_manager": scene_manager,
	}

func _objective(
	objective_id: StringName,
	dependencies: Array[StringName],
	auto_activate: bool,
	conditions: Array[Resource] = [],
	effects: Array[Resource] = [],
	objective_type: int = OBJECTIVE_DEFINITION.ObjectiveType.STANDARD,
	completion_event_payload: Dictionary = {}
) -> Resource:
	var objective: Resource = OBJECTIVE_DEFINITION.new()
	objective.objective_id = objective_id
	objective.dependencies = dependencies.duplicate(true)
	objective.auto_activate = auto_activate
	var typed_conditions: Array[I_Condition] = []
	for c in conditions:
		if c is I_Condition:
			typed_conditions.append(c as I_Condition)
	objective.conditions = typed_conditions
	var typed_effects: Array[I_Effect] = []
	for e in effects:
		if e is I_Effect:
			typed_effects.append(e as I_Effect)
	objective.completion_effects = typed_effects
	objective.objective_type = objective_type
	objective.completion_event_payload = completion_event_payload.duplicate(true)
	return objective

func _objective_set(set_id: StringName, objectives: Array[Resource]) -> Resource:
	var objective_set: Resource = OBJECTIVE_SET.new()
	objective_set.set_id = set_id
	var typed_objectives: Array[RS_ObjectiveDefinition] = []
	for o in objectives:
		if o is RS_ObjectiveDefinition:
			typed_objectives.append(o as RS_ObjectiveDefinition)
	objective_set.objectives = typed_objectives
	return objective_set
