extends Node
class_name M_AutosaveScheduler

## Autosave Scheduler (Phase 6)
##
## Manages autosave triggers, coalescing, and cooldown enforcement.
## Subscribes to milestone events and dispatches autosave requests to M_SaveManager.
##
## Triggers:
## - checkpoint_activated (ECS event)
## - gameplay/mark_area_complete (Redux action)
## - scene/transition_completed (Redux action)
##
## Blocking conditions:
## - gameplay.death_in_progress == true
## - scene.is_transitioning == true
## - M_SaveManager is locked (_is_saving or _is_loading)
##
## Cooldown/Priority:
## - NORMAL: 5s cooldown
## - HIGH: 2s cooldown
## - CRITICAL: always trigger

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

enum Priority {
	NORMAL = 0,
	HIGH = 1,
	CRITICAL = 2
}

const COOLDOWN_NORMAL := 5.0  # 5 seconds
const COOLDOWN_HIGH := 2.0    # 2 seconds

const EVENT_CHECKPOINT_ACTIVATED := StringName("checkpoint_activated")
const ACTION_MARK_AREA_COMPLETE := StringName("gameplay/mark_area_complete")
const ACTION_TRANSITION_COMPLETED := StringName("scene/transition_completed")

var _state_store = null
var _save_manager = null
var _event_unsubscribes: Array[Callable] = []

# Dirty flag + priority tracking for coalescing
var _is_dirty: bool = false
var _pending_priority: int = Priority.NORMAL
var _last_autosave_time: float = -1000.0  # Initialize to distant past to allow first autosave

func _ready() -> void:
	_discover_dependencies()
	_subscribe_to_triggers()

func _discover_dependencies() -> void:
	_state_store = _get_state_store()
	_save_manager = _get_save_manager()

func _get_state_store():
	return U_SERVICE_LOCATOR.get_service(StringName("state_store"))

func _get_save_manager():
	return U_SERVICE_LOCATOR.get_service(StringName("save_manager"))

func _subscribe_to_triggers() -> void:
	# Subscribe to ECS events
	_event_unsubscribes.append(
		U_ECSEventBus.subscribe(EVENT_CHECKPOINT_ACTIVATED, _on_checkpoint_activated)
	)

	# Subscribe to Redux actions via action_dispatched signal
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		_state_store.action_dispatched.connect(_on_action_dispatched)

func _on_checkpoint_activated(_event: Dictionary) -> void:
	_request_autosave_if_allowed(Priority.NORMAL)

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))

	if action_type == ACTION_MARK_AREA_COMPLETE:
		# DON'T autosave on mark_area_complete - wait for transition_completed instead
		# This ensures we save AFTER the scene transition, not before
		pass
	elif action_type == ACTION_TRANSITION_COMPLETED:
		var payload: Dictionary = action.get("payload", {})
		var scene_id: StringName = payload.get("scene_id", StringName(""))

		# Check if transitioning to a gameplay scene (exterior, interior, etc.)
		if _is_gameplay_scene(scene_id):
			# For gameplay scenes, autosave even if shell isn't set to 'gameplay' yet
			_request_autosave_for_gameplay_transition(Priority.HIGH)
		else:
			_request_autosave_if_allowed(Priority.NORMAL)

func _request_autosave_if_allowed(priority: int) -> void:
	# Enforce cooldown based on priority
	var now := Time.get_ticks_msec() / 1000.0
	var time_since_last_save := now - _last_autosave_time

	if priority == Priority.NORMAL and time_since_last_save < COOLDOWN_NORMAL:
		return  # Skip - too soon for normal priority
	elif priority == Priority.HIGH and time_since_last_save < COOLDOWN_HIGH:
		return  # Skip - too soon for high priority
	# CRITICAL priority ignores cooldown

	# Check blocking conditions
	if not _is_autosave_allowed():
		return

	# Mark dirty and track highest priority
	_is_dirty = true
	_pending_priority = maxi(_pending_priority, priority)

	# Schedule autosave on next frame (coalescing happens here)
	if not _is_dirty:
		return

	# Perform autosave immediately (coalescing within same frame)
	call_deferred("_perform_autosave")

func _is_autosave_allowed() -> bool:
	if _state_store == null or _save_manager == null:
		return false

	var state: Dictionary = _state_store.get_state()

	# Only autosave during gameplay (not in menus)
	var navigation: Dictionary = state.get("navigation", {})
	if navigation.get("shell", "") != "gameplay":
		return false

	# Check death_in_progress flag
	var gameplay: Dictionary = state.get("gameplay", {})
	if gameplay.get("death_in_progress", false):
		return false

	# Check scene transitioning flag
	var scene: Dictionary = state.get("scene", {})
	if scene.get("is_transitioning", false):
		return false

	# Check if save manager is locked
	if _save_manager.has_method("is_locked") and _save_manager.is_locked():
		return false

	return true

func _is_gameplay_scene(scene_id: StringName) -> bool:
	# Check if this is a gameplay scene (not menu/victory/etc)
	var gameplay_scenes := [
		StringName("exterior"),
		StringName("gameplay_base"),
		StringName("interior_house"),
		StringName("test_scene"),
	]
	return scene_id in gameplay_scenes

func _request_autosave_for_gameplay_transition(priority: int) -> void:
	# Special autosave for gameplay scene transitions
	# Skips the shell check since shell might be transitioning
	var now := Time.get_ticks_msec() / 1000.0
	var time_since_last_save := now - _last_autosave_time

	# Enforce cooldown
	if priority == Priority.NORMAL and time_since_last_save < COOLDOWN_NORMAL:
		return
	elif priority == Priority.HIGH and time_since_last_save < COOLDOWN_HIGH:
		return

	# Check other blocking conditions (except shell)
	if _state_store == null or _save_manager == null:
		return

	var state: Dictionary = _state_store.get_state()
	var gameplay: Dictionary = state.get("gameplay", {})
	if gameplay.get("death_in_progress", false):
		return

	var scene: Dictionary = state.get("scene", {})
	if scene.get("is_transitioning", false):
		return

	if _save_manager.has_method("is_locked") and _save_manager.is_locked():
		return

	# Trigger autosave
	_is_dirty = true
	_pending_priority = maxi(_pending_priority, priority)
	call_deferred("_perform_autosave")

func _perform_autosave() -> void:
	if not _is_dirty:
		return

	# Clear dirty flag and reset priority
	_is_dirty = false
	var priority: int = _pending_priority
	_pending_priority = Priority.NORMAL

	# Request autosave from save manager
	if _save_manager != null and _save_manager.has_method("request_autosave"):
		_save_manager.request_autosave(priority)
		_last_autosave_time = Time.get_ticks_msec() / 1000.0

func _exit_tree() -> void:
	# Unsubscribe from ECS events
	for unsubscribe in _event_unsubscribes:
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribes.clear()

	# Disconnect from state store
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		if _state_store.action_dispatched.is_connected(_on_action_dispatched):
			_state_store.action_dispatched.disconnect(_on_action_dispatched)
