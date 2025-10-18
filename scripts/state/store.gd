extends Node
class_name StateStore

signal state_changed(state: Dictionary)
signal action_dispatched(action: Dictionary)

const SELECTOR := preload("res://scripts/state/selector.gd")

var _state: Dictionary = {}
var _reducers: Dictionary = {}
var _state_version: int = 0
var _time_travel_enabled: bool = false
var _history: Array = []
var _history_index: int = -1
var _max_history_size: int = 1000
var _persistable_slices: Array[StringName] = []

func _ready() -> void:
	var existing: Array = get_tree().get_nodes_in_group("state_store")
	if existing.size() > 0:
		push_error("FATAL: Multiple StateStore instances detected. Only one allowed per scene tree.")
		queue_free()
		return
	add_to_group("state_store")

func register_reducer(reducer_class) -> void:
	assert(reducer_class != null, "Reducer class must not be null")
	var slice_name: StringName = reducer_class.get_slice_name()
	assert(!_reducers.has(slice_name), "Reducer for slice %s already registered" % [slice_name])

	_reducers[slice_name] = reducer_class

	var initial_state: Dictionary = reducer_class.get_initial_state()
	_state[slice_name] = initial_state.duplicate(true)

	if reducer_class.get_persistable():
		_persistable_slices.append(slice_name)

func dispatch(action: Dictionary) -> void:
	assert(action.has("type"), "Action requires a type field")
	var new_state: Dictionary = _state.duplicate(true)

	for slice_name in _reducers.keys():
		var reducer: Variant = _reducers[slice_name]
		var previous_slice: Variant = _state.get(slice_name, {})
		var updated_slice: Variant = reducer.reduce(previous_slice, action)
		new_state[slice_name] = updated_slice

	if _time_travel_enabled:
		_record_history(action, new_state)

	_state = new_state
	_state_version += 1

	action_dispatched.emit(action)
	state_changed.emit(_state)

func subscribe(callback: Callable) -> Callable:
	var err := state_changed.connect(callback)
	assert(err == OK, "Failed to connect subscriber")
	return func() -> void:
		if state_changed.is_connected(callback):
			state_changed.disconnect(callback)

func get_state() -> Dictionary:
	return _state.duplicate(true)

func select(target) -> Variant:
	if typeof(target) == TYPE_STRING or typeof(target) == TYPE_STRING_NAME:
		return _select_path(String(target))
	if typeof(target) == TYPE_OBJECT and target.has_method("select"):
		var resolver := func(path: String) -> Variant:
			return _select_path_from_state(_state, path)
		return target.select(_state, _state_version, resolver)
	assert(false, "Unsupported selector type %s" % [typeof(target)])
	return null

func enable_time_travel(enabled: bool, max_history_size: int = 1000) -> void:
	_time_travel_enabled = enabled
	_max_history_size = max_history_size
	if not enabled:
		_history.clear()
		_history_index = -1
	else:
		_history.clear()
		_history_index = -1

func _select_path(path: String) -> Variant:
	return _select_path_from_state(_state, path)

func _select_path_from_state(source_state: Dictionary, path: String) -> Variant:
	var segments := path.split(".")
	var current: Variant = source_state
	for segment in segments:
		if current is Dictionary and (current as Dictionary).has(segment):
			current = (current as Dictionary)[segment]
		else:
			return null
	return current

func _record_history(action: Dictionary, new_state: Dictionary) -> void:
	if _history_index >= 0 and _history_index < _history.size() - 1:
		_history = _history.slice(0, _history_index + 1)
	_history.append({
		"action": action.duplicate(true),
		"state": new_state.duplicate(true),
	})
	if _history.size() > _max_history_size:
		_history.pop_front()
	_history_index = _history.size() - 1
