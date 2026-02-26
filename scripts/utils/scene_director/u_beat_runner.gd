extends RefCounted
class_name U_BeatRunner

const RS_BEAT_DEFINITION := preload("res://scripts/resources/scene_director/rs_beat_definition.gd")

var _beats: Array[Resource] = []
var _beat_id_to_index: Dictionary = {}
var _current_index: int = 0
var _has_executed_current_beat: bool = false
var _is_waiting_timed: bool = false
var _timed_elapsed: float = 0.0
var _timed_duration: float = 0.0
var _is_waiting_signal: bool = false
var _waiting_signal_event: StringName = StringName("")
var _is_waiting_parallel: bool = false
var _parallel_runners: Array = []
var _parallel_lane_ids: Array[StringName] = []
var _parallel_join_index: int = -1

func start(beats: Array[Resource]) -> void:
	_beats = beats.duplicate()
	_beat_id_to_index = _build_id_to_index_map(_beats)
	_current_index = 0
	_reset_wait_state()
	_reset_parallel_state()

func execute_current_beat(context: Dictionary) -> void:
	if is_complete():
		return
	if _is_waiting_parallel:
		return
	if _has_executed_current_beat:
		return

	var beat: Resource = get_current_beat()
	if beat == null:
		advance()
		return

	var preconditions: Array[Resource] = _to_resource_array(_resource_get(beat, "preconditions", []))
	if not _check_conditions(preconditions, context):
		var failure_target: StringName = _to_string_name(
			_resource_get(beat, "next_beat_id_on_failure", StringName(""))
		)
		_advance_to_next(beat, failure_target)
		return

	var effects: Array[Resource] = _to_resource_array(_resource_get(beat, "effects", []))
	_execute_effects(effects, context)
	_has_executed_current_beat = true

	var next_target: StringName = _to_string_name(
		_resource_get(beat, "next_beat_id", StringName(""))
	)
	var wait_mode: int = _to_wait_mode(_resource_get(beat, "wait_mode", RS_BEAT_DEFINITION.WaitMode.INSTANT))
	match wait_mode:
		RS_BEAT_DEFINITION.WaitMode.INSTANT:
			var lane_ids: Array[StringName] = _to_string_name_array(
				_resource_get(beat, "parallel_beat_ids", [])
			)
			if not lane_ids.is_empty():
				var join_id: StringName = _to_string_name(
					_resource_get(beat, "parallel_join_beat_id", StringName(""))
				)
				_start_parallel(lane_ids, join_id)
				return
			_advance_to_next(beat, next_target)
		RS_BEAT_DEFINITION.WaitMode.TIMED:
			_is_waiting_timed = true
			_timed_elapsed = 0.0
			_timed_duration = max(_to_float(_resource_get(beat, "duration", 0.0), 0.0), 0.0)
			if _timed_duration <= 0.0:
				_advance_to_next(beat, next_target)
		RS_BEAT_DEFINITION.WaitMode.SIGNAL:
			_is_waiting_signal = true
			_waiting_signal_event = _to_string_name(_resource_get(beat, "wait_event", StringName("")))
			if _waiting_signal_event == StringName(""):
				_advance_to_next(beat, next_target)
		_:
			_advance_to_next(beat, next_target)

func advance() -> void:
	if is_complete():
		return
	_current_index += 1
	_reset_wait_state()
	_reset_parallel_state()

func is_complete() -> bool:
	return _current_index >= _beats.size()

func get_current_beat() -> Resource:
	if is_complete():
		return null
	return _beats[_current_index] as Resource

func get_current_index() -> int:
	return _current_index

func update(delta: float, context: Dictionary = {}) -> void:
	if is_complete():
		return
	if _is_waiting_parallel:
		_update_parallel(delta, context)
		return
	if not _is_waiting_timed:
		return

	_timed_elapsed += max(delta, 0.0)
	if _timed_elapsed >= _timed_duration:
		var beat: Resource = get_current_beat()
		var next_target: StringName = _to_string_name(
			_resource_get(beat, "next_beat_id", StringName(""))
		)
		_advance_to_next(beat, next_target)

func on_signal_received(event_name: StringName) -> void:
	if is_complete():
		return
	if _is_waiting_parallel:
		for runner_variant in _parallel_runners:
			var runner: Variant = runner_variant
			if runner == null:
				continue
			if not runner.has_method("on_signal_received"):
				continue
			runner.on_signal_received(event_name)
		return
	if not _is_waiting_signal:
		return
	if _to_string_name(event_name) != _waiting_signal_event:
		return

	var beat: Resource = get_current_beat()
	var next_target: StringName = _to_string_name(
		_resource_get(beat, "next_beat_id", StringName(""))
	)
	_advance_to_next(beat, next_target)

func is_waiting_parallel() -> bool:
	return _is_waiting_parallel

func is_parallel_complete() -> bool:
	return not _is_waiting_parallel and _parallel_runners.is_empty() and _parallel_lane_ids.is_empty()

func get_parallel_runners() -> Array:
	return _parallel_runners.duplicate()

func _advance_to_next(current_beat: Resource, explicit_target: StringName = StringName("")) -> void:
	if is_complete():
		return

	var next_index: int = _resolve_target_index(explicit_target)
	if next_index < 0:
		var fallback_target: StringName = _to_string_name(
			_resource_get(current_beat, "next_beat_id", StringName(""))
		)
		next_index = _resolve_target_index(fallback_target)
	if next_index < 0:
		next_index = _current_index + 1

	_current_index = next_index
	_reset_wait_state()
	_reset_parallel_state()

func _start_parallel(lane_ids: Array[StringName], join_id: StringName) -> void:
	_reset_parallel_state()
	_is_waiting_parallel = true
	_parallel_lane_ids = lane_ids.duplicate()
	_parallel_join_index = _resolve_target_index(join_id)

	for lane_id in lane_ids:
		var lane_index: int = _resolve_target_index(lane_id)
		if lane_index < 0 or lane_index >= _beats.size():
			continue
		var lane_beat: Resource = _beats[lane_index] as Resource
		if lane_beat == null:
			continue

		var lane_runner := U_BeatRunner.new()
		var lane_beats: Array[Resource] = [lane_beat]
		lane_runner.start(lane_beats)
		_parallel_runners.append(lane_runner)

	if _parallel_runners.is_empty():
		_complete_parallel_wait()

func _update_parallel(delta: float, context: Dictionary) -> void:
	var remaining: Array = []
	for runner_variant in _parallel_runners:
		var runner: Variant = runner_variant
		if runner == null:
			continue
		if runner.has_method("execute_current_beat"):
			runner.execute_current_beat(context)
		if runner.has_method("update"):
			runner.update(delta, context)
		if runner.has_method("is_complete") and not runner.is_complete():
			remaining.append(runner)

	_parallel_runners = remaining
	if _parallel_runners.is_empty():
		_complete_parallel_wait()

func _complete_parallel_wait() -> void:
	var next_index: int = _parallel_join_index
	if next_index < 0:
		next_index = _current_index + 1

	_current_index = next_index
	_reset_wait_state()
	_reset_parallel_state()

func _resolve_target_index(beat_id: StringName) -> int:
	if beat_id == StringName(""):
		return -1
	if not _beat_id_to_index.has(beat_id):
		return -1

	var index_variant: Variant = _beat_id_to_index.get(beat_id, -1)
	if index_variant is int:
		return index_variant
	return -1

func _build_id_to_index_map(beats: Array[Resource]) -> Dictionary:
	var map: Dictionary = {}
	for index in range(beats.size()):
		var beat: Resource = beats[index]
		var beat_id: StringName = _to_string_name(_resource_get(beat, "beat_id", StringName("")))
		if beat_id == StringName(""):
			continue
		if map.has(beat_id):
			continue
		map[beat_id] = index
	return map

func _check_conditions(conditions: Array[Resource], context: Dictionary) -> bool:
	for condition_resource in conditions:
		var condition: Variant = condition_resource
		if condition == null:
			return false
		if not condition.has_method("evaluate"):
			return false

		var score: float = _to_float(condition.evaluate(context), 0.0)
		if score <= 0.0:
			return false
	return true

func _execute_effects(effects: Array[Resource], context: Dictionary) -> void:
	for effect_resource in effects:
		var effect: Variant = effect_resource
		if effect == null:
			continue
		if not effect.has_method("execute"):
			continue
		effect.execute(context)

func _reset_wait_state() -> void:
	_has_executed_current_beat = false
	_is_waiting_timed = false
	_timed_elapsed = 0.0
	_timed_duration = 0.0
	_is_waiting_signal = false
	_waiting_signal_event = StringName("")

func _reset_parallel_state() -> void:
	_is_waiting_parallel = false
	_parallel_runners.clear()
	_parallel_lane_ids.clear()
	_parallel_join_index = -1

func _to_wait_mode(value: Variant) -> int:
	if value is int:
		return value
	return RS_BEAT_DEFINITION.WaitMode.INSTANT

func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	return value if value != null else fallback

func _to_resource_array(value: Variant) -> Array[Resource]:
	var resources: Array[Resource] = []
	if value is Array:
		for item in value:
			if item is Resource:
				resources.append(item as Resource)
	return resources

func _to_float(value: Variant, fallback: float) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback

func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")

func _to_string_name_array(value: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	if value is Array:
		for entry in value:
			var name: StringName = _to_string_name(entry)
			if name == StringName(""):
				continue
			names.append(name)
	elif value is PackedStringArray:
		for entry in value:
			var name: StringName = _to_string_name(entry)
			if name == StringName(""):
				continue
			names.append(name)
	return names
