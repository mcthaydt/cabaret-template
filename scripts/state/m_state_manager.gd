@icon("res://editor_icons/manager.svg")
extends Node
class_name M_StateManager

signal state_changed(state: Dictionary)
signal action_dispatched(action: Dictionary)

const SELECTOR := preload("res://scripts/state/u_selector_utils.gd")
const PERSISTENCE := preload("res://scripts/state/u_state_persistence.gd")
const CONSTANTS := preload("res://scripts/state/state_constants.gd")
const STATE_UTILS := preload("res://scripts/state/u_state_utils.gd")

var _state: Dictionary = {}
var _reducers: Dictionary = {}
var _state_version: int = 0
var _time_travel_enabled: bool = false
var _history: Array = []
var _history_index: int = -1
var _max_history_size: int = 1000
var _persistable_slices: Array[StringName] = []

func _ready() -> void:
	var existing: Array = get_tree().get_nodes_in_group(CONSTANTS.STATE_STORE_GROUP)
	if existing.size() > 0:
		push_error("FATAL: Multiple M_StateManager instances detected. Only one allowed per scene tree.")
		queue_free()
		return
	add_to_group(CONSTANTS.STATE_STORE_GROUP)

	# Initialize any missing reducer slices using an @@INIT action
	var changed: bool = false
	for slice_name in _reducers.keys():
		if !_state.has(slice_name):
			var reducer: Variant = _reducers[slice_name]
			var init_result: Variant = reducer.reduce({}, {"type": CONSTANTS.INIT_ACTION})
			_state[slice_name] = STATE_UTILS.safe_duplicate(init_result)
			changed = true

	if changed:
		_state_version += 1
		state_changed.emit(_state)

func register_reducer(reducer_class) -> void:
	assert(reducer_class != null, "Reducer class must not be null")
	var slice_name: StringName = reducer_class.get_slice_name()
	assert(!_reducers.has(slice_name), "Reducer for slice %s already registered" % [slice_name])

	_reducers[slice_name] = reducer_class

	var initial_state: Dictionary = reducer_class.get_initial_state()
	_state[slice_name] = STATE_UTILS.safe_duplicate(initial_state)

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

func save_state(path: String, whitelist: Array[StringName] = []) -> Error:
	var slices_to_save: Array[StringName] = whitelist
	if slices_to_save.is_empty():
		slices_to_save = _persistable_slices
	return PERSISTENCE.save_to_file(path, _state, slices_to_save)

func load_state(path: String) -> Error:
	var loaded: Dictionary = PERSISTENCE.load_from_file(path)
	if loaded.is_empty():
		return ERR_FILE_CANT_READ

	var next_state: Dictionary = _state.duplicate(true)
	var changed: bool = false
	for slice_name in loaded.keys():
		if !_state.has(slice_name):
			continue
		var slice_value: Variant = loaded[slice_name]
		next_state[slice_name] = STATE_UTILS.safe_duplicate(slice_value)
		changed = true

	if not changed:
		return ERR_FILE_CANT_READ

	_state = next_state
	_state_version += 1
	state_changed.emit(_state)
	return OK

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
	# Always clear history when toggling time travel state
	_history.clear()
	_history_index = -1

	_time_travel_enabled = enabled
	_max_history_size = max_history_size

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
		"action": STATE_UTILS.safe_duplicate(action),
		"state": STATE_UTILS.safe_duplicate(new_state),
	})
	if _history.size() > _max_history_size:
		_history.pop_front()
	_history_index = _history.size() - 1

func get_history() -> Array:
	var results: Array = []
	for entry in _history:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var action_variant: Variant = entry.get("action", {})
		var state_variant: Variant = entry.get("state", {})
		results.append({
			"action": STATE_UTILS.safe_duplicate(action_variant),
			"state": STATE_UTILS.safe_duplicate(state_variant),
		})
	return results

func step_backward() -> void:
	if not _time_travel_enabled:
		return
	if _history.is_empty():
		return
	if _history_index <= 0:
		return
	_history_index -= 1
	_restore_state_from_history(_history_index)

func step_forward() -> void:
	if not _time_travel_enabled:
		return
	if _history.is_empty():
		return
	if _history_index < 0:
		return
	if _history_index >= _history.size() - 1:
		return
	_history_index += 1
	_restore_state_from_history(_history_index)

func jump_to_action(index: int) -> void:
	if not _time_travel_enabled:
		return
	if _history.is_empty():
		return
	if index < 0 or index >= _history.size():
		return
	if index == _history_index:
		return
	_history_index = index
	_restore_state_from_history(_history_index)

func export_history(path: String) -> Error:
	var serializable: Array = []
	for entry in _history:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var action_variant: Variant = entry.get("action", {})
		var state_variant: Variant = entry.get("state", {})
		var serialized_action: Dictionary = {}
		if typeof(action_variant) == TYPE_DICTIONARY:
			var type_value: String = str(action_variant.get("type", ""))
			if type_value != "":
				serialized_action["type"] = type_value
			if action_variant.has("payload"):
				serialized_action["payload"] = STATE_UTILS.safe_duplicate(action_variant["payload"])
			else:
				serialized_action["payload"] = null
		var serialized_state: Variant = STATE_UTILS.safe_duplicate(state_variant)
		serializable.append({
			"action": serialized_action,
			"state": serialized_state,
		})

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(serializable))
	file.close()
	return OK

func import_history(path: String) -> Error:
	if !FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var contents: String = file.get_as_text()
	file.close()

	var parsed_variant: Variant = JSON.parse_string(contents)
	if typeof(parsed_variant) != TYPE_ARRAY:
		push_error("Time Travel: History file must contain an Array.")
		return ERR_PARSE_ERROR

	var entries: Array = parsed_variant
	var normalized_actions: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var action_variant: Variant = entry.get("action")
		if typeof(action_variant) != TYPE_DICTIONARY:
			continue
		if !action_variant.has("type"):
			continue
		var action_type_str: String = str(action_variant.get("type", ""))
		if action_type_str.is_empty():
			continue
		var normalized_action: Dictionary = {
			"type": StringName(action_type_str),
			"payload": null,
		}
		if action_variant.has("payload"):
			normalized_action["payload"] = STATE_UTILS.safe_duplicate(action_variant["payload"])
		normalized_actions.append(normalized_action)

	var previous_max: int = _max_history_size
	enable_time_travel(false)
	_reset_state_to_initial()
	enable_time_travel(true, previous_max)

	for action in normalized_actions:
		dispatch(action)

	return OK

func _restore_state_from_history(index: int) -> void:
	if index < 0 or index >= _history.size():
		return
	var entry: Variant = _history[index]
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var state_variant: Variant = entry.get("state", {})
	if typeof(state_variant) != TYPE_DICTIONARY:
		return
	_apply_restored_state(state_variant)

func _apply_restored_state(target_state: Dictionary) -> void:
	_state = STATE_UTILS.safe_duplicate(target_state)
	_state_version += 1
	state_changed.emit(_state)

func _reset_state_to_initial() -> void:
	var initial_state: Dictionary = {}
	for slice_name in _reducers.keys():
		var reducer: Variant = _reducers[slice_name]
		var initial_variant: Variant = {}
		if reducer.has_method("get_initial_state"):
			initial_variant = reducer.get_initial_state()
		if typeof(initial_variant) == TYPE_DICTIONARY:
			initial_state[slice_name] = STATE_UTILS.safe_duplicate(initial_variant)
		else:
			initial_state[slice_name] = {}
	_state = initial_state
	_state_version += 1
	state_changed.emit(_state)
