extends GutTest

## C7: Objectives Manager Namespace Support
##
## Tests for namespace-aware objective set storage. Multiple objective sets
## can be active simultaneously without replacing each other.

const M_OBJECTIVES_MANAGER := preload("res://scripts/core/managers/m_objectives_manager.gd")
const I_STATE_STORE := preload("res://scripts/core/interfaces/i_state_store.gd")
const I_CONDITION := preload("res://scripts/core/interfaces/i_condition.gd")
const OBJECTIVE_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_objective_definition.gd")
const OBJECTIVE_SET := preload("res://scripts/core/resources/scene_director/rs_objective_set.gd")
const OBJECTIVES_REDUCER := preload("res://scripts/state/reducers/u_objectives_reducer.gd")
const OBJECTIVES_ACTIONS := preload("res://scripts/state/actions/u_objectives_actions.gd")
const OBJECTIVES_SELECTORS := preload("res://scripts/state/selectors/u_objectives_selectors.gd")
const GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")

class ObjectivesStoreStub extends I_StateStore:
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

class ConditionAlwaysPassStub extends I_Condition:
	func evaluate(_context: Dictionary) -> float:
		return 1.0

class ConditionNeverPassStub extends I_Condition:
	func evaluate(_context: Dictionary) -> float:
		return 0.0

var _store: ObjectivesStoreStub

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()
	_store = ObjectivesStoreStub.new()
	autofree(_store)

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()

## --- Commit 1 Tests: Namespace-aware loading (TDD RED) ---

func test_loading_second_set_does_not_replace_first() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var set_b: Resource = _objective_set(StringName("set_b"), [
		_objective(StringName("obj_b1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a, set_b], true)

	assert_eq(manager.get_objective_status(StringName("obj_a1")), "active",
		"First set's objective should remain active after loading second set")
	assert_eq(manager.get_objective_status(StringName("obj_b1")), "active",
		"Second set's objective should be active")

func test_active_set_ids_tracks_all_loaded_sets() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var set_b: Resource = _objective_set(StringName("set_b"), [
		_objective(StringName("obj_b1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a, set_b], true)

	var state: Dictionary = _store.get_state()
	var active_set_ids: Array = OBJECTIVES_SELECTORS.get_active_set_ids(state)
	assert_true(active_set_ids.has(StringName("set_a")),
		"set_a should be in active_set_ids")
	assert_true(active_set_ids.has(StringName("set_b")),
		"set_b should be in active_set_ids")

func test_evaluate_across_multiple_sets() -> void:
	var condition_a := ConditionAlwaysPassStub.new()
	var condition_b := ConditionAlwaysPassStub.new()
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true, [condition_a]),
	])
	var set_b: Resource = _objective_set(StringName("set_b"), [
		_objective(StringName("obj_b1"), [], true, [condition_b]),
	])
	var manager: Variant = await _spawn_manager([set_a, set_b], true)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATED, {})

	assert_eq(manager.get_objective_status(StringName("obj_a1")), "completed",
		"Objective in set_a should complete on evaluation")
	assert_eq(manager.get_objective_status(StringName("obj_b1")), "completed",
		"Objective in set_b should complete on evaluation")

func test_complete_objective_in_one_set_does_not_affect_other() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var set_b: Resource = _objective_set(StringName("set_b"), [
		_objective(StringName("obj_b1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a, set_b], true)

	manager._complete_objective(StringName("obj_a1"))

	assert_eq(manager.get_objective_status(StringName("obj_a1")), "completed",
		"Objective in set_a should be completed")
	assert_eq(manager.get_objective_status(StringName("obj_b1")), "active",
		"Objective in set_b should remain active")

func test_single_set_load_is_backwards_compatible() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a], true)

	assert_eq(manager.get_objective_status(StringName("obj_a1")), "active",
		"Single-set loading should still work as before")

	var state: Dictionary = _store.get_state()
	var active_set_ids: Array = OBJECTIVES_SELECTORS.get_active_set_ids(state)
	assert_eq(active_set_ids.size(), 1,
		"Single-set mode should have exactly one active set")
	assert_eq(active_set_ids[0], StringName("set_a"),
		"Single-set mode active_set_ids should contain the loaded set")

func test_unload_set_removes_from_namespace() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var set_b: Resource = _objective_set(StringName("set_b"), [
		_objective(StringName("obj_b1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a, set_b], true)

	var unloaded: bool = manager.unload_objective_set(StringName("set_b"))
	assert_true(unloaded, "Unloading an active set should succeed")

	assert_eq(manager.get_objective_status(StringName("obj_a1")), "active",
		"Remaining set's objectives should still be active")
	assert_eq(manager.get_objective_status(StringName("obj_b1")), "inactive",
		"Unloaded set's objectives should be inactive")

	var state: Dictionary = _store.get_state()
	var active_set_ids: Array = OBJECTIVES_SELECTORS.get_active_set_ids(state)
	assert_false(active_set_ids.has(StringName("set_b")),
		"Unloaded set should not be in active_set_ids")

func test_reload_same_set_replaces_only_that_set() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var set_b: Resource = _objective_set(StringName("set_b"), [
		_objective(StringName("obj_b1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a, set_b], true)

	# Complete obj_a1, then reload set_a via reset_for_new_run (fresh start)
	manager._complete_objective(StringName("obj_a1"))
	assert_eq(manager.get_objective_status(StringName("obj_a1")), "completed")

	var reloaded: bool = manager.reset_for_new_run(StringName("set_a"))
	assert_true(reloaded, "Resetting set_a should succeed")

	# After reset, obj_a1 should be auto-activated again
	assert_eq(manager.get_objective_status(StringName("obj_a1")), "active",
		"Reset set's auto-activate objectives should be re-activated")
	# reset_for_new_run clears all statuses and sets active_set_ids to [set_a]
	# so set_b objectives will be inactive (not in active_set_ids)
	assert_eq(manager.get_objective_status(StringName("obj_b1")), "inactive",
		"Other set's objectives should be inactive after reset_for_new_run")

func test_fail_objective_in_namespace() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var set_b: Resource = _objective_set(StringName("set_b"), [
		_objective(StringName("obj_b1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a, set_b], true)

	manager._fail_objective(StringName("obj_a1"))

	assert_eq(manager.get_objective_status(StringName("obj_a1")), "failed",
		"Objective in set_a should be failed")
	assert_eq(manager.get_objective_status(StringName("obj_b1")), "active",
		"Objective in set_b should remain active")

func test_unload_nonexistent_set_returns_false() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a], true)

	var unloaded: bool = manager.unload_objective_set(StringName("set_nonexistent"))
	assert_false(unloaded, "Unloading a non-existent set should return false")

func test_active_set_id_is_primary_set() -> void:
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true),
	])
	var manager: Variant = await _spawn_manager([set_a], true)

	var state: Dictionary = _store.get_state()
	assert_eq(
		OBJECTIVES_SELECTORS.get_active_set_id(state),
		StringName("set_a"),
		"active_set_id should reflect the primary loaded set"
	)

func test_within_set_dependency_across_namespace() -> void:
	# Each set has its own dependency chain; they don't cross-reference
	var set_a: Resource = _objective_set(StringName("set_a"), [
		_objective(StringName("obj_a1"), [], true, [ConditionAlwaysPassStub.new()]),
		_objective(StringName("obj_a2"), [StringName("obj_a1")], false, [ConditionNeverPassStub.new()]),
	])
	var set_b: Resource = _objective_set(StringName("set_b"), [
		_objective(StringName("obj_b1"), [], true, [ConditionNeverPassStub.new()]),
	])
	var manager: Variant = await _spawn_manager([set_a, set_b], true)

	# obj_a2 depends on obj_a1 (within set_a)
	assert_eq(manager.get_objective_status(StringName("obj_a2")), "inactive")

	# Trigger evaluation — obj_a1 completes, obj_a2 should activate
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATED, {})

	assert_eq(manager.get_objective_status(StringName("obj_a1")), "completed")
	assert_eq(manager.get_objective_status(StringName("obj_a2")), "active",
		"Within-set dependency activation should work in namespace mode")
	assert_eq(manager.get_objective_status(StringName("obj_b1")), "active",
		"Other set's objectives should remain unaffected")

## --- Helper methods ---

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
	if conditions.size() > 0:
		var typed_conditions: Array[I_Condition] = []
		for condition in conditions:
			if condition is I_Condition:
				typed_conditions.append(condition as I_Condition)
		objective.conditions = typed_conditions
	if effects.size() > 0:
		var typed_effects: Array[I_Effect] = []
		for effect in effects:
			if effect is I_Effect:
				typed_effects.append(effect as I_Effect)
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