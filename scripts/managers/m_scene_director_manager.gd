@icon("res://assets/editor_icons/icn_manager.svg")
extends I_SceneDirector
class_name M_SceneDirectorManager

const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_SCENE_DIRECTOR_ACTIONS := preload("res://scripts/state/actions/u_scene_director_actions.gd")
const U_BEAT_RUNNER := preload("res://scripts/utils/scene_director/u_beat_runner.gd")
const U_BEAT_GRAPH := preload("res://scripts/utils/scene_director/u_beat_graph.gd")
const RS_BEAT_DEFINITION := preload("res://scripts/resources/scene_director/rs_beat_definition.gd")
const RSRuleContext := preload("res://scripts/resources/ecs/rs_rule_context.gd")

@export var state_store: I_StateStore = null
@export var directives: Array[Resource] = []

var _store: I_StateStore:
	get: return _binder.store
var _binder: U_StoreActionBinder = U_StoreActionBinder.new()
var _beat_runner: U_BeatRunner = null
var _active_directive: Resource = null
var _signal_unsubscribes_by_event: Dictionary = {}
var _last_reported_current_beat_id: StringName = StringName("")
var _last_reported_active_beat_ids: Array[StringName] = []

func _ready() -> void:
	_beat_runner = U_BEAT_RUNNER.new()
	_binder.resolve(state_store, self, _on_action_dispatched)

func _exit_tree() -> void:
	_binder.disconnect_signal(_on_action_dispatched)
	_clear_signal_subscriptions()

func _physics_process(delta: float) -> void:
	# Keep retrying store discovery so late ServiceLocator registration can attach
	# action subscriptions even while the director is idle.
	if _store == null:
		_binder.resolve(state_store, self, _on_action_dispatched)

	if _active_directive == null:
		return
	if _beat_runner == null:
		return

	var context: Dictionary = _build_context()
	var before_index: int = U_ResourceAccessHelpers.to_int(_beat_runner.get_current_index(), -1)
	var was_waiting_parallel: bool = _is_runner_waiting_parallel()
	_beat_runner.execute_current_beat(context)
	_process_runner_state_change(before_index, was_waiting_parallel)

	if _active_directive == null:
		return
	if _beat_runner.is_complete():
		_on_directive_complete()
		return

	before_index = U_ResourceAccessHelpers.to_int(_beat_runner.get_current_index(), -1)
	was_waiting_parallel = _is_runner_waiting_parallel()
	_beat_runner.update(delta, context)
	_process_runner_state_change(before_index, was_waiting_parallel)

	if _active_directive == null:
		return
	if _beat_runner.is_complete():
		_on_directive_complete()

func _select_directive(scene_id: StringName) -> Resource:
	if scene_id == StringName(""):
		return null

	var best_directive: Resource = null
	var best_priority: int = -2147483648
	var best_id: StringName = StringName("")
	var context: Dictionary = _build_context()

	for directive in directives:
		if directive == null:
			continue

		var target_scene_id: StringName = U_ResourceAccessHelpers.to_string_name(
			U_ResourceAccessHelpers.resource_get(directive, "target_scene_id", StringName(""))
		)
		if target_scene_id != scene_id:
			continue

		var selection_conditions: Array[Resource] = U_ResourceAccessHelpers.to_resource_array(
			U_ResourceAccessHelpers.resource_get(directive, "selection_conditions", [])
		)
		if not _check_conditions(selection_conditions, context):
			continue

		var priority: int = U_ResourceAccessHelpers.to_int(U_ResourceAccessHelpers.resource_get(directive, "priority", 0), 0)
		var directive_id: StringName = _get_directive_id(directive)
		if best_directive == null:
			best_directive = directive
			best_priority = priority
			best_id = directive_id
			continue

		var should_replace: bool = priority > best_priority
		if not should_replace and priority == best_priority:
			should_replace = String(directive_id) < String(best_id)

		if should_replace:
			best_directive = directive
			best_priority = priority
			best_id = directive_id

	return best_directive

func _start_directive(directive: Resource) -> void:
	if directive == null:
		return

	if _beat_runner == null:
		_beat_runner = U_BEAT_RUNNER.new()

	_clear_signal_subscriptions()
	_active_directive = directive
	_reset_reported_beat_state()

	var directive_id: StringName = _get_directive_id(directive)
	var beats: Array[Resource] = U_ResourceAccessHelpers.to_resource_array(U_ResourceAccessHelpers.resource_get(directive, "beats", []))

	var graph_report: Dictionary = U_BEAT_GRAPH.validate(beats)
	if not bool(graph_report.get("valid", false)):
		print(
			"M_SceneDirectorManager: Invalid beat graph for directive '%s': %s"
			% [str(directive_id), str(graph_report.get("errors", []))]
		)
		_reset_director_state()
		return

	_beat_runner.start(beats)

	if _store != null:
		_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.start_directive(directive_id))

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_DIRECTIVE_STARTED, {
		"directive_id": directive_id,
	})

	_process_runner_state_change(-1, false)
	_subscribe_signal_events(beats)

func _on_directive_complete() -> void:
	if _active_directive == null:
		return

	var directive_id: StringName = _get_directive_id(_active_directive)
	if _store != null:
		_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.complete_directive())
		_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.set_current_beat(StringName("")))
		var empty_active: Array[StringName] = []
		_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.set_active_beats(empty_active))
		_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.complete_parallel())

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_DIRECTIVE_COMPLETED, {
		"directive_id": directive_id,
	})

	_active_directive = null
	_reset_reported_beat_state()
	_clear_signal_subscriptions()
	if _beat_runner != null:
		var empty_beats: Array[Resource] = []
		_beat_runner.start(empty_beats)

func get_active_directive_id() -> StringName:
	if _active_directive == null:
		return StringName("")
	return _get_directive_id(_active_directive)

func _build_context() -> Dictionary:
	_binder.resolve(state_store, self, _on_action_dispatched)

	var rule_context: RefCounted = RSRuleContext.new()
	if _store != null:
		rule_context.redux_state = _store.get_state()
		rule_context.state_store = _store
	return rule_context.to_dictionary()

func _build_event_context(event_payload: Dictionary) -> Dictionary:
	var context: Dictionary = _build_context()
	context[RSRuleContext.KEY_EVENT_PAYLOAD] = event_payload.duplicate(true)
	return context

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = U_ResourceAccessHelpers.to_string_name(action.get("type", StringName("")))
	if action_type != U_SCENE_ACTIONS.ACTION_TRANSITION_COMPLETED:
		return

	var payload: Dictionary = {}
	var payload_variant: Variant = action.get("payload", {})
	if payload_variant is Dictionary:
		payload = payload_variant as Dictionary
	var scene_id: StringName = U_ResourceAccessHelpers.to_string_name(payload.get("scene_id", StringName("")))
	if scene_id == StringName(""):
		return

	var directive: Resource = _select_directive(scene_id)
	if directive == null:
		_reset_director_state()
		return

	_start_directive(directive)

func _reset_director_state() -> void:
	_active_directive = null
	_reset_reported_beat_state()
	_clear_signal_subscriptions()
	if _beat_runner != null:
		var empty_beats: Array[Resource] = []
		_beat_runner.start(empty_beats)
	if _store != null:
		_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.reset())

func _subscribe_signal_events(beats: Array[Resource]) -> void:
	var unique_events: Dictionary = {}
	for beat in beats:
		if beat == null:
			continue

		var wait_mode: int = U_ResourceAccessHelpers.to_int(
			U_ResourceAccessHelpers.resource_get(beat, "wait_mode", RS_BEAT_DEFINITION.WaitMode.INSTANT),
			RS_BEAT_DEFINITION.WaitMode.INSTANT
		)
		if wait_mode != RS_BEAT_DEFINITION.WaitMode.SIGNAL:
			continue

		var wait_event: StringName = U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(beat, "wait_event", StringName("")))
		if wait_event == StringName(""):
			continue

		unique_events[wait_event] = true

	for event_name_variant in unique_events.keys():
		var wait_event: StringName = U_ResourceAccessHelpers.to_string_name(event_name_variant)
		var unsubscribe: Callable = U_ECS_EVENT_BUS.subscribe(
			wait_event,
			func(event: Dictionary) -> void:
				_on_signal_event(wait_event, event)
		)
		_signal_unsubscribes_by_event[wait_event] = unsubscribe

func _on_signal_event(wait_event: StringName, event: Dictionary) -> void:
	if _active_directive == null:
		return
	if _beat_runner == null:
		return

	var before_index: int = U_ResourceAccessHelpers.to_int(_beat_runner.get_current_index(), -1)
	var was_waiting_parallel: bool = _is_runner_waiting_parallel()
	_beat_runner.on_signal_received(wait_event)
	_process_runner_state_change(before_index, was_waiting_parallel)

	if _active_directive == null:
		return
	if _beat_runner.is_complete():
		_on_directive_complete()
		return

	var payload: Dictionary = {}
	var payload_variant: Variant = event.get("payload", {})
	if payload_variant is Dictionary:
		payload = (payload_variant as Dictionary).duplicate(true)
	var event_context: Dictionary = _build_event_context(payload)

	before_index = U_ResourceAccessHelpers.to_int(_beat_runner.get_current_index(), -1)
	was_waiting_parallel = _is_runner_waiting_parallel()
	_beat_runner.execute_current_beat(event_context)
	_process_runner_state_change(before_index, was_waiting_parallel)

	if _active_directive == null:
		return
	if _beat_runner.is_complete():
		_on_directive_complete()

func _process_runner_state_change(previous_index: int, previous_parallel_waiting: bool) -> void:
	if _beat_runner == null:
		return

	var current_index: int = U_ResourceAccessHelpers.to_int(_beat_runner.get_current_index(), previous_index)
	var waiting_parallel: bool = _is_runner_waiting_parallel()
	var current_beat_id: StringName = _get_runner_current_beat_id()
	var active_beat_ids: Array[StringName] = _get_runner_active_beat_ids()

	if _store != null:
		if current_index != previous_index:
			_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.set_beat_index(current_index))
		if current_beat_id != _last_reported_current_beat_id:
			_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.set_current_beat(current_beat_id))
		if not _string_name_arrays_equal(active_beat_ids, _last_reported_active_beat_ids):
			_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.set_active_beats(active_beat_ids))
		if waiting_parallel and not previous_parallel_waiting:
			_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.start_parallel(active_beat_ids))
		elif previous_parallel_waiting and not waiting_parallel:
			_store.dispatch(U_SCENE_DIRECTOR_ACTIONS.complete_parallel())
		_last_reported_current_beat_id = current_beat_id
		_last_reported_active_beat_ids = active_beat_ids.duplicate()

	if current_index != previous_index and previous_index >= 0:
		_dispatch_beat_advanced_event(current_beat_id, active_beat_ids)

func _dispatch_beat_advanced_event(
	current_beat_id: StringName,
	active_beat_ids: Array[StringName]
) -> void:
	if _active_directive == null:
		return

	var directive_id: StringName = _get_directive_id(_active_directive)
	var current_index: int = -1
	if _beat_runner != null:
		current_index = U_ResourceAccessHelpers.to_int(_beat_runner.get_current_index(), -1)
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_BEAT_ADVANCED, {
		"directive_id": directive_id,
		"current_beat_index": current_index,
		"current_beat_id": current_beat_id,
		"active_beat_ids": active_beat_ids.duplicate(),
	})

func _is_runner_waiting_parallel() -> bool:
	if _beat_runner == null:
		return false
	return bool(_beat_runner.is_waiting_parallel())

func _get_runner_current_beat_id() -> StringName:
	if _beat_runner == null:
		return StringName("")
	var beat: Variant = _beat_runner.get_current_beat()
	if beat == null or not (beat is Resource):
		return StringName("")
	return U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(beat as Resource, "beat_id", StringName("")))

func _get_runner_active_beat_ids() -> Array[StringName]:
	if not _is_runner_waiting_parallel():
		var current_id: StringName = _get_runner_current_beat_id()
		if current_id == StringName(""):
			return []
		return [current_id]

	var active_ids: Array[StringName] = []
	if _beat_runner == null:
		return active_ids

	var lane_runners: Array[U_BeatRunner] = _beat_runner.get_parallel_runners()
	for lane_runner in lane_runners:
		if lane_runner == null:
			continue
		var lane_beat: Variant = lane_runner.get_current_beat()
		if lane_beat == null or not (lane_beat is Resource):
			continue
		var lane_id: StringName = U_ResourceAccessHelpers.to_string_name(
			U_ResourceAccessHelpers.resource_get(lane_beat as Resource, "beat_id", StringName(""))
		)
		if lane_id == StringName(""):
			continue
		if not active_ids.has(lane_id):
			active_ids.append(lane_id)
	return active_ids

func _clear_signal_subscriptions() -> void:
	for unsubscribe_variant in _signal_unsubscribes_by_event.values():
		if unsubscribe_variant is Callable:
			var unsubscribe: Callable = unsubscribe_variant
			if unsubscribe.is_valid():
				unsubscribe.call()
	_signal_unsubscribes_by_event.clear()

func _reset_reported_beat_state() -> void:
	_last_reported_current_beat_id = StringName("")
	_last_reported_active_beat_ids.clear()

func _string_name_arrays_equal(left: Array[StringName], right: Array[StringName]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if left[index] != right[index]:
			return false
	return true

func _check_conditions(conditions: Array[Resource], context: Dictionary) -> bool:
	for condition_resource in conditions:
		var condition: Variant = condition_resource
		if condition == null:
			return false
		if not condition is I_Condition:
			return false

		var score: float = U_ResourceAccessHelpers.to_float(condition.evaluate(context), 0.0)
		if score <= 0.0:
			return false
	return true

func _get_directive_id(directive: Resource) -> StringName:
	return U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(directive, "directive_id", StringName("")))

