extends GutTest

const M_SCENE_DIRECTOR := preload("res://scripts/managers/m_scene_director.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_SCENE_DIRECTOR_ACTIONS := preload("res://scripts/state/actions/u_scene_director_actions.gd")
const U_SCENE_DIRECTOR_REDUCER := preload("res://scripts/state/reducers/u_scene_director_reducer.gd")
const U_SCENE_DIRECTOR_SELECTORS := preload("res://scripts/state/selectors/u_scene_director_selectors.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const RS_SCENE_DIRECTIVE := preload("res://scripts/resources/scene_director/rs_scene_directive.gd")
const RS_BEAT_DEFINITION := preload("res://scripts/resources/scene_director/rs_beat_definition.gd")

class SceneDirectorStoreStub extends I_STATE_STORE:
	signal action_dispatched(action: Dictionary)
	signal store_ready()

	var _state: Dictionary = {
		"scene_director": {
			"active_directive_id": StringName(""),
			"current_beat_index": -1,
			"state": "idle",
		},
	}
	var _subscribers: Array[Callable] = []
	var _dispatched_actions: Array[Dictionary] = []

	func dispatch(action: Dictionary) -> void:
		var action_copy: Dictionary = action.duplicate(true)
		_dispatched_actions.append(action_copy)

		var director_slice: Dictionary = _state.get("scene_director", {}).duplicate(true)
		_state["scene_director"] = U_SCENE_DIRECTOR_REDUCER.reduce(director_slice, action_copy)

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

class ConditionStub extends Resource:
	var response_value: float = 1.0
	var evaluate_calls: int = 0
	var last_context: Dictionary = {}

	func _init(initial_value: float = 1.0) -> void:
		response_value = initial_value

	func evaluate(context: Dictionary) -> float:
		evaluate_calls += 1
		last_context = context.duplicate(true)
		return response_value

class ConditionPayloadFlagStub extends Resource:
	var evaluate_calls: int = 0
	var last_context: Dictionary = {}

	func evaluate(context: Dictionary) -> float:
		evaluate_calls += 1
		last_context = context.duplicate(true)
		var payload_variant: Variant = context.get("event_payload", {})
		if payload_variant is Dictionary:
			var payload := payload_variant as Dictionary
			return 1.0 if str(payload.get("flag", "")) == "ok" else 0.0
		return 0.0

class EffectStub extends Resource:
	var execute_calls: int = 0
	var last_context: Dictionary = {}

	func execute(context: Dictionary) -> void:
		execute_calls += 1
		last_context = context.duplicate(true)

var _store: SceneDirectorStoreStub

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()
	_store = SceneDirectorStoreStub.new()
	autofree(_store)

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()

func test_select_directive_picks_highest_priority_match() -> void:
	var pass_low := ConditionStub.new(1.0)
	var pass_high := ConditionStub.new(1.0)
	var fail_top := ConditionStub.new(0.0)
	var manager: Variant = await _spawn_manager(
		[
			_directive(StringName("dir_fail"), StringName("gameplay_base"), 100, [fail_top], []),
			_directive(StringName("dir_high"), StringName("gameplay_base"), 20, [pass_high], []),
			_directive(StringName("dir_low"), StringName("gameplay_base"), 5, [pass_low], []),
		]
	)

	var selected: Resource = manager._select_directive(StringName("gameplay_base"))

	assert_not_null(selected)
	assert_eq(selected.directive_id, StringName("dir_high"))
	assert_gt(fail_top.evaluate_calls, 0)
	assert_gt(pass_high.evaluate_calls, 0)

func test_no_directive_selected_for_non_matching_scene() -> void:
	var manager: Variant = await _spawn_manager(
		[
			_directive(StringName("dir_menu"), StringName("main_menu"), 1, [], []),
		]
	)

	var selected: Resource = manager._select_directive(StringName("gameplay_base"))
	assert_eq(selected, null)

func test_timed_beats_run_in_physics_process_and_complete() -> void:
	var beat_effect := EffectStub.new()
	var completed_events: Array[Dictionary] = []
	var unsubscribe_completed: Callable = U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_DIRECTIVE_COMPLETED,
		func(event: Dictionary) -> void:
			var payload_variant: Variant = event.get("payload", {})
			if payload_variant is Dictionary:
				completed_events.append((payload_variant as Dictionary).duplicate(true))
	)

	var manager: Variant = await _spawn_manager(
		[
			_directive(
				StringName("dir_timed"),
				StringName("gameplay_base"),
				1,
				[],
				[
					_beat(
						StringName("beat_timed"),
						RS_BEAT_DEFINITION.WaitMode.TIMED,
						0.2,
						StringName(""),
						[],
						[beat_effect]
					),
				]
			),
		]
	)

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))
	manager._physics_process(0.1)
	assert_eq(beat_effect.execute_calls, 1)
	assert_true(beat_effect.last_context.has("state_store"))
	assert_true(beat_effect.last_context.has("redux_state"))
	assert_true(U_SCENE_DIRECTOR_SELECTORS.is_running(_store.get_state()))

	manager._physics_process(0.1)
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_director_state(_store.get_state()), "completed")
	assert_true(_has_action(U_SCENE_DIRECTOR_ACTIONS.ACTION_COMPLETE_DIRECTIVE))
	assert_eq(completed_events.size(), 1)
	assert_eq(completed_events[0].get("directive_id", StringName("")), StringName("dir_timed"))

	if unsubscribe_completed.is_valid():
		unsubscribe_completed.call()

func test_signal_advancement_merges_event_payload_context() -> void:
	var beat_one_effect := EffectStub.new()
	var beat_two_condition := ConditionPayloadFlagStub.new()
	var beat_two_effect := EffectStub.new()
	var manager: Variant = await _spawn_manager(
		[
			_directive(
				StringName("dir_signal"),
				StringName("gameplay_base"),
				1,
				[],
				[
					_beat(
						StringName("beat_wait"),
						RS_BEAT_DEFINITION.WaitMode.SIGNAL,
						0.0,
						StringName("dialogue_done"),
						[],
						[beat_one_effect]
					),
					_beat(
						StringName("beat_after_signal"),
						RS_BEAT_DEFINITION.WaitMode.INSTANT,
						0.0,
						StringName(""),
						[beat_two_condition],
						[beat_two_effect]
					),
				]
			),
		]
	)

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))
	manager._physics_process(0.016)
	assert_eq(beat_one_effect.execute_calls, 1)
	assert_eq(beat_two_effect.execute_calls, 0)

	U_ECS_EVENT_BUS.publish(StringName("other_event"), {"flag": "ok"})
	assert_eq(beat_two_effect.execute_calls, 0)

	U_ECS_EVENT_BUS.publish(StringName("dialogue_done"), {"flag": "ok"})
	assert_eq(beat_two_condition.evaluate_calls, 1)
	assert_eq(beat_two_effect.execute_calls, 1)
	assert_true(beat_two_condition.last_context.has("event_payload"))
	assert_eq(
		beat_two_condition.last_context.get("event_payload", {}).get("flag", ""),
		"ok"
	)
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_director_state(_store.get_state()), "completed")

func test_signal_subscriptions_use_unique_wait_events_only() -> void:
	var manager: Variant = await _spawn_manager([])
	var directive: Resource = _directive(
		StringName("dir_wait_events"),
		StringName("gameplay_base"),
		1,
		[],
		[
			_beat(StringName("beat_a1"), RS_BEAT_DEFINITION.WaitMode.SIGNAL, 0.0, StringName("event_a")),
			_beat(StringName("beat_a2"), RS_BEAT_DEFINITION.WaitMode.SIGNAL, 0.0, StringName("event_a")),
			_beat(StringName("beat_b"), RS_BEAT_DEFINITION.WaitMode.SIGNAL, 0.0, StringName("event_b")),
			_beat(StringName("beat_ignore"), RS_BEAT_DEFINITION.WaitMode.TIMED, 0.1, StringName("")),
			_beat(StringName("beat_empty"), RS_BEAT_DEFINITION.WaitMode.SIGNAL, 0.0, StringName("")),
		]
	)

	manager._start_directive(directive)

	assert_eq(manager._signal_unsubscribes_by_event.size(), 2)
	assert_true(manager._signal_unsubscribes_by_event.has(StringName("event_a")))
	assert_true(manager._signal_unsubscribes_by_event.has(StringName("event_b")))

func test_signal_subscriptions_cleanup_on_complete_and_reset() -> void:
	var manager: Variant = await _spawn_manager(
		[
			_directive(
				StringName("dir_signal"),
				StringName("gameplay_base"),
				1,
				[],
				[
					_beat(
						StringName("beat_wait"),
						RS_BEAT_DEFINITION.WaitMode.SIGNAL,
						0.0,
						StringName("dialogue_done")
					),
				]
			),
		]
	)

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))
	assert_eq(manager._signal_unsubscribes_by_event.size(), 1)

	manager._physics_process(0.016)
	U_ECS_EVENT_BUS.publish(StringName("dialogue_done"), {})
	assert_eq(manager._signal_unsubscribes_by_event.size(), 0)

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("unknown_scene")))
	assert_eq(manager._signal_unsubscribes_by_event.size(), 0)
	assert_true(_has_action(U_SCENE_DIRECTOR_ACTIONS.ACTION_RESET))

func test_late_store_registration_resolves_during_idle_tick() -> void:
	U_SERVICE_LOCATOR.clear()
	var manager: Variant = await _spawn_manager(
		[
			_directive(
				StringName("dir_late_store"),
				StringName("gameplay_base"),
				1,
				[],
				[
					_beat(StringName("beat_once")),
				]
			),
		],
		false
	)

	# No store at _ready(); registration happens after manager is already in tree.
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)
	manager._physics_process(0.016)
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))

	assert_true(_has_action(U_SCENE_DIRECTOR_ACTIONS.ACTION_START_DIRECTIVE))

func test_branching_directive_uses_set_beat_index_and_skips_intermediate_beat() -> void:
	var start_effect := EffectStub.new()
	var skipped_effect := EffectStub.new()
	var end_effect := EffectStub.new()

	var start := _beat(StringName("beat_start"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [start_effect])
	start.next_beat_id = StringName("beat_end")
	var skipped := _beat(StringName("beat_skipped"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [skipped_effect])
	var ending := _beat(StringName("beat_end"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [end_effect])

	var manager: Variant = await _spawn_manager(
		[
			_directive(StringName("dir_branch"), StringName("gameplay_base"), 1, [], [start, skipped, ending]),
		]
	)

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))
	manager._physics_process(0.016)
	manager._physics_process(0.016)

	assert_eq(start_effect.execute_calls, 1)
	assert_eq(skipped_effect.execute_calls, 0)
	assert_eq(end_effect.execute_calls, 1)
	assert_true(_has_action(U_SCENE_DIRECTOR_ACTIONS.ACTION_SET_BEAT_INDEX))
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_current_beat_index(_store.get_state()), 3)
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_director_state(_store.get_state()), "completed")

func test_parallel_directive_dispatches_parallel_actions_and_completes_join() -> void:
	var lane_a_effect := EffectStub.new()
	var lane_b_effect := EffectStub.new()
	var join_effect := EffectStub.new()

	var fork := _beat(StringName("beat_fork"))
	var lane_a := _beat(StringName("lane_a"), RS_BEAT_DEFINITION.WaitMode.TIMED, 0.05, StringName(""), [], [lane_a_effect])
	var lane_b := _beat(StringName("lane_b"), RS_BEAT_DEFINITION.WaitMode.TIMED, 0.05, StringName(""), [], [lane_b_effect])
	var join := _beat(StringName("beat_join"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [join_effect])
	var lanes: Array[StringName] = [StringName("lane_a"), StringName("lane_b")]
	fork.parallel_beat_ids = lanes
	fork.parallel_join_beat_id = StringName("beat_join")

	var manager: Variant = await _spawn_manager(
		[
			_directive(StringName("dir_parallel"), StringName("gameplay_base"), 1, [], [fork, lane_a, lane_b, join]),
		]
	)

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))
	manager._physics_process(0.016)
	assert_true(_has_action(U_SCENE_DIRECTOR_ACTIONS.ACTION_START_PARALLEL))
	assert_true(U_SCENE_DIRECTOR_SELECTORS.is_parallel(_store.get_state()))

	manager._physics_process(0.05)
	assert_true(_has_action(U_SCENE_DIRECTOR_ACTIONS.ACTION_COMPLETE_PARALLEL))
	assert_false(U_SCENE_DIRECTOR_SELECTORS.is_parallel(_store.get_state()))

	manager._physics_process(0.016)
	assert_eq(lane_a_effect.execute_calls, 1)
	assert_eq(lane_b_effect.execute_calls, 1)
	assert_eq(join_effect.execute_calls, 1)
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_director_state(_store.get_state()), "completed")

func test_invalid_beat_graph_warns_and_skips_directive_start() -> void:
	var invalid_fork := _beat(StringName("beat_fork"))
	var lanes: Array[StringName] = [StringName("lane_a")]
	invalid_fork.parallel_beat_ids = lanes
	var lane_a := _beat(StringName("lane_a"))

	var manager: Variant = await _spawn_manager(
		[
			_directive(StringName("dir_invalid"), StringName("gameplay_base"), 1, [], [invalid_fork, lane_a]),
		]
	)

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))
	manager._physics_process(0.016)

	assert_true(_has_action(U_SCENE_DIRECTOR_ACTIONS.ACTION_RESET))
	assert_false(_has_action(U_SCENE_DIRECTOR_ACTIONS.ACTION_START_PARALLEL))
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_director_state(_store.get_state()), "idle")

func _spawn_manager(directive_list: Array[Resource], inject_store: bool = true) -> Variant:
	var manager := M_SCENE_DIRECTOR.new()
	if inject_store:
		manager.state_store = _store
	manager.directives = directive_list.duplicate(true)
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager

func _directive(
	directive_id: StringName,
	target_scene_id: StringName,
	priority: int,
	conditions: Array[Resource],
	beats: Array[Resource]
) -> Resource:
	var directive: Resource = RS_SCENE_DIRECTIVE.new()
	directive.directive_id = directive_id
	directive.target_scene_id = target_scene_id
	directive.priority = priority
	directive.selection_conditions = conditions.duplicate(true)
	directive.beats = beats.duplicate(true)
	return directive

func _beat(
	beat_id: StringName,
	wait_mode: int = RS_BEAT_DEFINITION.WaitMode.INSTANT,
	duration: float = 0.0,
	wait_event: StringName = StringName(""),
	preconditions: Array[Resource] = [],
	effects: Array[Resource] = []
) -> Resource:
	var beat: Resource = RS_BEAT_DEFINITION.new()
	beat.beat_id = beat_id
	beat.wait_mode = wait_mode
	beat.duration = duration
	beat.wait_event = wait_event
	beat.preconditions = preconditions.duplicate(true)
	beat.effects = effects.duplicate(true)
	beat.next_beat_id = StringName("")
	beat.next_beat_id_on_failure = StringName("")
	var empty_lanes: Array[StringName] = []
	beat.parallel_beat_ids = empty_lanes
	beat.parallel_join_beat_id = StringName("")
	return beat

func _has_action(action_type: StringName) -> bool:
	for action in _store.get_dispatched_actions():
		if action.get("type", StringName("")) == action_type:
			return true
	return false
