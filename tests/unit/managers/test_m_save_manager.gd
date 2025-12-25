extends GutTest

## Unit tests for M_SaveManager
##
## Tests the save manager's role as the central coordinator for save/load operations.

const M_SaveManager := preload("res://scripts/managers/m_save_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/state/resources/rs_navigation_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_SaveInitialState := preload("res://scripts/state/resources/rs_save_initial_state.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_SaveActions := preload("res://scripts/state/actions/u_save_actions.gd")
const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")
const U_SceneActions := preload("res://scripts/state/actions/u_scene_actions.gd")

var _store: M_StateStore
var _manager: M_SaveManager
var _dispatched_actions: Array[Dictionary] = []


func before_each() -> void:
	U_StateHandoff.clear_all()
	_dispatched_actions.clear()

	# Create store with persistence disabled
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_history = false
	_store.settings.auto_save_interval = 0.0
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	_store.navigation_initial_state = RS_NavigationInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	_store.save_initial_state = RS_SaveInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	# Create save manager
	_manager = M_SaveManager.new()
	_manager.autosave_interval = 0.0  # Disable autosave for tests
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Connect to action_dispatched
	_store.action_dispatched.connect(_on_action_dispatched)


func after_each() -> void:
	U_StateHandoff.clear_all()
	_dispatched_actions.clear()
	_store = null
	_manager = null


func _on_action_dispatched(action: Dictionary) -> void:
	_dispatched_actions.append(action.duplicate(true))


# ==============================================================================
# Test: Manager Registration & Lifecycle
# ==============================================================================

func test_manager_adds_to_group_on_ready() -> void:
	var nodes: Array = get_tree().get_nodes_in_group("save_manager")
	assert_true(_manager in nodes, "Manager should join save_manager group")


func test_manager_has_process_mode_always() -> void:
	assert_eq(
		_manager.process_mode,
		Node.PROCESS_MODE_ALWAYS,
		"Manager should process even when tree is paused"
	)


# ==============================================================================
# Test: Signal Definitions
# ==============================================================================

func test_manager_has_save_completed_signal() -> void:
	assert_true(
		_manager.has_signal("save_completed"),
		"Manager should emit save_completed signal"
	)


func test_manager_has_load_completed_signal() -> void:
	assert_true(
		_manager.has_signal("load_completed"),
		"Manager should emit load_completed signal"
	)


func test_manager_has_save_failed_signal() -> void:
	assert_true(
		_manager.has_signal("save_failed"),
		"Manager should emit save_failed signal"
	)


func test_manager_has_load_failed_signal() -> void:
	assert_true(
		_manager.has_signal("load_failed"),
		"Manager should emit load_failed signal"
	)


# ==============================================================================
# Test: Save Flow
# ==============================================================================

func test_save_flow_dispatches_save_completed() -> void:
	# Dispatch save_started action (slot 1)
	_store.dispatch(U_SaveActions.save_started(1))
	await get_tree().process_frame
	await get_tree().process_frame

	# Check for save_completed action
	var found_completed := false
	for action in _dispatched_actions:
		if action.get("type") == U_SaveActions.ACTION_SAVE_COMPLETED:
			found_completed = true
			break

	assert_true(found_completed, "Save should dispatch save_completed action")


func test_save_flow_creates_file() -> void:
	# Dispatch save_started action
	_store.dispatch(U_SaveActions.save_started(1))
	await get_tree().process_frame
	await get_tree().process_frame

	# Check file exists
	var path := U_SaveManager.get_manual_slot_path(1)
	var exists := FileAccess.file_exists(path)

	# Clean up
	if exists:
		DirAccess.remove_absolute(path)

	assert_true(exists, "Save file should be created")


# ==============================================================================
# Test: Load Flow
# ==============================================================================

func test_load_from_nonexistent_slot_dispatches_load_failed() -> void:
	# NOTE: This test validates that load_failed is dispatched when slot doesn't exist.
	# The push_error from U_SaveManager is expected behavior (proper error reporting).
	# GUT may flag this as "unexpected error" but the behavior is correct.

	# Clean up any existing file first
	var path := U_SaveManager.get_manual_slot_path(2)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	# Try to load from slot that doesn't exist
	_store.dispatch(U_SaveActions.load_started(2))
	await get_tree().process_frame
	await get_tree().process_frame

	var found_failed := false
	for action in _dispatched_actions:
		if action.get("type") == U_SaveActions.ACTION_LOAD_FAILED:
			found_failed = true
			break

	# The assertion should pass - the error from push_error is expected
	assert_true(found_failed, "Loading nonexistent slot should dispatch load_failed")


func test_load_flow_dispatches_load_completed() -> void:
	# Set up scene state with a valid scene_id before saving
	# This is required because load checks for scene_id
	_store.dispatch(U_SceneActions.transition_completed(StringName("test_scene")))
	await get_tree().process_frame

	# Verify scene state was set
	var scene_state: Dictionary = _store.get_slice(StringName("scene"))
	gut.p("Scene state after transition_completed: %s" % str(scene_state))

	# Create a save
	_store.dispatch(U_SaveActions.save_started(1))
	await get_tree().process_frame
	await get_tree().process_frame
	_dispatched_actions.clear()

	# Load it
	_store.dispatch(U_SaveActions.load_started(1))
	await get_tree().process_frame
	await get_tree().process_frame

	var found_completed := false
	var found_failed := false
	var fail_reason := ""
	for action in _dispatched_actions:
		if action.get("type") == U_SaveActions.ACTION_LOAD_COMPLETED:
			found_completed = true
		if action.get("type") == U_SaveActions.ACTION_LOAD_FAILED:
			found_failed = true
			fail_reason = str(action.get("error", ""))

	# Clean up
	var path := U_SaveManager.get_manual_slot_path(1)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	if found_failed:
		gut.p("Load failed: %s" % fail_reason)

	assert_true(found_completed, "Load should dispatch load_completed action")


# ==============================================================================
# Test: Delete Flow
# ==============================================================================

func test_delete_flow_dispatches_delete_completed() -> void:
	# Create a save first
	_store.dispatch(U_SaveActions.save_started(1))
	await get_tree().process_frame
	await get_tree().process_frame
	_dispatched_actions.clear()

	# Delete it
	_store.dispatch(U_SaveActions.delete_started(1))
	await get_tree().process_frame
	await get_tree().process_frame

	var found_completed := false
	for action in _dispatched_actions:
		if action.get("type") == U_SaveActions.ACTION_DELETE_COMPLETED:
			found_completed = true
			break

	assert_true(found_completed, "Delete should dispatch delete_completed action")


func test_delete_flow_removes_file() -> void:
	# Create a save first
	_store.dispatch(U_SaveActions.save_started(1))
	await get_tree().process_frame
	await get_tree().process_frame

	var path := U_SaveManager.get_manual_slot_path(1)
	assert_true(FileAccess.file_exists(path), "Save file should exist before delete")

	# Delete it
	_store.dispatch(U_SaveActions.delete_started(1))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(FileAccess.file_exists(path), "Save file should be deleted")


# ==============================================================================
# Test: Autosave Timer
# ==============================================================================

func test_manager_owns_autosave_timer_when_enabled() -> void:
	# Create a manager with autosave enabled
	var test_manager := M_SaveManager.new()
	test_manager.autosave_interval = 60.0
	add_child_autofree(test_manager)
	await get_tree().process_frame

	var has_timer := false
	for child in test_manager.get_children():
		if child is Timer and child.name == "AutosaveTimer":
			has_timer = true
			break

	assert_true(has_timer, "Manager with autosave_interval > 0 should have AutosaveTimer")


func test_autosave_disabled_when_interval_zero() -> void:
	# _manager was created with autosave_interval = 0
	var has_timer := false
	for child in _manager.get_children():
		if child is Timer and child.name == "AutosaveTimer":
			has_timer = true
			break

	assert_false(has_timer, "Manager with autosave_interval = 0 should not have timer")
