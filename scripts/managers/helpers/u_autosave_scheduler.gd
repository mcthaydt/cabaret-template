extends Node
class_name U_AutosaveScheduler

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
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")

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

func _on_checkpoint_activated(__event: Dictionary) -> void:
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

	# Check if transitioning to a gameplay scene (alleyway, interior, etc.)
		if _is_gameplay_scene(scene_id):
			# For gameplay scenes, autosave even if shell isn't set to 'gameplay' yet
			_request_autosave_for_gameplay_transition(Priority.HIGH)
		# Do not autosave on non-gameplay transitions (menu/endgame/ui). These can
		# occur while navigation.shell still reflects gameplay and would overwrite
		# the latest gameplay autosave with an unusable target scene (e.g., game_over).

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
	var block_reason: String = _get_autosave_block_reason(false)
	if not block_reason.is_empty():
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
	return _get_autosave_block_reason(false).is_empty()

func _get_autosave_block_reason(skip_shell_check: bool) -> String:
	if _state_store == null or _save_manager == null:
		if _state_store == null:
			return "state_store unavailable"
		return "save_manager unavailable"

	var state: Dictionary = _state_store.get_state()

	# Only autosave during gameplay (not in menus)
	if not skip_shell_check:
		var navigation: Dictionary = state.get("navigation", {})
		if navigation.get("shell", "") != "gameplay":
			return "navigation.shell=%s" % str(navigation.get("shell", ""))

	# Check death_in_progress flag
	var gameplay: Dictionary = state.get("gameplay", {})
	if gameplay.get("death_in_progress", false):
		return "gameplay.death_in_progress=true"

	# Check scene transitioning flag
	var scene: Dictionary = state.get("scene", {})
	if scene.get("is_transitioning", false):
		return "scene.is_transitioning=true"

	# Check if save manager is locked
	var typed_save_manager := _save_manager as I_SaveManager
	if typed_save_manager != null and typed_save_manager.is_locked():
		return "save_manager.is_locked=true"

	return ""

func _is_gameplay_scene(scene_id: StringName) -> bool:
	if scene_id == StringName(""):
		return false

	var scene_type: int = U_SCENE_REGISTRY.get_scene_type(scene_id)
	if scene_type == U_SCENE_REGISTRY.SceneType.GAMEPLAY:
		return true

	# Fallback for tests or dev scenes not registered in the registry.
	var fallback_gameplay_scenes := [
		StringName("alleyway"),
		StringName("gameplay_base"),
		StringName("interior_house"),
		StringName("scene1"),
		StringName("scene2"),
		StringName("scene3"),
	]
	return scene_id in fallback_gameplay_scenes

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
	var block_reason: String = _get_autosave_block_reason(true)
	if not block_reason.is_empty():
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
	var typed_save_manager := _save_manager as I_SaveManager
	if typed_save_manager != null:
		typed_save_manager.request_autosave(priority)
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
