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

signal state_changed(action: Dictionary, new_state: Dictionary)
signal slice_updated(slice_name: StringName, slice_state: Dictionary)
signal action_dispatched(action: Dictionary)
signal validation_failed(action: Dictionary, error: String)

const PROJECT_SETTING_HISTORY_SIZE := "state/debug/history_size"
const PROJECT_SETTING_ENABLE_PERSISTENCE := "state/runtime/enable_persistence"

@export var settings: RS_StateStoreSettings
@export var gameplay_initial_state: RS_GameplayInitialState

var _state: Dictionary = {}
var _subscribers: Array[Callable] = []
var _slice_configs: Dictionary = {}
var _signal_batcher: SignalBatcher = null

func _ready() -> void:
	add_to_group("state_store")
	_initialize_settings()
	_initialize_slices()
	_signal_batcher = SignalBatcher.new()
	set_physics_process(true)  # Enable physics processing for signal batching

func _exit_tree() -> void:
	if is_in_group("state_store"):
		remove_from_group("state_store")

func _physics_process(_delta: float) -> void:
	# Flush batched signals once per physics frame
	if _signal_batcher != null:
		_signal_batcher.flush(func(slice_name: StringName, slice_state: Dictionary) -> void:
			slice_updated.emit(slice_name, slice_state)
		)

func _initialize_settings() -> void:
	if settings == null:
		push_warning("M_StateStore: No settings assigned, using defaults")
		settings = RS_StateStoreSettings.new()

	# Load from project settings if available
	if ProjectSettings.has_setting(PROJECT_SETTING_HISTORY_SIZE):
		var history_size: int = ProjectSettings.get_setting(PROJECT_SETTING_HISTORY_SIZE, 1000)
		if settings.max_history_size != history_size:
			settings.max_history_size = history_size

func _initialize_slices() -> void:
	# Register gameplay slice if initial state provided
	if gameplay_initial_state != null:
		var gameplay_config := StateSliceConfig.new(StringName("gameplay"))
		gameplay_config.reducer = Callable(GameplayReducer, "reduce")
		gameplay_config.initial_state = gameplay_initial_state.to_dictionary()
		gameplay_config.dependencies = []
		gameplay_config.transient_fields = []
		register_slice(gameplay_config)

## Dispatch an action to update state
func dispatch(action: Dictionary) -> void:
	# Validate action using ActionRegistry
	if not ActionRegistry.validate_action(action):
		var error_msg: String = "Action validation failed"
		if not action.has("type"):
			error_msg = "Action missing 'type' field"
		elif not ActionRegistry.is_registered(action.get("type")):
			error_msg = "Unregistered action type: %s" % action.get("type")
		
		validation_failed.emit(action, error_msg)
		return

	# Log action in debug mode
	if OS.is_debug_build() and settings.enable_debug_logging:
		print("[STATE] Action dispatched: ", action.get("type"))

	# Process action through reducers to update state
	_apply_reducers(action)

	# Create deep copy of action for subscribers
	var action_copy: Dictionary = action.duplicate(true)

	# Notify subscribers with new state
	for subscriber in _subscribers:
		var state_copy := _state.duplicate(true)
		subscriber.call(action_copy, state_copy)

	# Emit unbatched signal
	action_dispatched.emit(action_copy)

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
func get_slice(slice_name: StringName) -> Dictionary:
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

	if OS.is_debug_build() and settings.enable_debug_logging:
		print("[STATE] Registered slice: ", config.slice_name)

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
