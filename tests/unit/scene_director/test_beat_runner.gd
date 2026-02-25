extends GutTest

const U_BEAT_RUNNER := preload("res://scripts/utils/scene_director/u_beat_runner.gd")
const RS_BEAT_DEFINITION := preload("res://scripts/resources/scene_director/rs_beat_definition.gd")

class StoreStub extends RefCounted:
	var dispatched: Array[Dictionary] = []

	func dispatch(action: Dictionary) -> void:
		dispatched.append(action.duplicate(true))

class ConditionStub extends Resource:
	var score: float = 1.0
	var evaluate_calls: int = 0
	var last_context: Dictionary = {}

	func _init(initial_score: float = 1.0) -> void:
		score = initial_score

	func evaluate(context: Dictionary) -> float:
		evaluate_calls += 1
		last_context = context.duplicate(true)
		return score

class EffectStub extends Resource:
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
	return beat

func _build_context() -> Dictionary:
	return {
		"state_store": _store,
		"redux_state": {},
	}
