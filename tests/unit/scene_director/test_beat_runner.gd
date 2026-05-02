extends GutTest

const U_BEAT_RUNNER := preload("res://scripts/core/utils/scene_director/u_beat_runner.gd")
const RS_BEAT_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_beat_definition.gd")

class StoreStub extends RefCounted:
	var dispatched: Array[Dictionary] = []

	func dispatch(action: Dictionary) -> void:
		dispatched.append(action.duplicate(true))

class ConditionStub extends I_Condition:
	var score: float = 1.0
	var evaluate_calls: int = 0
	var last_context: Dictionary = {}

	func _init(initial_score: float = 1.0) -> void:
		score = initial_score

	func evaluate(context: Dictionary) -> float:
		evaluate_calls += 1
		last_context = context.duplicate(true)
		return score

class EffectStub extends I_Effect:
	var execute_calls: int = 0
	var last_context: Dictionary = {}

	func execute(context: Dictionary) -> void:
		execute_calls += 1
		last_context = context.duplicate(true)

var _runner: Variant
var _store: StoreStub

func before_each() -> void:
	_runner = U_BEAT_RUNNER.new()
	_store = StoreStub.new()

func test_start_initializes_with_first_beat() -> void:
	var beats: Array[Resource] = [
		_beat(StringName("beat_intro")),
		_beat(StringName("beat_followup")),
	]

	_runner.start(beats)

	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 0)
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_intro"))

func test_instant_beats_auto_advance_after_effect_execution() -> void:
	var effect := EffectStub.new()
	var beats: Array[Resource] = [
		_beat(
			StringName("beat_instant"),
			RS_BEAT_DEFINITION.WaitMode.INSTANT,
			0.0,
			StringName(""),
			[],
			[effect]
		),
	]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())

	assert_eq(effect.execute_calls, 1)
	assert_true(effect.last_context.has("state_store"))
	assert_true(effect.last_context.has("redux_state"))
	assert_true(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 1)

func test_timed_beats_advance_after_duration_elapsed() -> void:
	var effect := EffectStub.new()
	var beats: Array[Resource] = [
		_beat(
			StringName("beat_timed"),
			RS_BEAT_DEFINITION.WaitMode.TIMED,
			0.5,
			StringName(""),
			[],
			[effect]
		),
	]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())
	assert_eq(effect.execute_calls, 1)
	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 0)

	_runner.update(0.2)
	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 0)

	_runner.update(0.3)
	assert_true(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 1)

func test_signal_beats_advance_only_on_matching_event() -> void:
	var effect := EffectStub.new()
	var beats: Array[Resource] = [
		_beat(
			StringName("beat_signal"),
			RS_BEAT_DEFINITION.WaitMode.SIGNAL,
			0.0,
			StringName("dialogue_complete"),
			[],
			[effect]
		),
	]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())
	assert_eq(effect.execute_calls, 1)
	assert_false(_runner.is_complete())

	_runner.on_signal_received(StringName("other_event"))
	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 0)

	_runner.on_signal_received(StringName("dialogue_complete"))
	assert_true(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 1)

func test_precondition_gating_skips_effects_when_conditions_fail() -> void:
	var condition := ConditionStub.new(0.0)
	var effect := EffectStub.new()
	var beats: Array[Resource] = [
		_beat(
			StringName("beat_guarded"),
			RS_BEAT_DEFINITION.WaitMode.INSTANT,
			0.0,
			StringName(""),
			[condition],
			[effect]
		),
	]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())

	assert_eq(condition.evaluate_calls, 1)
	assert_eq(effect.execute_calls, 0)
	assert_true(condition.last_context.has("state_store"))
	assert_true(condition.last_context.has("redux_state"))
	assert_true(_runner.is_complete())

func test_is_complete_true_after_all_beats_advance() -> void:
	var beats: Array[Resource] = [
		_beat(StringName("beat_1")),
		_beat(StringName("beat_2")),
	]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())
	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 1)

	_runner.execute_current_beat(_build_context())
	assert_true(_runner.is_complete())
	assert_eq(_runner.get_current_index(), 2)

func test_empty_beat_list_is_immediately_complete() -> void:
	var beats: Array[Resource] = []
	_runner.start(beats)

	assert_true(_runner.is_complete())
	assert_eq(_runner.get_current_beat(), null)

func test_next_beat_id_jumps_to_target_on_successful_completion() -> void:
	var first_effect := EffectStub.new()
	var jump_target_effect := EffectStub.new()
	var skipped_effect := EffectStub.new()
	var first := _beat(StringName("beat_first"))
	first.next_beat_id = StringName("beat_jump_target")
	var skipped := _beat(StringName("beat_skipped"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [skipped_effect])
	var jump_target := _beat(
		StringName("beat_jump_target"),
		RS_BEAT_DEFINITION.WaitMode.INSTANT,
		0.0,
		StringName(""),
		[],
		[jump_target_effect]
	)
	var first_effects: Array[I_Effect] = [first_effect]
	first.effects = first_effects
	var beats: Array[Resource] = [first, skipped, jump_target]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())
	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_jump_target"))
	assert_eq(skipped_effect.execute_calls, 0)

	_runner.execute_current_beat(_build_context())
	assert_true(_runner.is_complete())
	assert_eq(first_effect.execute_calls, 1)
	assert_eq(jump_target_effect.execute_calls, 1)

func test_next_beat_id_on_failure_jumps_when_preconditions_fail() -> void:
	var failing_condition := ConditionStub.new(0.0)
	var first_effect := EffectStub.new()
	var fail_target_effect := EffectStub.new()

	var first := _beat(
		StringName("beat_guarded"),
		RS_BEAT_DEFINITION.WaitMode.INSTANT,
		0.0,
		StringName(""),
		[failing_condition],
		[first_effect]
	)
	first.next_beat_id_on_failure = StringName("beat_failure_target")

	var middle := _beat(StringName("beat_middle"))
	var fail_target := _beat(
		StringName("beat_failure_target"),
		RS_BEAT_DEFINITION.WaitMode.INSTANT,
		0.0,
		StringName(""),
		[],
		[fail_target_effect]
	)

	var beats: Array[Resource] = [first, middle, fail_target]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())
	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_failure_target"))
	assert_eq(first_effect.execute_calls, 0)

	_runner.execute_current_beat(_build_context())
	assert_true(_runner.is_complete())
	assert_eq(fail_target_effect.execute_calls, 1)

func test_failure_without_failure_target_falls_back_to_sequential_not_success_target() -> void:
	var failing_condition := ConditionStub.new(0.0)

	var guarded := _beat(
		StringName("beat_guarded"),
		RS_BEAT_DEFINITION.WaitMode.INSTANT,
		0.0,
		StringName(""),
		[failing_condition]
	)
	guarded.next_beat_id = StringName("beat_success_target")
	guarded.next_beat_id_on_failure = StringName("")

	var sequential := _beat(StringName("beat_sequential"))
	var success_target := _beat(StringName("beat_success_target"))
	var beats: Array[Resource] = [guarded, sequential, success_target]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())

	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_sequential"))

func test_unknown_next_beat_id_falls_back_to_sequential_advance() -> void:
	var first := _beat(StringName("beat_first"))
	first.next_beat_id = StringName("missing_target")
	var second := _beat(StringName("beat_second"))
	var beats: Array[Resource] = [first, second]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())

	assert_false(_runner.is_complete())
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_second"))

func test_parallel_fork_join_runs_lane_runners_and_jumps_to_join() -> void:
	var fork_effect := EffectStub.new()
	var lane_a_effect := EffectStub.new()
	var lane_b_effect := EffectStub.new()
	var join_effect := EffectStub.new()

	var fork := _beat(StringName("beat_fork"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [fork_effect])
	var lane_a := _beat(StringName("lane_a"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [lane_a_effect])
	var lane_b := _beat(StringName("lane_b"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [lane_b_effect])
	var join := _beat(StringName("beat_join"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [join_effect])

	var lanes: Array[StringName] = [StringName("lane_a"), StringName("lane_b")]
	fork.parallel_beat_ids = lanes
	fork.parallel_join_beat_id = StringName("beat_join")

	var beats: Array[Resource] = [fork, lane_a, lane_b, join]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())
	assert_true(_runner.is_waiting_parallel())
	assert_eq(_runner.get_parallel_runners().size(), 2)
	assert_eq(fork_effect.execute_calls, 1)
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_fork"))

	_runner.update(0.016, _build_context())
	assert_false(_runner.is_waiting_parallel())
	assert_eq(lane_a_effect.execute_calls, 1)
	assert_eq(lane_b_effect.execute_calls, 1)
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_join"))

	_runner.execute_current_beat(_build_context())
	assert_true(_runner.is_complete())
	assert_eq(join_effect.execute_calls, 1)

func test_parallel_signal_propagates_to_lane_runners() -> void:
	var lane_effect := EffectStub.new()
	var join_effect := EffectStub.new()

	var fork := _beat(StringName("beat_fork"))
	var lane := _beat(
		StringName("lane_signal"),
		RS_BEAT_DEFINITION.WaitMode.SIGNAL,
		0.0,
		StringName("lane_done"),
		[],
		[lane_effect]
	)
	var join := _beat(StringName("beat_join"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""), [], [join_effect])
	var lanes: Array[StringName] = [StringName("lane_signal")]
	fork.parallel_beat_ids = lanes
	fork.parallel_join_beat_id = StringName("beat_join")

	var beats: Array[Resource] = [fork, lane, join]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())
	_runner.update(0.016, _build_context())
	assert_true(_runner.is_waiting_parallel())
	assert_eq(lane_effect.execute_calls, 1)

	_runner.on_signal_received(StringName("lane_done"))
	_runner.update(0.016, _build_context())
	assert_false(_runner.is_waiting_parallel())
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_join"))

	_runner.execute_current_beat(_build_context())
	assert_true(_runner.is_complete())
	assert_eq(join_effect.execute_calls, 1)

func test_parallel_with_no_valid_lanes_jumps_to_join() -> void:
	var fork := _beat(StringName("beat_fork"))
	var join := _beat(StringName("beat_join"))
	var lanes: Array[StringName] = [StringName("lane_missing")]
	fork.parallel_beat_ids = lanes
	fork.parallel_join_beat_id = StringName("beat_join")
	var beats: Array[Resource] = [fork, join]
	_runner.start(beats)

	_runner.execute_current_beat(_build_context())

	assert_false(_runner.is_waiting_parallel())
	assert_eq(_runner.get_current_beat().beat_id, StringName("beat_join"))

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
	var typed_preconditions: Array[I_Condition] = []
	for c in preconditions:
		if c is I_Condition:
			typed_preconditions.append(c as I_Condition)
	beat.preconditions = typed_preconditions
	var typed_effects: Array[I_Effect] = []
	for e in effects:
		if e is I_Effect:
			typed_effects.append(e as I_Effect)
	beat.effects = typed_effects
	beat.next_beat_id = StringName("")
	beat.next_beat_id_on_failure = StringName("")
	var empty_lanes: Array[StringName] = []
	beat.parallel_beat_ids = empty_lanes
	beat.parallel_join_beat_id = StringName("")
	return beat

func _build_context() -> Dictionary:
	return {
		"state_store": _store,
		"redux_state": {},
	}
