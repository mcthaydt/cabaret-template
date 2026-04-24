extends GutTest

const M_RUN_COORDINATOR := preload("res://scripts/managers/m_run_coordinator_manager.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")
const I_OBJECTIVES_MANAGER := preload("res://scripts/interfaces/i_objectives_manager.gd")
const U_RUN_ACTIONS := preload("res://scripts/state/actions/u_run_actions.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_INTERACT_BLOCKER := preload("res://scripts/utils/u_interact_blocker.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

class RunStoreStub extends I_STATE_STORE:
	signal action_dispatched(action: Dictionary)
	signal store_ready()

	var _state: Dictionary = {}
	var _dispatched_actions: Array[Dictionary] = []

	func dispatch(action: Dictionary) -> void:
		var action_copy: Dictionary = action.duplicate(true)
		_dispatched_actions.append(action_copy)
		action_dispatched.emit(action_copy)

	func subscribe(_callback: Callable) -> Callable:
		return Callable()

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

class ObjectivesManagerStub extends I_OBJECTIVES_MANAGER:
	var reset_calls: int = 0
	var last_set_id: StringName = StringName("")
	var _known_sets: Dictionary = {StringName("default_progression"): true}

	func reset_for_new_run(set_id: StringName = StringName("default_progression")) -> bool:
		reset_calls += 1
		last_set_id = set_id
		return true

	func has_objective_set(set_id: StringName) -> bool:
		return _known_sets.has(set_id)

var _store: RunStoreStub

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_INTERACT_BLOCKER.cleanup()
	_store = RunStoreStub.new()
	autofree(_store)

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_INTERACT_BLOCKER.cleanup()

func test_run_reset_dispatches_gameplay_reset_then_retry_and_resets_objectives() -> void:
	var objectives_manager := ObjectivesManagerStub.new()
	autofree(objectives_manager)
	U_SERVICE_LOCATOR.register(StringName("objectives_manager"), objectives_manager)

	var coordinator := M_RUN_COORDINATOR.new()
	coordinator.state_store = _store
	add_child_autofree(coordinator)
	await wait_process_frames(1)

	U_INTERACT_BLOCKER.block()
	assert_true(U_INTERACT_BLOCKER.is_blocked())

	_store.dispatch(U_RUN_ACTIONS.reset_run(StringName("retry")))
	await wait_process_frames(1)

	var actions: Array[Dictionary] = _store.get_dispatched_actions()
	var gameplay_index: int = _find_action_index(actions, U_GAMEPLAY_ACTIONS.ACTION_RESET_PROGRESS)
	var retry_index: int = _find_action_index(actions, U_NAVIGATION_ACTIONS.ACTION_RETRY)

	assert_true(gameplay_index >= 0, "Coordinator should dispatch gameplay/reset_progress")
	assert_true(retry_index >= 0, "Coordinator should dispatch navigation/retry")
	assert_true(gameplay_index < retry_index, "gameplay/reset_progress should dispatch before navigation/retry")
	if retry_index >= 0:
		assert_eq(
			actions[retry_index].get("scene_id", StringName("")),
			coordinator.game_config.retry_scene_id
		)
	assert_eq(objectives_manager.reset_calls, 1)
	assert_eq(objectives_manager.last_set_id, StringName("default_progression"))
	assert_false(U_INTERACT_BLOCKER.is_blocked(), "Coordinator should force-unblock interact blocker")

func test_run_reset_without_objectives_manager_still_resets_and_retries() -> void:
	var coordinator := M_RUN_COORDINATOR.new()
	coordinator.state_store = _store
	add_child_autofree(coordinator)
	await wait_process_frames(1)

	_store.dispatch(U_RUN_ACTIONS.reset_run(StringName("retry")))
	await wait_process_frames(1)

	var actions: Array[Dictionary] = _store.get_dispatched_actions()
	assert_true(_find_action_index(actions, U_GAMEPLAY_ACTIONS.ACTION_RESET_PROGRESS) >= 0)
	assert_true(_find_action_index(actions, U_NAVIGATION_ACTIONS.ACTION_RETRY) >= 0)
	assert_engine_error("objectives_manager not available during run/reset")

func test_reentrant_run_reset_requests_are_ignored_while_in_flight() -> void:
	var coordinator := M_RUN_COORDINATOR.new()
	coordinator.state_store = _store
	add_child_autofree(coordinator)
	await wait_process_frames(1)

	_store.dispatch(U_RUN_ACTIONS.reset_run(StringName("retry")))
	_store.dispatch(U_RUN_ACTIONS.reset_run(StringName("retry")))
	await wait_process_frames(1)

	var actions: Array[Dictionary] = _store.get_dispatched_actions()
	assert_eq(_count_actions(actions, U_GAMEPLAY_ACTIONS.ACTION_RESET_PROGRESS), 1)
	assert_eq(_count_actions(actions, U_NAVIGATION_ACTIONS.ACTION_RETRY), 1)
	assert_engine_error("objectives_manager not available during run/reset")

func _find_action_index(actions: Array[Dictionary], action_type: StringName) -> int:
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		if action.get("type", StringName("")) == action_type:
			return i
	return -1

func _count_actions(actions: Array[Dictionary], action_type: StringName) -> int:
	var count: int = 0
	for action in actions:
		if action.get("type", StringName("")) == action_type:
			count += 1
	return count
