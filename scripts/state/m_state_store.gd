@icon("res://assets/editor_icons/manager.svg")

extends I_StateStore
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

const U_SIGNAL_BATCHER := preload("res://scripts/state/utils/u_signal_batcher.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_STATE_SLICE_MANAGER := preload("res://scripts/state/utils/u_state_slice_manager.gd")
const U_STATE_REPOSITORY := preload("res://scripts/state/utils/u_state_repository.gd")
const U_STATE_VALIDATOR := preload("res://scripts/state/utils/u_state_validator.gd")
const U_ACTION_HISTORY_BUFFER := preload("res://scripts/state/utils/u_action_history_buffer.gd")
const U_STORE_PERFORMANCE_METRICS := preload("res://scripts/state/utils/u_store_performance_metrics.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_BOOT_REDUCER := preload("res://scripts/state/reducers/u_boot_reducer.gd")
const U_MENU_REDUCER := preload("res://scripts/state/reducers/u_menu_reducer.gd")
const U_GAMEPLAY_REDUCER := preload("res://scripts/state/reducers/u_gameplay_reducer.gd")
const U_NAVIGATION_REDUCER := preload("res://scripts/state/reducers/u_navigation_reducer.gd")
const U_SCENE_REDUCER := preload("res://scripts/state/reducers/u_scene_reducer.gd")
const U_SETTINGS_REDUCER := preload("res://scripts/state/reducers/u_settings_reducer.gd")
const U_DEBUG_REDUCER := preload("res://scripts/state/reducers/u_debug_reducer.gd")
const U_VFX_REDUCER := preload("res://scripts/state/reducers/u_vfx_reducer.gd")
const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")
const U_INPUT_CAPTURE_GUARD := preload("res://scripts/utils/u_input_capture_guard.gd")
const RS_BOOT_INITIAL_STATE := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MENU_INITIAL_STATE := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_SETTINGS_INITIAL_STATE := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_DEBUG_INITIAL_STATE := preload("res://scripts/resources/state/rs_debug_initial_state.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/resources/state/rs_audio_initial_state.gd")

signal state_changed(action: Dictionary, new_state: Dictionary)
signal slice_updated(slice_name: StringName, slice_state: Dictionary)
signal action_dispatched(action: Dictionary)
signal validation_failed(action: Dictionary, error: String)
signal state_loaded(filepath: String)
signal store_ready()

const ACTION_FLAG_IMMEDIATE := "immediate"

const PROJECT_SETTING_HISTORY_SIZE := "state/debug/history_size"
const PROJECT_SETTING_ENABLE_HISTORY := "state/debug/enable_history"
const PROJECT_SETTING_ENABLE_PERSISTENCE := "state/runtime/enable_persistence"

@export var settings: RS_StateStoreSettings
@export var boot_initial_state: RS_BootInitialState
@export var menu_initial_state: RS_MenuInitialState
@export var navigation_initial_state: Resource
@export var gameplay_initial_state: RS_GameplayInitialState
@export var scene_initial_state: RS_SceneInitialState
@export var settings_initial_state: RS_SettingsInitialState
@export var debug_initial_state: RS_DebugInitialState
@export var vfx_initial_state: RS_VFXInitialState
@export var audio_initial_state: RS_AudioInitialState

var _state: Dictionary = {}
var _subscribers: Array[Callable] = []
var _slice_configs: Dictionary = {}
var _signal_batcher: U_SignalBatcher = null
var _pending_immediate_updates: Dictionary = {}
var _action_history_buffer := U_ACTION_HISTORY_BUFFER.new()
var _debug_overlay: CanvasLayer = null
var _is_ready: bool = false
var _performance_metrics := U_STORE_PERFORMANCE_METRICS.new()

func _ready() -> void:
	# Store must continue flushing batched slice_updated signals while paused so
	# pause menus and overlay reconciliation remain responsive.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var service_name := StringName("state_store")
	if not U_SERVICE_LOCATOR.has(service_name):
		U_SERVICE_LOCATOR.register(service_name, self)
	_initialize_settings()
	_initialize_slices()
		
	# Validate all slice dependencies after registration
	if not validate_slice_dependencies():
		push_warning("M_StateStore: Some slice dependencies are invalid")
	
	# Restore state from StateHandoff AFTER slices are initialized
	_restore_from_handoff()

	# Auto-load persisted state if enabled and file exists
	_try_autoload_state()
	
	_signal_batcher = U_SIGNAL_BATCHER.new()
	set_physics_process(true)  # Enable physics processing for signal batching
	# Ensure batching and input work even when the SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_is_ready = true
	store_ready.emit()

func _exit_tree() -> void:
	# Preserve state for scene transitions via StateHandoff
	_preserve_to_handoff()

	# Save state to disk on shutdown if persistence enabled
	_save_state_if_enabled()

func is_ready() -> bool:
	return _is_ready

func _save_state_if_enabled() -> void:
	var enable_logging := settings != null and settings.enable_debug_logging
	U_STATE_REPOSITORY.save_state_if_enabled(settings, _state, _slice_configs, enable_logging)

func _try_autoload_state() -> void:
	var enable_logging := settings != null and settings.enable_debug_logging
	U_STATE_REPOSITORY.try_autoload_state(settings, _state, _slice_configs, enable_logging)

func _physics_process(_delta: float) -> void:
	# Flush batched signals once per physics frame
	_flush_signal_batcher()

func _process(_delta: float) -> void:
	# Do not flush on idle; tests expect a single batched emission per frame.
	# Physics flush handles batching even when tree is paused (PROCESS_MODE_ALWAYS).
	pass

func _on_debug_overlay_tree_exiting() -> void:
	_debug_overlay = null

func _flush_signal_batcher() -> int:
	if _signal_batcher == null:
		return 0
	var pending_count := _signal_batcher.get_pending_count()
	if pending_count == 0:
		return 0
	_signal_batcher.flush(func(slice_name: StringName, slice_state: Dictionary) -> void:
		slice_updated.emit(slice_name, slice_state)
		_performance_metrics.record_signal_emitted()
	)
	return pending_count

## Handle input for debug overlay toggle via action
##
## Debug overlay spawns when the `toggle_debug_overlay` action is pressed.
## Supports both action events (InputEventAction) and Input singleton state.
func _input(event: InputEvent) -> void:
	# Check if debug overlay is enabled via project settings
	const PROJECT_SETTING_ENABLE_DEBUG_OVERLAY := "state/debug/enable_debug_overlay"
	if ProjectSettings.has_setting(PROJECT_SETTING_ENABLE_DEBUG_OVERLAY):
		if not ProjectSettings.get_setting(PROJECT_SETTING_ENABLE_DEBUG_OVERLAY, true):
			return  # Debug overlay disabled in project settings
	
	if U_INPUT_CAPTURE_GUARD.is_capture_active():
		return  # Suppress overlay toggle while input capture is active.
	
	# Toggle debug overlay with action (prefer explicit InputEventAction, fallback to Input state)
	var toggle_pressed: bool = false
	if event is InputEventAction:
		var aev := event as InputEventAction
		toggle_pressed = aev.action == "toggle_debug_overlay" and aev.pressed
	else:
		# Fallback to Input singleton so hardware mapping still works
		toggle_pressed = Input.is_action_just_pressed("toggle_debug_overlay")

	# Act on toggle
	if toggle_pressed:
		if _debug_overlay == null or not is_instance_valid(_debug_overlay):
			# Spawn debug overlay
			var overlay_scene := load("res://scenes/debug/debug_state_overlay.tscn")
			if overlay_scene:
				_debug_overlay = overlay_scene.instantiate()
				add_child(_debug_overlay)
				register_debug_overlay(_debug_overlay)
		else:
			# Despawn debug overlay
			_debug_overlay.queue_free()
			register_debug_overlay(null)

func register_debug_overlay(overlay: CanvasLayer) -> void:
	if overlay != null and is_instance_valid(overlay):
		_debug_overlay = overlay
		if not overlay.tree_exiting.is_connected(_on_debug_overlay_tree_exiting):
			overlay.tree_exiting.connect(_on_debug_overlay_tree_exiting, CONNECT_ONE_SHOT)
		return
	_debug_overlay = null

func get_debug_overlay() -> CanvasLayer:
	if _debug_overlay != null and is_instance_valid(_debug_overlay):
		return _debug_overlay
	return null

func _initialize_settings() -> void:
	if settings == null:
		settings = RS_StateStoreSettings.new()

	# Load from project settings if available
	if ProjectSettings.has_setting(PROJECT_SETTING_HISTORY_SIZE):
		var history_size: int = ProjectSettings.get_setting(PROJECT_SETTING_HISTORY_SIZE, 1000)
		if settings.max_history_size != history_size:
			settings.max_history_size = history_size
	
	# Check if history is enabled
	var enable_history: bool = true
	if ProjectSettings.has_setting(PROJECT_SETTING_ENABLE_HISTORY):
		enable_history = ProjectSettings.get_setting(PROJECT_SETTING_ENABLE_HISTORY, true)
	else:
		enable_history = true  # Default to enabled in debug builds

	_action_history_buffer.configure(settings.max_history_size, enable_history)

func _initialize_slices() -> void:
	U_STATE_SLICE_MANAGER.initialize_slices(
		_slice_configs,
		_state,
		boot_initial_state,
		menu_initial_state,
		navigation_initial_state,
		settings_initial_state,
		gameplay_initial_state,
		scene_initial_state,
		debug_initial_state,
		vfx_initial_state,
		audio_initial_state
	)

## Normalize a deserialized state dictionary for tests.
##
## This is a thin wrapper around U_StateValidator.normalize_loaded_state()
## so tests can exercise normalization logic without reaching into the validator
## directly. Production code should continue to use U_StateRepository for
## save/load flows.
func _normalize_loaded_state(state: Dictionary) -> void:
	U_STATE_VALIDATOR.normalize_loaded_state(state)

## Normalize a single spawn reference for tests.
##
## Delegates to U_StateValidator.normalize_spawn_reference() so tests can
## validate spawn normalization behavior via the store instance.
func _normalize_spawn_reference(
	value: Variant,
	allow_empty: bool,
	emit_warning: bool = true
) -> StringName:
	return U_STATE_VALIDATOR.normalize_spawn_reference(value, allow_empty, emit_warning)

## Dispatch an action to update state
func dispatch(action: Dictionary) -> void:
	# Performance tracking start
	var perf_start: int = _performance_metrics.start_dispatch()
	var is_immediate: bool = bool(action.get(ACTION_FLAG_IMMEDIATE, false))
	if _signal_batcher == null:
		_signal_batcher = U_SIGNAL_BATCHER.new()
	_pending_immediate_updates.clear()
	
	# Validate action using ActionRegistry
	if not U_ActionRegistry.validate_action(action):
		var error_msg: String = "Action validation failed"
		if not action.has("type"):
			error_msg = "Action missing 'type' field"
		elif not U_ActionRegistry.is_registered(action.get("type")):
			error_msg = "Unregistered action type: %s" % action.get("type")
		
		validation_failed.emit(action, error_msg)
		return

	# Process action through reducers to update state and detect changes
	var any_changed: bool = U_STATE_SLICE_MANAGER.apply_reducers(
		_state,
		_slice_configs,
		action,
		_signal_batcher,
		_pending_immediate_updates
	)

	# Record action in history AFTER reducer runs (includes state_after)
	_action_history_buffer.record_action(action, _state)

	# Create deep copy of action for subscribers
	var action_copy: Dictionary = action.duplicate(true)

	# Notify subscribers with new state
	for subscriber in _subscribers:
		var state_copy := _state.duplicate(true)
		subscriber.call(action_copy, state_copy)

	# Emit unbatched signal
	action_dispatched.emit(action_copy)
	
	# Flush batched slice updates immediately when requested.
	if is_immediate:
		var emitted_count := _flush_signal_batcher()
		if emitted_count == 0 and not _pending_immediate_updates.is_empty():
			for slice_name in _pending_immediate_updates.keys():
				var snapshot_variant: Variant = _pending_immediate_updates[slice_name]
				if snapshot_variant is Dictionary:
					var snapshot_dict := (snapshot_variant as Dictionary).duplicate(true)
					slice_updated.emit(slice_name, snapshot_dict)
					_performance_metrics.record_signal_emitted()
	_pending_immediate_updates.clear()
	
	# Performance tracking end
	_performance_metrics.finish_dispatch(perf_start)

## Apply reducers to update state based on action
## Kept for backward compatibility; now delegates to U_StateSliceManager.
func _apply_reducers(action: Dictionary) -> bool:
	return U_STATE_SLICE_MANAGER.apply_reducers(
		_state,
		_slice_configs,
		action,
		_signal_batcher,
		_pending_immediate_updates
	)

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

## Get state with transient fields filtered out
##
## Returns a deep copy of state suitable for persistence, with:
## - Transient slices removed (where config.is_transient == true)
## - Transient fields removed (as defined in slice configs)
## - Gameplay slice fully preserved (includes input fields)
##
## Used by M_SaveManager to prepare state for saving.
func get_persistable_state() -> Dictionary:
	const U_STATE_PERSISTENCE := preload("res://scripts/state/utils/u_state_persistence.gd")
	return U_STATE_PERSISTENCE.filter_transient_fields(_state, _slice_configs)

## Get slice configs for advanced state manipulation
##
## Returns a reference to the internal slice configs dictionary.
## Used by save/load systems that need direct access to transient field definitions.
##
## WARNING: This is a reference, not a copy. Do not modify.
func get_slice_configs() -> Dictionary:
	return _slice_configs

## Get specific slice state (deep copy)
##
## Optional caller_slice parameter enables dependency validation:
## If provided, checks that caller_slice has declared slice_name as a dependency.
## Logs error if accessing undeclared dependency.
func get_slice(slice_name: StringName, caller_slice: StringName = StringName()) -> Dictionary:
	# Validate dependencies if caller is specified
	if caller_slice != StringName():
		var caller_config: RS_StateSliceConfig = _slice_configs.get(caller_slice)
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
##   - RS_StateSliceConfig in register_slice() call
##
## Example registration pattern:
##   var gameplay_config := RS_StateSliceConfig.new(StringName("gameplay"))
##   gameplay_config.reducer = Callable(GameplayReducer, "reduce")
##   gameplay_config.initial_state = gameplay_initial_state.to_dictionary()
##   gameplay_config.dependencies = []  # Other slices this slice depends on
##   register_slice(gameplay_config)
func register_slice(config: RS_StateSliceConfig) -> void:
	U_STATE_SLICE_MANAGER.register_slice(_slice_configs, _state, config)

func validate_slice_dependencies() -> bool:
	return U_STATE_SLICE_MANAGER.validate_slice_dependencies(_slice_configs)

## Record action in history with timestamp and state snapshot
## Get complete action history (deep copy)
##
## Returns array of history entries with format:
##   {action: Dictionary, timestamp: float, state_after: Dictionary}
##
## History is limited to max_history_size entries (circular buffer).
func get_action_history() -> Array:
	return _action_history_buffer.get_action_history()

## Get last N actions from history (deep copy)
##
## Returns the most recent N action history entries.
## If N exceeds history size, returns all available entries.
func get_last_n_actions(n: int) -> Array:
	return _action_history_buffer.get_last_n_actions(n)

## Save current state to JSON file
##
## Excludes transient fields as defined in slice configs.
## Returns OK on success, or an Error code on failure.
func save_state(filepath: String) -> Error:
	return U_STATE_REPOSITORY.save_state(filepath, _state, _slice_configs)

## Load state from JSON file
##
## Merges loaded state with current state, preserving transient fields.
## Returns OK on success, or an Error code on failure.
func load_state(filepath: String) -> Error:
	var err: Error = U_STATE_REPOSITORY.load_state(filepath, _state, _slice_configs)
	if err == OK:
		state_loaded.emit(filepath)
	return err

## Apply loaded state directly from a dictionary
##
## Used by M_SaveManager to apply save file state without going through file I/O.
## Merges loaded state with current state (loaded takes precedence).
## Respects transient slice and field configurations.
## Emits slice_updated for each modified slice.
func apply_loaded_state(loaded_state: Dictionary) -> void:
	for slice_name in loaded_state:
		var config: RS_StateSliceConfig = _slice_configs.get(slice_name)

		# Skip transient slices
		if config != null and config.is_transient:
			continue

		var loaded_slice: Dictionary = loaded_state[slice_name]
		if not loaded_slice is Dictionary:
			continue

		# Filter out transient fields from loaded data
		var filtered_slice := loaded_slice.duplicate(true)
		if config != null:
			for transient_field in config.transient_fields:
				if filtered_slice.has(transient_field):
					filtered_slice.erase(transient_field)

		# Merge with current state (loaded takes precedence)
		if _state.has(slice_name):
			var current_slice: Dictionary = _state[slice_name]
			for key in filtered_slice:
				current_slice[key] = filtered_slice[key]
			_state[slice_name] = current_slice
		else:
			_state[slice_name] = filtered_slice

		# Emit slice_updated signal
		slice_updated.emit(slice_name, _state[slice_name])

## Preserve state to StateHandoff for scene transitions
func _preserve_to_handoff() -> void:
	for slice_name in _state:
		var slice_state: Dictionary = _state[slice_name]
		var preserved := slice_state.duplicate(true)
		var config: RS_StateSliceConfig = _slice_configs.get(slice_name)
		if config != null and config.is_transient:
			continue
		if config != null:
			for transient_field in config.transient_fields:
				if preserved.has(transient_field):
					preserved.erase(transient_field)
		U_STATE_HANDOFF.preserve_slice(slice_name, preserved)
	
## Restore state from StateHandoff after scene transitions
func _restore_from_handoff() -> void:
	for slice_name in _slice_configs:
		var config: RS_StateSliceConfig = _slice_configs.get(slice_name)
		if config != null and config.is_transient:
			continue
		var restored_state: Dictionary = U_STATE_HANDOFF.restore_slice(slice_name)
		
		if not restored_state.is_empty():
			# Merge restored state with current state (restored takes precedence)
			if _state.has(slice_name):
				var current_state: Dictionary = _state[slice_name]
				for key in restored_state:
					current_state[key] = restored_state[key]
				_state[slice_name] = current_state
			else:
				_state[slice_name] = restored_state.duplicate(true)
			
			# Clear the handoff state after restoring
			U_STATE_HANDOFF.clear_slice(slice_name)

## Get performance metrics (T414)
##
## Returns dictionary with:
##   - dispatch_count: Total number of actions dispatched
##   - avg_dispatch_time_ms: Average dispatch time in milliseconds
##   - last_dispatch_time_ms: Last dispatch time in milliseconds
##   - signal_emit_count: Total number of signals emitted
func get_performance_metrics() -> Dictionary:
	return _performance_metrics.get_performance_metrics()

## Reset performance metrics (useful for profiling specific sections)
func reset_performance_metrics() -> void:
	_performance_metrics.reset()
