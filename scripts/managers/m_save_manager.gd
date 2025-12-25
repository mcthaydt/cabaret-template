@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_SaveManager

## Save Manager - Coordinates save/load operations
##
## Responsibilities:
## - Subscribe to save/load/delete actions from Redux
## - Coordinate save operations using U_SaveManager
## - Coordinate load operations with scene transitions
## - Own the autosave timer
## - Emit signals for UI feedback
##
## Discovery: Add to "save_manager" group, discoverable via ServiceLocator or group lookup
##
## Signals:
## - save_completed(slot_index, success): Emitted after save operation
## - load_completed(slot_index, success): Emitted after load operation
## - save_failed(slot_index, error): Emitted on save failure
## - load_failed(slot_index, error): Emitted on load failure

signal save_completed(slot_index: int, success: bool)
signal load_completed(slot_index: int, success: bool)
signal save_failed(slot_index: int, error: String)
signal load_failed(slot_index: int, error: String)

const U_SAVE_MANAGER := preload("res://scripts/state/utils/u_save_manager.gd")
const U_SAVE_ACTIONS := preload("res://scripts/state/actions/u_save_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

## Autosave interval in seconds (0 = disabled)
@export var autosave_interval: float = 60.0

## Test mode - uses test paths instead of real save paths
var test_mode: bool = false
var test_slot_pattern: String = ""
var test_auto_slot_path: String = ""

## Internal references (store is untyped for compatibility with mock stores)
var _store = null
var _scene_manager: Node = null
var _autosave_timer: Timer = null


func _ready() -> void:
	# Must continue operating when tree is paused (save from pause menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Add to group for discovery
	add_to_group("save_manager")

	# Wait for other managers to initialize
	await get_tree().process_frame

	# Find store
	_store = _find_store()
	if _store == null:
		push_error("M_SaveManager: No state store found")
		return

	# Find scene manager (optional - may not exist in tests)
	_scene_manager = _find_scene_manager()

	# Subscribe to actions
	_store.action_dispatched.connect(_on_action_dispatched)

	# Setup autosave timer
	_setup_autosave_timer()


func _exit_tree() -> void:
	if _store != null and _store.has_signal("action_dispatched"):
		if _store.action_dispatched.is_connected(_on_action_dispatched):
			_store.action_dispatched.disconnect(_on_action_dispatched)

	if is_in_group("save_manager"):
		remove_from_group("save_manager")


# ==============================================================================
# Store & Manager Discovery
# ==============================================================================

func _find_store():
	# Try ServiceLocator first (matches M_SceneManager pattern)
	var store = U_SERVICE_LOCATOR.try_get_service(StringName("state_store"))
	if store != null:
		return store

	# Fallback to group lookup
	var stores := get_tree().get_nodes_in_group("state_store")
	if not stores.is_empty():
		return stores[0]

	return null


func _find_scene_manager() -> Node:
	# Try ServiceLocator first (matches pattern from other managers)
	var manager = U_SERVICE_LOCATOR.try_get_service(StringName("scene_manager"))
	if manager != null:
		return manager

	# Fallback to group lookup
	var managers := get_tree().get_nodes_in_group("scene_manager")
	if not managers.is_empty():
		return managers[0]

	return null


# ==============================================================================
# Action Subscription
# ==============================================================================

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: Variant = action.get("type")

	match action_type:
		U_SAVE_ACTIONS.ACTION_SAVE_STARTED:
			_handle_save_started(action)
		U_SAVE_ACTIONS.ACTION_LOAD_STARTED:
			_handle_load_started(action)
		U_SAVE_ACTIONS.ACTION_DELETE_STARTED:
			_handle_delete_started(action)


# ==============================================================================
# Save Flow
# ==============================================================================

func _handle_save_started(action: Dictionary) -> void:
	var slot_index: int = action.get("slot_index", -1)
	if slot_index < 0:
		_dispatch_action(U_SAVE_ACTIONS.save_failed(slot_index, "Invalid slot index"))
		save_failed.emit(slot_index, "Invalid slot index")
		return

	# Get current state from store
	var state: Dictionary = _store.get_state()

	# Save to slot
	var err: Error = OK
	if slot_index == U_SAVE_MANAGER.AUTO_SLOT_INDEX:
		err = U_SAVE_MANAGER.save_to_auto_slot(state, {})
	else:
		err = U_SAVE_MANAGER.save_to_slot(slot_index, state, {})

	if err != OK:
		var error_msg := "Save failed: %s" % error_string(err)
		_dispatch_action(U_SAVE_ACTIONS.save_failed(slot_index, error_msg))
		save_failed.emit(slot_index, error_msg)
		return

	# Success
	_dispatch_action(U_SAVE_ACTIONS.save_completed(slot_index))
	save_completed.emit(slot_index, true)


# ==============================================================================
# Load Flow
# ==============================================================================

func _handle_load_started(action: Dictionary) -> void:
	var slot_index: int = action.get("slot_index", -1)
	if slot_index < 0:
		_dispatch_action(U_SAVE_ACTIONS.load_failed(slot_index, "Invalid slot index"))
		load_failed.emit(slot_index, "Invalid slot index")
		return

	# Clear navigation overlays BEFORE loading (Bug #6 prevention)
	_clear_navigation_overlays()

	# Check if save file exists
	var path: String
	if slot_index == U_SAVE_MANAGER.AUTO_SLOT_INDEX:
		path = U_SAVE_MANAGER.get_auto_slot_path()
	else:
		path = U_SAVE_MANAGER.get_manual_slot_path(slot_index)

	if not FileAccess.file_exists(path):
		var error_msg := "Save file not found: %s" % path
		_dispatch_action(U_SAVE_ACTIONS.load_failed(slot_index, error_msg))
		load_failed.emit(slot_index, error_msg)
		return

	# Load state using M_StateStore.load_from_save_slot() which modifies _state directly
	var err: Error = _store.load_from_save_slot(slot_index)

	if err != OK:
		var error_msg := "Load failed: %s" % error_string(err)
		_dispatch_action(U_SAVE_ACTIONS.load_failed(slot_index, error_msg))
		load_failed.emit(slot_index, error_msg)
		return

	# Get loaded scene_id from the newly loaded state
	var loaded_scene_slice: Dictionary = _store.get_slice(StringName("scene"))
	var loaded_scene_id: StringName = loaded_scene_slice.get("current_scene_id", StringName(""))

	if loaded_scene_id == StringName(""):
		_dispatch_action(U_SAVE_ACTIONS.load_failed(slot_index, "No scene_id in save file"))
		load_failed.emit(slot_index, "No scene_id in save file")
		return

	# Trigger scene transition to loaded scene
	# start_game will handle the shell change and scene transition
	_dispatch_action(U_NAVIGATION_ACTIONS.start_game(loaded_scene_id))

	# Success
	_dispatch_action(U_SAVE_ACTIONS.load_completed(slot_index))
	load_completed.emit(slot_index, true)


func _clear_navigation_overlays() -> void:
	if _store == null:
		return

	var nav_state: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack: Array = nav_state.get("overlay_stack", [])

	# Close each overlay
	for _i in range(overlay_stack.size()):
		_dispatch_action(U_NAVIGATION_ACTIONS.close_top_overlay())


# ==============================================================================
# Delete Flow
# ==============================================================================

func _handle_delete_started(action: Dictionary) -> void:
	var slot_index: int = action.get("slot_index", -1)
	if slot_index < 0:
		_dispatch_action(U_SAVE_ACTIONS.delete_failed(slot_index, "Invalid slot index"))
		return

	# Cannot delete autosave slot
	if slot_index == U_SAVE_MANAGER.AUTO_SLOT_INDEX:
		_dispatch_action(U_SAVE_ACTIONS.delete_failed(slot_index, "Cannot delete autosave slot"))
		return

	# Delete slot
	var err: Error = U_SAVE_MANAGER.delete_slot(slot_index)

	if err != OK:
		var error_msg := "Delete failed: %s" % error_string(err)
		_dispatch_action(U_SAVE_ACTIONS.delete_failed(slot_index, error_msg))
		return

	# Success
	_dispatch_action(U_SAVE_ACTIONS.delete_completed(slot_index))


# ==============================================================================
# Autosave Timer
# ==============================================================================

func _setup_autosave_timer() -> void:
	if autosave_interval <= 0.0:
		return

	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = true
	_autosave_timer.wait_time = autosave_interval
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)


func _on_autosave_timeout() -> void:
	if _store == null:
		return

	# Only autosave during gameplay
	var nav_state: Dictionary = _store.get_slice(StringName("navigation"))
	var shell: StringName = nav_state.get("shell", StringName(""))
	if shell != StringName("gameplay"):
		return

	# Don't autosave during transitions
	var scene_state: Dictionary = _store.get_slice(StringName("scene"))
	if scene_state.get("is_transitioning", false):
		return

	# Trigger autosave
	var state: Dictionary = _store.get_state()
	var err: Error = U_SAVE_MANAGER.save_to_auto_slot(state, {})

	if err != OK:
		push_warning("M_SaveManager: Autosave failed: %s" % error_string(err))


# ==============================================================================
# Helpers
# ==============================================================================

func _dispatch_action(action: Dictionary) -> void:
	if _store == null:
		return
	_store.dispatch(action)
