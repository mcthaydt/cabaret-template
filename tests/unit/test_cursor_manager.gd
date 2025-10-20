extends BaseTest

const CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")

var _signal_fired := false
var _last_locked_state := false
var _last_visible_state := false

func _on_cursor_state_changed(locked: bool, visible: bool) -> void:
	_signal_fired = true
	_last_locked_state = locked
	_last_visible_state = visible

func before_each() -> void:
	_signal_fired = false
	_last_locked_state = false
	_last_visible_state = false

func test_manager_initializes_with_locked_and_hidden_cursor() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	assert_true(manager.is_cursor_locked(), "Cursor should be locked on initialization")
	assert_false(manager.is_cursor_visible(), "Cursor should be hidden on initialization")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "Mouse mode should be CAPTURED")

func test_toggle_cursor_unlocks_and_shows() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.toggle_cursor()

	assert_false(manager.is_cursor_locked(), "Cursor should be unlocked after toggle")
	assert_true(manager.is_cursor_visible(), "Cursor should be visible after toggle")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "Mouse mode should be VISIBLE")

func test_toggle_cursor_locks_and_hides_when_unlocked() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	# First toggle to unlock/show
	manager.toggle_cursor()
	await get_tree().process_frame
	# Second toggle should lock/hide
	manager.toggle_cursor()
	await get_tree().process_frame

	assert_true(manager.is_cursor_locked(), "Cursor should be locked after second toggle")
	assert_false(manager.is_cursor_visible(), "Cursor should be hidden after second toggle")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "Mouse mode should be CAPTURED")

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
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "Mouse mode should be VISIBLE")

func test_cursor_state_changed_signal_emits() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.cursor_state_changed.connect(_on_cursor_state_changed)
	manager.toggle_cursor()

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

func test_esc_key_toggles_cursor() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	# Create and dispatch ESC key press event
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_ESCAPE
	key_event.pressed = true
	manager._unhandled_input(key_event)

	assert_false(manager.is_cursor_locked(), "ESC should unlock cursor")
	assert_true(manager.is_cursor_visible(), "ESC should show cursor")

func test_manager_adds_to_cursor_manager_group() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	assert_true(manager.is_in_group("cursor_manager"), "Manager should be in cursor_manager group")

func test_locked_cursor_uses_captured_mode() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_state(true, false)

	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "Locked cursor should use CAPTURED mode")

func test_unlocked_visible_cursor_uses_visible_mode() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_state(false, true)

	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "Unlocked visible cursor should use VISIBLE mode")

func test_unlocked_hidden_cursor_uses_hidden_mode() -> void:
	var manager := CURSOR_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	manager.set_cursor_state(false, false)

	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_HIDDEN, "Unlocked hidden cursor should use HIDDEN mode")
