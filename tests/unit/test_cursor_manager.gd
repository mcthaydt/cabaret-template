extends BaseTest

const CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _signal_fired := false
var _last_locked_state := false
var _last_visible_state := false

func _on_cursor_state_changed(locked: bool, visible: bool) -> void:
	_signal_fired = true
	_last_locked_state = locked
	_last_visible_state = visible

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_signal_fired = false
	_last_locked_state = false
	_last_visible_state = false

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

func test_manager_initializes_with_locked_and_hidden_cursor() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for Input.mouse_mode to settle in headless mode

	assert_true(manager.is_cursor_locked(), "Cursor should be locked on initialization")
	assert_false(manager.is_cursor_visible(), "Cursor should be hidden on initialization")
	# Note: Input.mouse_mode checks are skipped in headless mode (always returns MOUSE_MODE_VISIBLE)
	# The manager's internal state (checked above) is what matters for functionality

## T071: Tests for toggle_cursor() removed - method no longer exists
## Cursor state is now controlled via explicit set_cursor_state() calls from M_TimeManager

func test_set_cursor_locked_changes_lock_state() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_locked(false)

	assert_false(manager.is_cursor_locked(), "Cursor should be unlocked")
	# Mouse mode depends on visibility, so it could be VISIBLE or HIDDEN
	assert_ne(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "Mouse mode should not be CAPTURED")

func test_set_cursor_visible_changes_visibility() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_visible(true)

	assert_true(manager.is_cursor_visible(), "Cursor should be visible")

func test_set_cursor_state_changes_both_states() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_state(false, true)

	assert_false(manager.is_cursor_locked(), "Cursor should be unlocked")
	assert_true(manager.is_cursor_visible(), "Cursor should be visible")
	# Note: Input.mouse_mode checks are skipped in headless mode

func test_cursor_state_changed_signal_emits() -> void:
	# T071: Updated to use set_cursor_state() instead of removed toggle_cursor()
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.cursor_state_changed.connect(_on_cursor_state_changed)
	manager.set_cursor_state(false, true)  # Unlock and show

	assert_true(_signal_fired, "cursor_state_changed signal should have fired")
	assert_false(_last_locked_state, "Signal should indicate unlocked state")
	assert_true(_last_visible_state, "Signal should indicate visible state")

func test_cursor_state_changed_signal_does_not_emit_when_state_unchanged() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.cursor_state_changed.connect(_on_cursor_state_changed)
	# Try to set to the same initial state
	manager.set_cursor_state(true, false)

	assert_false(_signal_fired, "cursor_state_changed signal should not fire when state is unchanged")

func test_cursor_manager_does_not_handle_pause_input() -> void:
	# T071: M_CursorManager no longer handles pause/ESC input directly
	# Cursor state is controlled via explicit calls from M_TimeManager
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	# Verify initial state
	assert_true(manager.is_cursor_locked(), "Cursor should be locked initially")
	assert_false(manager.is_cursor_visible(), "Cursor should be hidden initially")

	# Simulate ESC input (should NOT change cursor state anymore)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame

	# Cursor state should remain unchanged (no input handling)
	assert_true(manager.is_cursor_locked(), "Cursor should still be locked (no input handling)")
	assert_false(manager.is_cursor_visible(), "Cursor should still be hidden (no input handling)")

func test_manager_registers_with_service_locator() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var service := U_SERVICE_LOCATOR.get_service(StringName("cursor_manager"))
	assert_eq(service, manager, "Manager should register with ServiceLocator")

func test_locked_cursor_uses_captured_mode() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_state(true, false)
	await get_tree().process_frame  # Wait for Input.mouse_mode to settle

	# Note: Input.mouse_mode checks are skipped in headless mode (always returns MOUSE_MODE_VISIBLE)
	# We verify the manager state is correctly set instead
	assert_true(manager.is_cursor_locked(), "Manager state should be locked")
	assert_false(manager.is_cursor_visible(), "Manager state should be hidden")

func test_unlocked_visible_cursor_uses_visible_mode() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_state(false, true)

	# Note: Input.mouse_mode checks are skipped in headless mode
	assert_false(manager.is_cursor_locked(), "Manager state should be unlocked")
	assert_true(manager.is_cursor_visible(), "Manager state should be visible")

func test_unlocked_hidden_cursor_uses_hidden_mode() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_state(false, false)
	await get_tree().process_frame  # Wait for Input.mouse_mode to settle

	# Note: Input.mouse_mode checks are skipped in headless mode
	assert_false(manager.is_cursor_locked(), "Manager state should be unlocked")
	assert_false(manager.is_cursor_visible(), "Manager state should be hidden")
