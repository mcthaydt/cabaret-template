extends GutTest

const M_OBJECTIVES_MANAGER := preload("res://scripts/managers/m_objectives_manager.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")
const OBJECTIVE_DEFINITION := preload("res://scripts/resources/scene_director/rs_objective_definition.gd")
const OBJECTIVE_SET := preload("res://scripts/resources/scene_director/rs_objective_set.gd")
const OBJECTIVES_REDUCER := preload("res://scripts/state/reducers/u_objectives_reducer.gd")
const OBJECTIVES_ACTIONS := preload("res://scripts/state/actions/u_objectives_actions.gd")
const GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const OBJECTIVE_EVENT_LOG := preload("res://scripts/utils/scene_director/u_objective_event_log.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")
const ACTION_SET_TEST_FLAG := StringName("tests/objectives/set_test_flag")

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
			"test_flag": false,
		},
	}
	var _subscribers: Array[Callable] = []
	var _dispatched_actions: Array[Dictionary] = []

	func dispatch(action: Dictionary) -> void:
		var action_copy: Dictionary = action.duplicate(true)
		_dispatched_actions.append(action_copy)

		var objectives_slice: Dictionary = _state.get("objectives", {}).duplicate(true)
		_state["objectives"] = OBJECTIVES_REDUCER.reduce(objectives_slice, action_copy)

		var action_type: StringName = action_copy.get("type", StringName(""))
		if action_type == GAMEPLAY_ACTIONS.ACTION_MARK_AREA_COMPLETE:
			var gameplay_slice: Dictionary = _state.get("gameplay", {}).duplicate(true)
			var completed_areas: Array = gameplay_slice.get("completed_areas", []).duplicate(true)
			var area_id: String = str(action_copy.get("payload", ""))
			if not area_id.is_empty() and not completed_areas.has(area_id):
				completed_areas.append(area_id)
			gameplay_slice["completed_areas"] = completed_areas
			_state["gameplay"] = gameplay_slice
		elif action_type == ACTION_SET_TEST_FLAG:
			var gameplay_with_flag: Dictionary = _state.get("gameplay", {}).duplicate(true)
			gameplay_with_flag["test_flag"] = bool(action_copy.get("payload", false))
			_state["gameplay"] = gameplay_with_flag

		action_dispatched.emit(action_copy)
		var snapshot: Dictionary = _state.duplicate(true)
		for callback in _subscribers:
			if callback.is_valid():
				callback.call(action_copy, snapshot)

	func subscribe(callback: Callable) -> Callable:
		_subscribers.append(callback)
		return func() -> void:
			_subscribers.erase(callback)

	func get_state() -> Dictionary:
		return _state.duplicate(true)

	func get_slice(slice_name: StringName) -> Dictionary:
		return _state.get(slice_name, {}).duplicate(true)

	func is_ready() -> bool:
		return true

	func apply_loaded_state(loaded_state: Dictionary) -> void:
		_state = loaded_state.duplicate(true)

	func get_dispatched_actions() -> Array[Dictionary]:
		return _dispatched_actions.duplicate(true)

class ConditionStub extends I_Condition:
	var response_value: float = 1.0
	var evaluate_calls: int = 0
	var last_context: Dictionary = {}

	func _init(initial_value: float = 1.0) -> void:
		response_value = initial_value

	func evaluate(context: Dictionary) -> float:
		evaluate_calls += 1
		last_context = context.duplicate(true)
		return response_value

class EffectStub extends I_Effect:
	var execute_calls: int = 0
	var last_context: Dictionary = {}

	func execute(context: Dictionary) -> void:
		execute_calls += 1
		last_context = context.duplicate(true)

class ConditionGameplayFlagStub extends I_Condition:
	var evaluate_calls: int = 0
	var last_context: Dictionary = {}

	func evaluate(context: Dictionary) -> float:
		evaluate_calls += 1
		last_context = context.duplicate(true)
		var state: Dictionary = context.get("redux_state", {})
		var gameplay: Dictionary = state.get("gameplay", {})
		return 1.0 if bool(gameplay.get("test_flag", false)) else 0.0

class ConditionCompletedAreaStub extends I_Condition:
	var required_area: String = ""
	var evaluate_calls: int = 0

	func _init(initial_area: String = "") -> void:
		required_area = initial_area

	func evaluate(context: Dictionary) -> float:
		evaluate_calls += 1
		var state: Dictionary = context.get("redux_state", {})
		var gameplay: Dictionary = state.get("gameplay", {})
		var completed_variant: Variant = gameplay.get("completed_areas", [])
		if completed_variant is Array:
			var completed: Array = completed_variant
			return 1.0 if completed.has(required_area) else 0.0
		return 0.0

class EffectSetGameplayFlagStub extends I_Effect:
	var execute_calls: int = 0
	var value: bool = true

	func _init(initial_value: bool = true) -> void:
		value = initial_value

	func execute(context: Dictionary) -> void:
		execute_calls += 1
		var store: Variant = context.get("state_store", null)
		if store == null:
			return
		if not store.has_method("dispatch"):
			return
		store.dispatch({
			"type": ACTION_SET_TEST_FLAG,
			"payload": value,
		})

var _store: ObjectivesStoreStub

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()
	_store = ObjectivesStoreStub.new()
	autofree(_store)

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()

func test_load_set_auto_activates_objectives_on_ready() -> void:
	var objective_set: Resource = _objective_set(
		StringName("set_default"),
		[
			_objective(StringName("obj_auto"), [], true),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)

	assert_eq(manager.get_objective_status(StringName("obj_auto")), "active")
	assert_eq(_store.get_state().get("objectives", {}).get("active_set_id"), StringName("set_default"))
	assert_true(_has_action(OBJECTIVES_ACTIONS.ACTION_ACTIVATE))

func test_evaluates_conditions_executes_effects_and_activates_dependents() -> void:
	var completion_condition := ConditionStub.new(1.0)
	var completion_effect := EffectStub.new()
	var dependent_condition := ConditionStub.new(0.0)

	var objective_set: Resource = _objective_set(
		StringName("set_core"),
		[
			_objective(
				StringName("obj_parent"),
				[],
				true,
				[completion_condition],
				[completion_effect]
			),
			_objective(
				StringName("obj_dependent"),
				[StringName("obj_parent")],
				false,
				[dependent_condition]
			),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATED, {"checkpoint_id": "cp_01"})

	assert_true(completion_condition.evaluate_calls > 0, "Completion condition should be evaluated")
	assert_eq(completion_effect.execute_calls, 1, "Completion effect should execute once")
	assert_eq(manager.get_objective_status(StringName("obj_parent")), "completed")
	assert_eq(manager.get_objective_status(StringName("obj_dependent")), "active")
	assert_true(_has_action(OBJECTIVES_ACTIONS.ACTION_COMPLETE))
	assert_true(_has_action(OBJECTIVES_ACTIONS.ACTION_ACTIVATE))

func test_fail_objective_dispatches_fail_action() -> void:
	var objective_set: Resource = _objective_set(
		StringName("set_fail"),
		[
			_objective(StringName("obj_fail"), [], true),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)
	manager._fail_objective(StringName("obj_fail"))

	assert_eq(manager.get_objective_status(StringName("obj_fail")), "failed")
	assert_true(_has_action(OBJECTIVES_ACTIONS.ACTION_FAIL))

func test_event_log_records_activation_and_completion_transitions() -> void:
	var objective_set: Resource = _objective_set(
		StringName("set_log"),
		[
			_objective(
				StringName("obj_logged"),
				[],
				true,
				[ConditionStub.new(1.0)]
			),
		]
	)
	await _spawn_manager([objective_set], true)
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATED, {})

	var log: Array = _store.get_state().get("objectives", {}).get("event_log", [])
	assert_true(log.size() >= 2, "Expected activation and completion events in log")
	assert_true(_log_contains_event(log, OBJECTIVE_EVENT_LOG.EVENT_ACTIVATED))
	assert_true(_log_contains_event(log, OBJECTIVE_EVENT_LOG.EVENT_COMPLETED))

func test_graph_validation_rejects_cycles() -> void:
	var cycle_set: Resource = _objective_set(
		StringName("set_cycle"),
		[
			_objective(StringName("obj_a"), [StringName("obj_c")], false),
			_objective(StringName("obj_b"), [StringName("obj_a")], false),
			_objective(StringName("obj_c"), [StringName("obj_b")], false),
		]
	)
	var manager: Variant = await _spawn_manager([cycle_set], true)
	var loaded: bool = manager.load_objective_set(StringName("set_cycle"))

	assert_false(loaded, "Cyclic objective set should be rejected")
	assert_eq(_store.get_state().get("objectives", {}).get("active_set_id"), StringName(""))

func test_victory_completion_publishes_configured_payload() -> void:
	var captured_actions: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		if action.get("type", StringName("")) == GAMEPLAY_ACTIONS.ACTION_TRIGGER_VICTORY_ROUTING:
			captured_actions.append(action.duplicate(true))
	)

	var objective_set: Resource = _objective_set(
		StringName("set_victory"),
		[
			_objective(
				StringName("obj_victory"),
				[],
				true,
				[ConditionStub.new(1.0)],
				[],
				OBJECTIVE_DEFINITION.ObjectiveType.VICTORY,
				{"target_scene": StringName("victory")}
			),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)
	_store.dispatch(GAMEPLAY_ACTIONS.trigger_victory(StringName("final_goal")))

	assert_eq(manager.get_objective_status(StringName("obj_victory")), "completed")
	assert_eq(captured_actions.size(), 1, "Expected one trigger_victory_routing action")
	if captured_actions.size() > 0:
		assert_eq(captured_actions[0].get("target_scene", StringName("")), StringName("victory"))

func test_discovers_store_from_service_locator_when_not_injected() -> void:
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)
	var objective_set: Resource = _objective_set(
		StringName("set_locator"),
		[
			_objective(StringName("obj_from_locator"), [], true),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], false)

	assert_eq(manager.get_objective_status(StringName("obj_from_locator")), "active")

func test_dependency_evaluation_refreshes_redux_state_within_same_event() -> void:
	var parent_condition := ConditionStub.new(1.0)
	var parent_effect := EffectSetGameplayFlagStub.new(true)
	var child_condition := ConditionGameplayFlagStub.new()
	var objective_set: Resource = _objective_set(
		StringName("set_refresh"),
		[
			_objective(
				StringName("obj_parent"),
				[],
				true,
				[parent_condition],
				[parent_effect]
			),
			_objective(
				StringName("obj_child"),
				[StringName("obj_parent")],
				false,
				[child_condition]
			),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATED, {})

	assert_eq(manager.get_objective_status(StringName("obj_parent")), "completed")
	assert_eq(
		manager.get_objective_status(StringName("obj_child")),
		"completed",
		"Dependent objective should complete in the same evaluation event after parent effects mutate state"
	)
	assert_eq(parent_effect.execute_calls, 1)
	assert_true(child_condition.evaluate_calls > 0)

func test_late_store_resolution_connects_action_dispatched_subscription() -> void:
	var late_store := ObjectivesStoreStub.new()
	autofree(late_store)
	var objective_set: Resource = _objective_set(
		StringName("set_late_store"),
		[
			_objective(
				StringName("obj_late"),
				[],
				true,
				[ConditionCompletedAreaStub.new("area_late")]
			),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], false)

	U_SERVICE_LOCATOR.register(StringName("state_store"), late_store)
	var loaded: bool = manager.load_objective_set(StringName("set_late_store"))
	assert_true(loaded)
	assert_eq(manager.get_objective_status(StringName("obj_late")), "active")

	late_store.dispatch(GAMEPLAY_ACTIONS.mark_area_complete("area_late"))

	assert_eq(
		manager.get_objective_status(StringName("obj_late")),
		"completed",
		"Manager should evaluate objectives on gameplay/mark_area_complete after late store discovery"
	)

func test_load_objective_set_reconciles_saved_statuses_and_discards_orphans() -> void:
	_store.apply_loaded_state({
		"objectives": {
			"statuses": {
				StringName("obj_saved_active"): "active",
				StringName("obj_saved_completed"): "completed",
				StringName("obj_orphan"): "failed",
			},
			"active_set_id": StringName("legacy_set"),
			"event_log": [],
		},
		"gameplay": {
			"completed_areas": [],
			"test_flag": false,
		},
	})

	var objective_set: Resource = _objective_set(
		StringName("set_reconcile"),
		[
			_objective(StringName("obj_saved_active"), [], false),
			_objective(StringName("obj_saved_completed"), [], false),
			_objective(StringName("obj_auto"), [], true),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)

	var objectives_slice: Dictionary = _store.get_state().get("objectives", {})
	var statuses: Dictionary = objectives_slice.get("statuses", {})
	assert_eq(manager.get_objective_status(StringName("obj_saved_active")), "active")
	assert_eq(manager.get_objective_status(StringName("obj_saved_completed")), "completed")
	assert_eq(manager.get_objective_status(StringName("obj_auto")), "active")
	assert_false(statuses.has(StringName("obj_orphan")), "Orphaned status should be discarded on set load")

func test_recovers_runtime_when_objective_statuses_are_empty() -> void:
	var objective_set: Resource = _objective_set(
		StringName("set_recover"),
		[
			_objective(
				StringName("obj_recover"),
				[],
				true,
				[ConditionCompletedAreaStub.new("bar")]
			),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)

	_store.apply_loaded_state({
		"objectives": {
			"statuses": {},
			"active_set_id": StringName(""),
			"event_log": [],
		},
		"gameplay": {
			"completed_areas": [],
			"test_flag": false,
		},
	})

	_store.dispatch(GAMEPLAY_ACTIONS.mark_area_complete("bar"))

	assert_eq(
		manager.get_objective_status(StringName("obj_recover")),
		"completed",
		"Manager should recover empty objectives slice and continue evaluating event-driven completion"
	)

func test_reset_for_new_run_rearms_root_objective_and_clears_event_log() -> void:
	var objective_set: Resource = _objective_set(
		StringName("default_progression"),
		[
			_objective(
				StringName("bar_complete"),
				[],
				true,
				[ConditionStub.new(0.0)]
			),
			_objective(
				StringName("final_complete"),
				[StringName("bar_complete")],
				false,
				[ConditionStub.new(0.0)]
			),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)

	manager._complete_objective(StringName("bar_complete"))
	assert_eq(manager.get_objective_status(StringName("bar_complete")), "completed")
	assert_eq(manager.get_objective_status(StringName("final_complete")), "active")
	assert_true(_store.get_state().get("objectives", {}).get("event_log", []).size() > 0)

	manager.reset_for_new_run(StringName("default_progression"))

	var objectives_slice: Dictionary = _store.get_state().get("objectives", {})
	var statuses: Dictionary = objectives_slice.get("statuses", {})
	assert_eq(statuses.get(StringName("bar_complete"), "inactive"), "active")
	assert_eq(statuses.get(StringName("final_complete"), "inactive"), "inactive")
	assert_eq(objectives_slice.get("event_log", []), [], "reset_for_new_run should clear event log")
	assert_eq(objectives_slice.get("active_set_id"), StringName("default_progression"))

func test_navigation_start_game_resets_objectives_for_new_run() -> void:
	var objective_set: Resource = _objective_set(
		StringName("default_progression"),
		[
			_objective(
				StringName("bar_complete"),
				[],
				true,
				[ConditionStub.new(0.0)]
			),
			_objective(
				StringName("final_complete"),
				[StringName("bar_complete")],
				false,
				[ConditionStub.new(0.0)]
			),
		]
	)
	var manager: Variant = await _spawn_manager([objective_set], true)

	manager._complete_objective(StringName("bar_complete"))
	assert_eq(manager.get_objective_status(StringName("bar_complete")), "completed")
	assert_eq(manager.get_objective_status(StringName("final_complete")), "active")
	assert_true(_store.get_state().get("objectives", {}).get("event_log", []).size() > 0)

	_store.dispatch(NAVIGATION_ACTIONS.start_game(StringName("alleyway")))

	var objectives_slice: Dictionary = _store.get_state().get("objectives", {})
	var statuses: Dictionary = objectives_slice.get("statuses", {})
	assert_eq(statuses.get(StringName("bar_complete"), "inactive"), "active")
	assert_eq(statuses.get(StringName("final_complete"), "inactive"), "inactive")
	assert_eq(objectives_slice.get("event_log", []), [])
	assert_eq(objectives_slice.get("active_set_id"), StringName("default_progression"))

func _spawn_manager(objective_sets: Array[Resource], inject_store: bool) -> Variant:
	var manager := M_OBJECTIVES_MANAGER.new()
	manager.objective_sets = objective_sets.duplicate()
	if inject_store:
		manager.state_store = _store
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager

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

func _has_action(action_type: StringName) -> bool:
	for action in _store.get_dispatched_actions():
		if action.get("type", StringName("")) == action_type:
			return true
	return false

func _log_contains_event(log: Array, event_type: String) -> bool:
	for entry_variant in log:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if str(entry.get("event_type", "")) == event_type:
			return true
	return false
