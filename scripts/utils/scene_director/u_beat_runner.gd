extends RefCounted
class_name U_BeatRunner

const RS_BEAT_DEFINITION := preload("res://scripts/resources/scene_director/rs_beat_definition.gd")

var _beats: Array[Resource] = []
var _current_index: int = 0
var _has_executed_current_beat: bool = false
var _is_waiting_timed: bool = false
var _timed_elapsed: float = 0.0
var _timed_duration: float = 0.0
var _is_waiting_signal: bool = false
var _waiting_signal_event: StringName = StringName("")

func start(beats: Array[Resource]) -> void:
	_beats = beats.duplicate()
	_current_index = 0
	_reset_wait_state()

func execute_current_beat(context: Dictionary) -> void:
	if is_complete():
		return
	if _has_executed_current_beat:
		return

	var beat: Resource = get_current_beat()
	if beat == null:
		advance()
		return

	var preconditions: Array[Resource] = _to_resource_array(_resource_get(beat, "preconditions", []))
	if not _check_conditions(preconditions, context):
		advance()
		return

	var effects: Array[Resource] = _to_resource_array(_resource_get(beat, "effects", []))
	_execute_effects(effects, context)
	_has_executed_current_beat = true

	var wait_mode: int = _to_wait_mode(_resource_get(beat, "wait_mode", RS_BEAT_DEFINITION.WaitMode.INSTANT))
	match wait_mode:
		RS_BEAT_DEFINITION.WaitMode.INSTANT:
			advance()
		RS_BEAT_DEFINITION.WaitMode.TIMED:
			_is_waiting_timed = true
			_timed_elapsed = 0.0
			_timed_duration = max(_to_float(_resource_get(beat, "duration", 0.0), 0.0), 0.0)
			if _timed_duration <= 0.0:
				advance()
		RS_BEAT_DEFINITION.WaitMode.SIGNAL:
			_is_waiting_signal = true
			_waiting_signal_event = _to_string_name(_resource_get(beat, "wait_event", StringName("")))
			if _waiting_signal_event == StringName(""):
				advance()
		_:
			advance()

func advance() -> void:
	if is_complete():
		return
	_current_index += 1
	_reset_wait_state()

func is_complete() -> bool:
	return _current_index >= _beats.size()

func get_current_beat() -> Resource:
	if is_complete():
		return null
	return _beats[_current_index] as Resource

func get_current_index() -> int:
	return _current_index

func update(delta: float) -> void:
	if is_complete():
		return
	if not _is_waiting_timed:
		return

	_timed_elapsed += max(delta, 0.0)
	if _timed_elapsed >= _timed_duration:
		advance()

func on_signal_received(event_name: StringName) -> void:
	if is_complete():
		return
	if not _is_waiting_signal:
		return
	if _to_string_name(event_name) != _waiting_signal_event:
		return

	advance()

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
