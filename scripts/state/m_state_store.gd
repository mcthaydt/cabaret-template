@icon("res://resources/editor_icons/manager.svg")

extends Node
class_name M_StateStore

## Centralized Redux-style state store for game state management.
##
## Manages state slices (boot, menu, gameplay) with immutable updates,
## action/reducer patterns, and signal-based reactivity.
##
## Usage:
##   var store := U_StateUtils.get_store(self)
##   store.dispatch(U_GameplayActions.pause_game())
##   var state: Dictionary = store.get_state()

const SignalBatcher = preload("res://scripts/state/signal_batcher.gd")
const SerializationHelper = preload("res://scripts/state/u_serialization_helper.gd")
const StateHandoff = preload("res://scripts/state/u_state_handoff.gd")
const BootReducer = preload("res://scripts/state/reducers/u_boot_reducer.gd")
const MenuReducer = preload("res://scripts/state/reducers/u_menu_reducer.gd")
const GameplayReducer = preload("res://scripts/state/reducers/u_gameplay_reducer.gd")
const SceneReducer = preload("res://scripts/state/reducers/u_scene_reducer.gd")
const RS_BootInitialState = preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState = preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_SceneInitialState = preload("res://scripts/state/resources/rs_scene_initial_state.gd")

signal state_changed(action: Dictionary, new_state: Dictionary)
signal slice_updated(slice_name: StringName, slice_state: Dictionary)
signal action_dispatched(action: Dictionary)
signal validation_failed(action: Dictionary, error: String)
signal state_loaded(filepath: String)

const PROJECT_SETTING_HISTORY_SIZE := "state/debug/history_size"
const PROJECT_SETTING_ENABLE_HISTORY := "state/debug/enable_history"
const PROJECT_SETTING_ENABLE_PERSISTENCE := "state/runtime/enable_persistence"

@export var settings: RS_StateStoreSettings
@export var boot_initial_state: RS_BootInitialState
@export var menu_initial_state: RS_MenuInitialState
@export var gameplay_initial_state: RS_GameplayInitialState
@export var scene_initial_state: RS_SceneInitialState

var _state: Dictionary = {}
var _subscribers: Array[Callable] = []
var _slice_configs: Dictionary = {}
var _signal_batcher: SignalBatcher = null
var _action_history: Array = []
var _max_history_size: int = 1000
var _enable_history: bool = true
var _debug_overlay: CanvasLayer = null

# Performance tracking (T414)
var _perf_dispatch_count: int = 0
var _perf_total_dispatch_time_us: int = 0  # microseconds
var _perf_signal_emit_count: int = 0
var _perf_last_dispatch_time_us: int = 0

func _ready() -> void:
	add_to_group("state_store")
	_initialize_settings()
	_initialize_slices()
	
	# Validate all slice dependencies after registration
	if not validate_slice_dependencies():
		push_warning("M_StateStore: Some slice dependencies are invalid")
	
	# Restore state from StateHandoff AFTER slices are initialized
	_restore_from_handoff()
	
	_signal_batcher = SignalBatcher.new()
	set_physics_process(true)  # Enable physics processing for signal batching

func _exit_tree() -> void:
	# Preserve state for scene transitions via StateHandoff
	_preserve_to_handoff()
	
	if is_in_group("state_store"):
		remove_from_group("state_store")

func _physics_process(_delta: float) -> void:
	# Flush batched signals once per physics frame
	if _signal_batcher != null:
		_signal_batcher.flush(func(slice_name: StringName, slice_state: Dictionary) -> void:
			slice_updated.emit(slice_name, slice_state)
			_perf_signal_emit_count += 1  # Track signal emissions
		)

## Handle input for debug overlay toggle (F3 key)
##
## Debug overlay spawns on F3 key press, controlled by M_StateStore._input()
## for easy access to store reference without needing global state.
func _input(event: InputEvent) -> void:
	# Check if debug overlay is enabled via project settings
	const PROJECT_SETTING_ENABLE_DEBUG_OVERLAY := "state/debug/enable_debug_overlay"
	if ProjectSettings.has_setting(PROJECT_SETTING_ENABLE_DEBUG_OVERLAY):
		if not ProjectSettings.get_setting(PROJECT_SETTING_ENABLE_DEBUG_OVERLAY, true):
			return  # Debug overlay disabled in project settings
	
	# Toggle debug overlay with F3 key
	if Input.is_action_just_pressed("toggle_debug_overlay"):
		if _debug_overlay == null or not is_instance_valid(_debug_overlay):
			# Spawn debug overlay
			var overlay_scene := load("res://scenes/debug/sc_state_debug_overlay.tscn")
			if overlay_scene:
				_debug_overlay = overlay_scene.instantiate()
				add_child(_debug_overlay)
		else:
			# Despawn debug overlay
			_debug_overlay.queue_free()
			_debug_overlay = null

func _initialize_settings() -> void:
	if settings == null:
		settings = RS_StateStoreSettings.new()

	# Load from project settings if available
	if ProjectSettings.has_setting(PROJECT_SETTING_HISTORY_SIZE):
		var history_size: int = ProjectSettings.get_setting(PROJECT_SETTING_HISTORY_SIZE, 1000)
		if settings.max_history_size != history_size:
			settings.max_history_size = history_size
	
	# Apply history settings to instance variables
	_max_history_size = settings.max_history_size
	
	# Check if history is enabled
	if ProjectSettings.has_setting(PROJECT_SETTING_ENABLE_HISTORY):
		_enable_history = ProjectSettings.get_setting(PROJECT_SETTING_ENABLE_HISTORY, true)
	else:
		_enable_history = true  # Default to enabled in debug builds

func _initialize_slices() -> void:
	# Register boot slice if initial state provided
	if boot_initial_state != null:
		var boot_config := StateSliceConfig.new(StringName("boot"))
		boot_config.reducer = Callable(BootReducer, "reduce")
		boot_config.initial_state = boot_initial_state.to_dictionary()
		boot_config.dependencies = []
		boot_config.transient_fields = []
		register_slice(boot_config)
	
	# Register menu slice if initial state provided
	if menu_initial_state != null:
		var menu_config := StateSliceConfig.new(StringName("menu"))
		menu_config.reducer = Callable(MenuReducer, "reduce")
		menu_config.initial_state = menu_initial_state.to_dictionary()
		menu_config.dependencies = []
		menu_config.transient_fields = []
		register_slice(menu_config)
	
	# Register gameplay slice if initial state provided
	if gameplay_initial_state != null:
		var gameplay_config := StateSliceConfig.new(StringName("gameplay"))
		gameplay_config.reducer = Callable(GameplayReducer, "reduce")
		gameplay_config.initial_state = gameplay_initial_state.to_dictionary()
		gameplay_config.dependencies = []
		gameplay_config.transient_fields = []
		register_slice(gameplay_config)

	# Register scene slice if initial state provided
	if scene_initial_state != null:
		var scene_config := StateSliceConfig.new(StringName("scene"))
		scene_config.reducer = Callable(SceneReducer, "reduce")
		scene_config.initial_state = scene_initial_state.to_dictionary()
		scene_config.dependencies = []
		scene_config.transient_fields = ["is_transitioning", "transition_type"]  # Don't persist transition state
		register_slice(scene_config)

## Dispatch an action to update state
func dispatch(action: Dictionary) -> void:
	# Performance tracking start
	var perf_start: int = Time.get_ticks_usec()
	
	# Validate action using ActionRegistry
	if not U_ActionRegistry.validate_action(action):
		var error_msg: String = "Action validation failed"
		if not action.has("type"):
			error_msg = "Action missing 'type' field"
		elif not U_ActionRegistry.is_registered(action.get("type")):
			error_msg = "Unregistered action type: %s" % action.get("type")
		
		validation_failed.emit(action, error_msg)
		return

	# Process action through reducers to update state
	_apply_reducers(action)

	# Record action in history AFTER reducer runs (includes state_after)
	if _enable_history:
		_record_action_in_history(action)

	# Create deep copy of action for subscribers
	var action_copy: Dictionary = action.duplicate(true)

	# Notify subscribers with new state
	for subscriber in _subscribers:
		var state_copy := _state.duplicate(true)
		subscriber.call(action_copy, state_copy)

	# Emit unbatched signal
	action_dispatched.emit(action_copy)
	
	# Performance tracking end
	var perf_end: int = Time.get_ticks_usec()
	_perf_last_dispatch_time_us = perf_end - perf_start
	_perf_total_dispatch_time_us += _perf_last_dispatch_time_us
	_perf_dispatch_count += 1

## Apply reducers to update state based on action
## State updates are IMMEDIATE (synchronous), signal emissions are batched (per-frame)
func _apply_reducers(action: Dictionary) -> void:
	for slice_name in _slice_configs:
		var config: StateSliceConfig = _slice_configs[slice_name]
		if config.reducer == Callable() or not config.reducer.is_valid():
			continue
		
		var current_slice_state: Dictionary = _state.get(slice_name, {})
		var next_slice_state: Variant = config.reducer.call(current_slice_state, action)
		
		if next_slice_state is Dictionary:
			var new_slice_state := (next_slice_state as Dictionary).duplicate(true)
			_state[slice_name] = new_slice_state
			
			# Mark slice as dirty for batched signal emission
			if _signal_batcher != null:
				_signal_batcher.mark_slice_dirty(slice_name, new_slice_state)

## Subscribe to state changes
## Returns unsubscribe callable
##
## Subscribers persist until explicitly unsubscribed. ECS systems should
## cache store reference and unsubscribe in _exit_tree() to prevent leaks.
func subscribe(callback: Callable) -> Callable:
	if callback == Callable() or not callback.is_valid():
		push_error("M_StateStore.subscribe: Invalid callback")
		return Callable()

	_subscribers.append(callback)

	# Return unsubscribe function
	var unsubscribe := func() -> void:
		_subscribers.erase(callback)

	return unsubscribe

## Unsubscribe from state changes
func unsubscribe(callback: Callable) -> void:
	_subscribers.erase(callback)

## Get current state (deep copy)
func get_state() -> Dictionary:
	return _state.duplicate(true)

## Get specific slice state (deep copy)
##
## Optional caller_slice parameter enables dependency validation:
## If provided, checks that caller_slice has declared slice_name as a dependency.
## Logs error if accessing undeclared dependency.
func get_slice(slice_name: StringName, caller_slice: StringName = StringName()) -> Dictionary:
	# Validate dependencies if caller is specified
	if caller_slice != StringName():
		var caller_config: StateSliceConfig = _slice_configs.get(caller_slice)
		if caller_config != null:
			if not caller_config.dependencies.has(slice_name) and caller_slice != slice_name:
				push_error("M_StateStore.get_slice: Slice '", caller_slice, "' accessing '", slice_name, "' without declaring dependency")
	
	return _state.get(slice_name, {}).duplicate(true)

## Register a state slice with its configuration
##
## Slices register via M_StateStore._ready() using @export resources.
## Each slice needs:
##   - RS_*InitialState resource (e.g., RS_GameplayInitialState)
##   - *_reducer.gd static class (e.g., GameplayReducer)
##   - StateSliceConfig in register_slice() call
##
## Example registration pattern:
##   var gameplay_config := StateSliceConfig.new(StringName("gameplay"))
##   gameplay_config.reducer = Callable(GameplayReducer, "reduce")
##   gameplay_config.initial_state = gameplay_initial_state.to_dictionary()
##   gameplay_config.dependencies = []  # Other slices this slice depends on
##   register_slice(gameplay_config)
func register_slice(config: StateSliceConfig) -> void:
	if config == null:
		push_error("M_StateStore.register_slice: Config is null")
		return

	if config.slice_name == StringName():
		push_error("M_StateStore.register_slice: Slice name is empty")
		return

	# Validate circular dependencies
	if _has_circular_dependency(config.slice_name, config.dependencies):
		push_error("M_StateStore.register_slice: Circular dependency detected for slice '", config.slice_name, "'")
		return

	_slice_configs[config.slice_name] = config
	_state[config.slice_name] = config.initial_state.duplicate(true)

## Validate that all declared slice dependencies exist and are valid
##
## Returns true if all dependencies are valid, false otherwise.
## Checks that:
## - All declared dependencies point to registered slices
## - No circular dependencies exist (already checked at registration)
func validate_slice_dependencies() -> bool:
	var all_valid := true
	
	for slice_name in _slice_configs:
		var config: StateSliceConfig = _slice_configs[slice_name]
		
		for dep in config.dependencies:
			if not _slice_configs.has(dep):
				push_error("M_StateStore: Slice '", slice_name, "' declares dependency on unregistered slice '", dep, "'")
				all_valid = false
	
	return all_valid

## Check for circular dependencies using depth-first search
func _has_circular_dependency(slice_name: StringName, dependencies: Array[StringName], visited: Dictionary = {}, rec_stack: Dictionary = {}) -> bool:
	visited[slice_name] = true
	rec_stack[slice_name] = true

	for dep in dependencies:
		if not visited.get(dep, false):
			var dep_config: StateSliceConfig = _slice_configs.get(dep)
			if dep_config != null:
				if _has_circular_dependency(dep, dep_config.dependencies, visited, rec_stack):
					return true
		elif rec_stack.get(dep, false):
			# Found a back edge, circular dependency detected
			return true

	rec_stack[slice_name] = false
	return false

## Record action in history with timestamp and state snapshot
func _record_action_in_history(action: Dictionary) -> void:
	var timestamp: float = U_ECSUtils.get_current_time()
	var state_snapshot: Dictionary = _state.duplicate(true)
	
	var history_entry: Dictionary = {
		"action": action.duplicate(true),
		"timestamp": timestamp,
		"state_after": state_snapshot
	}
	
	_action_history.append(history_entry)
	
	# Prune oldest entries if exceeding max size (circular buffer)
	while _action_history.size() > _max_history_size:
		_action_history.remove_at(0)

## Get complete action history (deep copy)
##
## Returns array of history entries with format:
##   {action: Dictionary, timestamp: float, state_after: Dictionary}
##
## History is limited to max_history_size entries (circular buffer).
func get_action_history() -> Array:
	return _action_history.duplicate(true)

## Get last N actions from history (deep copy)
##
## Returns the most recent N action history entries.
## If N exceeds history size, returns all available entries.
func get_last_n_actions(n: int) -> Array:
	if n <= 0:
		return []
	
	var history_size: int = _action_history.size()
	if n >= history_size:
		return _action_history.duplicate(true)
	
	# Get last n entries
	var start_index: int = history_size - n
	var result: Array = []
	for i in range(start_index, history_size):
		result.append(_action_history[i].duplicate(true))
	
	return result

## Save current state to JSON file
##
## Excludes transient fields as defined in slice configs.
## Returns OK on success, or an Error code on failure.
func save_state(filepath: String) -> Error:
	if filepath.is_empty():
		push_error("M_StateStore.save_state: Empty filepath")
		return ERR_INVALID_PARAMETER
	
	# Build state to save, excluding transient fields
	var state_to_save: Dictionary = {}
	
	for slice_name in _state:
		var slice_state: Dictionary = _state[slice_name]
		var config: StateSliceConfig = _slice_configs.get(slice_name)
		
		# Copy slice state, excluding transient fields
		var filtered_state: Dictionary = {}
		for key in slice_state:
			var is_transient: bool = false
			if config != null:
				is_transient = config.transient_fields.has(key)
			
			if not is_transient:
				filtered_state[key] = slice_state[key]
		
		# Apply serialization to convert Godot types
		state_to_save[slice_name] = SerializationHelper.godot_to_json(filtered_state)
	
	# Convert to JSON string
	var json_string: String = JSON.stringify(state_to_save, "\t")
	
	# Write to file
	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		var error: Error = FileAccess.get_open_error()
		push_error("M_StateStore.save_state: Failed to open file for writing: ", error)
		return error
	
	file.store_string(json_string)
	file.close()
	
	if OS.is_debug_build() and settings.enable_debug_logging:
		print("[STATE] Saved state to: ", filepath)
	
	return OK

## Load state from JSON file
##
## Merges loaded state with current state, preserving transient fields.
## Returns OK on success, or an Error code on failure.
func load_state(filepath: String) -> Error:
	if filepath.is_empty():
		push_error("M_StateStore.load_state: Empty filepath")
		return ERR_INVALID_PARAMETER
	
	# Check if file exists
	if not FileAccess.file_exists(filepath):
		push_error("M_StateStore.load_state: File does not exist: ", filepath)
		return ERR_FILE_NOT_FOUND
	
	# Read file
	var file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		var error: Error = FileAccess.get_open_error()
		push_error("M_StateStore.load_state: Failed to open file for reading: ", error)
		return error
	
	var json_string: String = file.get_as_text()
	file.close()
	
	# Parse JSON
	var parsed: Variant = JSON.parse_string(json_string)
	if parsed == null or not parsed is Dictionary:
		push_error("M_StateStore.load_state: Invalid JSON in file")
		return ERR_PARSE_ERROR
	
	var loaded_state: Dictionary = parsed as Dictionary
	
	# Apply deserialization to convert back to Godot types
	var deserialized_state: Dictionary = SerializationHelper.json_to_godot(loaded_state)
	
	# Merge loaded state with current state
	for slice_name in deserialized_state:
		if _state.has(slice_name):
			var loaded_slice: Dictionary = deserialized_state[slice_name]
			var current_slice: Dictionary = _state[slice_name]
			var config: StateSliceConfig = _slice_configs.get(slice_name)
			
			# Preserve transient fields from current state
			if config != null:
				for transient_field in config.transient_fields:
					if current_slice.has(transient_field) and not loaded_slice.has(transient_field):
						loaded_slice[transient_field] = current_slice[transient_field]
			
			# Replace slice with loaded state (merged with transient fields)
			_state[slice_name] = loaded_slice.duplicate(true)
	
	if OS.is_debug_build() and settings.enable_debug_logging:
		print("[STATE] Loaded state from: ", filepath)
	
	state_loaded.emit(filepath)
	
	return OK

## Preserve state to StateHandoff for scene transitions
func _preserve_to_handoff() -> void:
	for slice_name in _state:
		var slice_state: Dictionary = _state[slice_name]
		StateHandoff.preserve_slice(slice_name, slice_state)
	
	if OS.is_debug_build() and settings.enable_debug_logging:
		print("[STATE] Preserved state to StateHandoff for scene transition")

## Restore state from StateHandoff after scene transitions
func _restore_from_handoff() -> void:
	for slice_name in _slice_configs:
		var restored_state: Dictionary = StateHandoff.restore_slice(slice_name)
		
		if not restored_state.is_empty():
			# Merge restored state with current state (restored takes precedence)
			if _state.has(slice_name):
				var current_state: Dictionary = _state[slice_name]
				for key in restored_state:
					current_state[key] = restored_state[key]
				_state[slice_name] = current_state
			else:
				_state[slice_name] = restored_state.duplicate(true)
			
			if OS.is_debug_build() and settings.enable_debug_logging:
				print("[STATE] Restored slice '", slice_name, "' from StateHandoff")
			
			# Clear the handoff state after restoring
			StateHandoff.clear_slice(slice_name)

## Get performance metrics (T414)
##
## Returns dictionary with:
##   - dispatch_count: Total number of actions dispatched
##   - avg_dispatch_time_ms: Average dispatch time in milliseconds
##   - last_dispatch_time_ms: Last dispatch time in milliseconds
##   - signal_emit_count: Total number of signals emitted
func get_performance_metrics() -> Dictionary:
	var avg_time_ms: float = 0.0
	if _perf_dispatch_count > 0:
		avg_time_ms = (_perf_total_dispatch_time_us / _perf_dispatch_count) / 1000.0
	
	var last_time_ms: float = _perf_last_dispatch_time_us / 1000.0
	
	return {
		"dispatch_count": _perf_dispatch_count,
		"avg_dispatch_time_ms": avg_time_ms,
		"last_dispatch_time_ms": last_time_ms,
		"signal_emit_count": _perf_signal_emit_count
	}

## Reset performance metrics (useful for profiling specific sections)
func reset_performance_metrics() -> void:
	_perf_dispatch_count = 0
	_perf_total_dispatch_time_us = 0
	_perf_signal_emit_count = 0
	_perf_last_dispatch_time_us = 0
