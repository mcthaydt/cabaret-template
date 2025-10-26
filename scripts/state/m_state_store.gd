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

signal state_changed(action: Dictionary, new_state: Dictionary)
signal slice_updated(slice_name: StringName, slice_state: Dictionary)
signal action_dispatched(action: Dictionary)
signal validation_failed(action: Dictionary, error: String)

const PROJECT_SETTING_HISTORY_SIZE := "state/debug/history_size"
const PROJECT_SETTING_ENABLE_PERSISTENCE := "state/runtime/enable_persistence"

@export var settings: RS_StateStoreSettings

var _state: Dictionary = {}
var _subscribers: Array[Callable] = []
var _slice_configs: Dictionary = {}

func _ready() -> void:
	add_to_group("state_store")
	_initialize_settings()
	_initialize_slices()

func _exit_tree() -> void:
	if is_in_group("state_store"):
		remove_from_group("state_store")

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
	# Placeholder - will add slice initialization in Phase 1c
	pass

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

	# Create deep copy of action for subscribers
	var action_copy: Dictionary = action.duplicate(true)

	# Notify subscribers
	for subscriber in _subscribers:
		if subscriber.is_valid():
			subscriber.call(action_copy, _state.duplicate(true))

	# Emit unbatched signal
	action_dispatched.emit(action_copy)

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
func register_slice(config: StateSliceConfig) -> void:
	if config == null:
		push_error("M_StateStore.register_slice: Config is null")
		return

	if config.slice_name == StringName():
		push_error("M_StateStore.register_slice: Slice name is empty")
		return

	_slice_configs[config.slice_name] = config
	_state[config.slice_name] = config.initial_state.duplicate(true)

	if OS.is_debug_build() and settings.enable_debug_logging:
		print("[STATE] Registered slice: ", config.slice_name)
