extends I_StateStore
class_name MockStateStore

## Functional mock for M_StateStore
##
## Maintains actual state and dispatched action history for test assertions.
## Implements slice-based state management for realistic behavior.
##
## Phase 10B-8 (T142b): Created to enable isolated system testing
##
## Test helpers:
## - set_slice(name, data): Pre-configure slice state
## - get_dispatched_actions(): Verify which actions were dispatched
## - clear_dispatched_actions(): Reset action history
## - reset(): Clear all state and history

signal action_dispatched(action: Dictionary)
signal slice_updated(slice_name: StringName, slice_state: Dictionary)

var _state: Dictionary = {}
var _subscribers: Array[Callable] = []
var _dispatched_actions: Array[Dictionary] = []
var _is_ready: bool = true

func _init(initial_state: Dictionary = {}) -> void:
	_state = initial_state.duplicate(true)
	# Ensure common slices exist
	if not _state.has("gameplay"):
		_state["gameplay"] = {}
	if not _state.has("input"):
		_state["input"] = {}
	if not _state.has("settings"):
		_state["settings"] = {}
	if not _state.has("navigation"):
		_state["navigation"] = {}

func dispatch(action: Dictionary) -> void:
	_dispatched_actions.append(action.duplicate(true))

	# Emit action_dispatched signal (for autosave scheduler)
	action_dispatched.emit(action.duplicate(true))

	# Optionally apply simple reducers for common actions
	var action_type: String = str(action.get("type", ""))
	if action_type == "TAKE_DAMAGE":
		_apply_damage_action(action)
	elif action_type == "UPDATE_MOVE_INPUT":
		_apply_move_input_action(action)
	elif action_type == "SET_LAST_CHECKPOINT":
		_apply_checkpoint_action(action)

	# Notify subscribers
	var action_copy := action.duplicate(true)
	var state_copy := _state.duplicate(true)
	for subscriber in _subscribers:
		if subscriber.is_valid():
			subscriber.call(action_copy, state_copy)

func subscribe(callback: Callable) -> Callable:
	if not callback.is_valid():
		return Callable()
	_subscribers.append(callback)
	return func() -> void:
		_subscribers.erase(callback)

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_slice(slice_name: StringName) -> Dictionary:
	return _state.get(slice_name, {}).duplicate(true)

func get_persistable_state() -> Dictionary:
	# Mock implementation - filter out known transient fields to match M_StateStore behavior
	var filtered_state: Dictionary = _state.duplicate(true)

	# Filter scene slice transient fields: is_transitioning, transition_type, scene_stack
	if filtered_state.has("scene"):
		var scene_slice: Dictionary = filtered_state["scene"].duplicate(true)
		scene_slice.erase("is_transitioning")
		scene_slice.erase("transition_type")
		scene_slice.erase("scene_stack")  # KEY FIX: Don't persist overlay stack
		filtered_state["scene"] = scene_slice

	# Navigation slice is entirely transient - exclude it completely
	filtered_state.erase("navigation")

	return filtered_state

func get_slice_configs() -> Dictionary:
	# Mock implementation - return simplified configs for testing
	return {
		"scene": {
			"transient_fields": [
				StringName("is_transitioning"),
				StringName("transition_type"),
				StringName("scene_stack")
			]
		}
	}

func is_ready() -> bool:
	return _is_ready

## Test helpers

## Pre-configure a state slice for testing
func set_slice(slice_name: StringName, slice_data: Dictionary) -> void:
	_state[slice_name] = slice_data.duplicate(true)

## Get all dispatched actions for verification
func get_dispatched_actions() -> Array[Dictionary]:
	return _dispatched_actions.duplicate(false)

## Clear dispatched action history
func clear_dispatched_actions() -> void:
	_dispatched_actions.clear()

## Reset all state and history
func reset() -> void:
	_state.clear()
	_subscribers.clear()
	_dispatched_actions.clear()
	# Re-initialize default slices
	_state["gameplay"] = {}
	_state["input"] = {}
	_state["settings"] = {}
	_state["navigation"] = {}

## Simple reducer implementations for common actions

func _apply_damage_action(action: Dictionary) -> void:
	var payload: Variant = action.get("payload", {})
	if not payload is Dictionary:
		return

	var entity_id: String = str(payload.get("entity_id", ""))
	var damage: float = float(payload.get("damage", 0.0))
	if entity_id.is_empty() or damage <= 0.0:
		return

	var gameplay: Dictionary = _state.get("gameplay", {})
	if entity_id == gameplay.get("player_entity_id", "player"):
		var current_health: float = float(gameplay.get("player_health", 100.0))
		gameplay["player_health"] = maxf(0.0, current_health - damage)
		_state["gameplay"] = gameplay

func _apply_move_input_action(action: Dictionary) -> void:
	var payload: Variant = action.get("payload", {})
	if not payload is Dictionary:
		return

	var move_input: Vector2 = payload.get("move_input", Vector2.ZERO)
	var input_slice: Dictionary = _state.get("input", {})
	input_slice["move_input"] = move_input
	_state["input"] = input_slice

func _apply_checkpoint_action(action: Dictionary) -> void:
	var payload: Variant = action.get("payload", {})
	if not payload is Dictionary:
		return

	var checkpoint_id: String = str(payload.get("checkpoint_id", ""))
	var spawn_point: String = str(payload.get("spawn_point", ""))
	if checkpoint_id.is_empty():
		return

	var gameplay: Dictionary = _state.get("gameplay", {})
	gameplay["last_checkpoint"] = checkpoint_id
	if not spawn_point.is_empty():
		gameplay["target_spawn_point"] = spawn_point
	_state["gameplay"] = gameplay
