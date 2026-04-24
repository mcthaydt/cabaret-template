extends GutTest

## Tests for rebind overlay gamepad event filtering.
## Validates that when device_category is "gamepad" and the active profile
## is a keyboard profile, the overlay falls back to InputMap events to find
## gamepad bindings instead of showing keyboard keys.

const OverlayScene := preload("res://scenes/ui/overlays/ui_input_rebinding_overlay.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")

var _store: TestStateStore
var _profile_manager: GamepadFilterProfileStub
var _scene_manager_mock: Node

# Use real action names that exist in ACTION_CATEGORIES so build_action_rows includes them.
const ACTION_JUMP := StringName("jump")
const ACTION_MOVE_FWD := StringName("move_forward")
const ACTION_SPRINT := StringName("sprint")

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null
	_store = TestStateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	if _store.settings != null:
		_store.settings.enable_persistence = false
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await _pump()
	await _pump()

	_profile_manager = GamepadFilterProfileStub.new()
	add_child_autofree(_profile_manager)
	_profile_manager.store_ref = _store
	U_ServiceLocator.register(StringName("input_profile_manager"), _profile_manager)
	await _pump()

	_scene_manager_mock = SceneManagerMock.new()
	add_child_autofree(_scene_manager_mock)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager_mock)

func after_each() -> void:
	if _profile_manager != null:
		_profile_manager.teardown()
	_profile_manager = null
	_store = null
	_scene_manager_mock = null
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	U_UI_THEME_BUILDER.active_config = null

# ── Tests ──────────────────────────────────────────────────────────────

func test_gamepad_device_shows_gamepad_bindings_when_profile_is_keyboard_only() -> void:
	_set_device_type_gamepad()

	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var action_rows: Dictionary = overlay._action_rows
	var jump_data: Dictionary = action_rows.get(ACTION_JUMP, {})
	var binding_container: HBoxContainer = jump_data.get("binding_container")
	assert_not_null(binding_container, "Jump action should have a binding container")
	if binding_container == null:
		return

	var has_gamepad_visual := _has_gamepad_binding_visual(binding_container)
	var has_keyboard_text := _has_keyboard_text(binding_container, "Space")
	assert_true(has_gamepad_visual, "Jump binding should display gamepad icon/label when device is gamepad")
	assert_false(has_keyboard_text, "Jump binding should NOT display keyboard 'Space' when device is gamepad")

func test_gamepad_device_shows_gamepad_motion_bindings_from_inputmap() -> void:
	_set_device_type_gamepad()

	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var action_rows: Dictionary = overlay._action_rows
	var move_data: Dictionary = action_rows.get(ACTION_MOVE_FWD, {})
	var binding_container: HBoxContainer = move_data.get("binding_container")
	assert_not_null(binding_container, "Move action should have a binding container")
	if binding_container == null:
		return

	var has_gamepad_visual := _has_gamepad_binding_visual(binding_container)
	var has_keyboard_text := _has_keyboard_text(binding_container, "W")
	assert_true(has_gamepad_visual, "Move binding should display gamepad icon when device is gamepad")
	assert_false(has_keyboard_text, "Move binding should NOT display keyboard 'W' when device is gamepad")

func test_keyboard_device_shows_keyboard_bindings_not_gamepad() -> void:
	# Device stays at default (keyboard/mouse).
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var action_rows: Dictionary = overlay._action_rows
	var jump_data: Dictionary = action_rows.get(ACTION_JUMP, {})
	var binding_container: HBoxContainer = jump_data.get("binding_container")
	assert_not_null(binding_container, "Jump action should have a binding container")
	if binding_container == null:
		return

	# Keyboard Space renders as a TextureRect (keyboard icon) or Label.
	# The key assertion is: no gamepad-specific icons should appear.
	var has_gamepad_icon := _has_gamepad_texture(binding_container)
	assert_false(has_gamepad_icon, "Jump binding should NOT display gamepad icons when device is keyboard")
	# Should have some visual (icon or label) for the keyboard binding.
	var child_count := _count_visual_children(binding_container)
	assert_gt(child_count, 0, "Jump binding should have at least one visual element for keyboard")

func test_refresh_bindings_switches_to_gamepad_after_device_change() -> void:
	# Start with keyboard device, then switch to gamepad and refresh.
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var action_rows: Dictionary = overlay._action_rows
	var jump_data: Dictionary = action_rows.get(ACTION_JUMP, {})
	var binding_container: HBoxContainer = jump_data.get("binding_container")
	assert_not_null(binding_container, "Jump action should have a binding container")
	if binding_container == null:
		return
	var has_keyboard_visual := _count_visual_children(binding_container) > 0
	assert_true(has_keyboard_visual, "Should show some binding initially")
	assert_false(_has_gamepad_texture(binding_container), "Should not show gamepad icons initially")

	# Switch to gamepad and refresh.
	_set_device_type_gamepad()
	overlay._refresh_bindings()
	await _pump()

	# Re-read binding container (children were queue_freed and recreated).
	jump_data = overlay._action_rows.get(ACTION_JUMP, {})
	binding_container = jump_data.get("binding_container")
	assert_not_null(binding_container, "Jump binding container should still exist after refresh")
	if binding_container == null:
		return

	var has_gamepad_visual := _has_gamepad_binding_visual(binding_container)
	assert_true(has_gamepad_visual, "After device switch to gamepad, jump should show gamepad binding")

func test_gamepad_sprint_shows_gamepad_binding_not_keyboard_fallback() -> void:
	# Sprint has keyboard in profile + gamepad in InputMap.
	# When device is gamepad, should show gamepad binding.
	_set_device_type_gamepad()

	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var action_rows: Dictionary = overlay._action_rows
	var sprint_data: Dictionary = action_rows.get(ACTION_SPRINT, {})
	var binding_container: HBoxContainer = sprint_data.get("binding_container")
	assert_not_null(binding_container, "Sprint action should have a binding container")
	if binding_container == null:
		return

	var has_gamepad_visual := _has_gamepad_binding_visual(binding_container)
	assert_true(has_gamepad_visual, "Sprint should show gamepad binding when device is gamepad")

# ── Helpers ────────────────────────────────────────────────────────────

func _set_device_type_gamepad() -> void:
	_store.dispatch(U_InputActions.device_changed(
		U_DeviceTypeConstants.DeviceType.GAMEPAD, 0, 0.0
	))

func _has_gamepad_binding_visual(container: HBoxContainer) -> bool:
	for child in container.get_children():
		if child is TextureRect and child.texture != null:
			var path: String = child.texture.resource_path
			if "gamepad" in path:
				return true
		if child is Label:
			var text: String = child.text.strip_edges()
			if "Joypad" in text or "Joystick" in text or "Trigger" in text or "Shoulder" in text:
				return true
	return false

func _has_keyboard_text(container: HBoxContainer, key_name: String) -> bool:
	for child in container.get_children():
		if child is Label:
			if key_name in child.text:
				return true
	return false

func _has_gamepad_texture(container: HBoxContainer) -> bool:
	for child in container.get_children():
		if child is TextureRect and child.texture != null:
			var path: String = child.texture.resource_path
			if "gamepad" in path:
				return true
	return false

func _count_visual_children(container: HBoxContainer) -> int:
	var count := 0
	for child in container.get_children():
		if child is TextureRect or child is Label:
			count += 1
	return count

func _pump() -> void:
	await get_tree().process_frame

# ── Test Doubles ───────────────────────────────────────────────────────

class GamepadFilterProfileStub extends I_InputProfileManager:
	## Profile stub that simulates mobile scenario: keyboard profile is "active"
	## but InputMap has both keyboard and gamepad events for each action.
	signal profile_switched(profile_id: String)
	signal bindings_reset()
	signal custom_binding_added(action: StringName, event: InputEvent)

	var active_profile: RS_InputProfile = RS_InputProfile.new()
	var custom_bindings: Dictionary = {}
	var _tracked_actions: Array[StringName] = []
	var _saved_events: Dictionary = {}  # action -> Array of original events to restore
	var store_ref: M_StateStore = null : set = set_store_ref
	var reset_call_count: int = 0
	var _unsubscribe: Callable = Callable()

	func _init() -> void:
		# Keyboard-only profile (device_type 0) — simulates the mobile bug scenario
		# where the "active" profile is keyboard but gamepad events exist in InputMap.
		active_profile.device_type = 0
		active_profile.set_events_for_action(StringName("jump"), _make_event_array(_make_key_event(Key.KEY_SPACE)))
		active_profile.set_events_for_action(StringName("move_forward"), _make_event_array(_make_key_event(Key.KEY_W)))
		active_profile.set_events_for_action(StringName("sprint"), _make_event_array(_make_key_event(Key.KEY_SHIFT)))

	func _ready() -> void:
		# Save original InputMap events so we can restore in teardown.
		for action_name in ["jump", "move_forward", "sprint"]:
			var action := StringName(action_name)
			if InputMap.has_action(action):
				_saved_events[action] = InputMap.action_get_events(action).duplicate()

		# Apply keyboard events from profile to InputMap.
		for key in active_profile.action_mappings.keys():
			var action: StringName = StringName(key)
			if action not in _tracked_actions:
				_tracked_actions.append(action)
			if not InputMap.has_action(action):
				InputMap.add_action(String(action))
			InputMap.action_erase_events(action)
			var events: Array[InputEvent] = active_profile.get_events_for_action(action)
			for ev in events:
				InputMap.action_add_event(action, ev.duplicate(true))

		# Also add GAMEPAD events to InputMap (simulating runtime where
		# gamepad profile events are also applied to InputMap).
		var joy_btn := InputEventJoypadButton.new()
		joy_btn.button_index = JOY_BUTTON_A
		InputMap.action_add_event(StringName("jump"), joy_btn)

		var joy_motion := InputEventJoypadMotion.new()
		joy_motion.axis = JOY_AXIS_LEFT_Y
		joy_motion.axis_value = -1.0
		InputMap.action_add_event(StringName("move_forward"), joy_motion)

		var sprint_btn := InputEventJoypadButton.new()
		sprint_btn.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event(StringName("sprint"), sprint_btn)

	func set_store_ref(value: M_StateStore) -> void:
		if store_ref == value:
			return
		store_ref = value

	func get_active_profile() -> RS_InputProfile:
		return active_profile

	func reset_action(_action: StringName) -> void:
		pass

	func reset_touchscreen_positions() -> Array[Dictionary]:
		return []

	func reset_to_defaults() -> void:
		reset_call_count += 1

	func _make_key_event(code: Key) -> InputEventKey:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		return ev

	func _make_event_array(event: InputEvent) -> Array[InputEvent]:
		var arr: Array[InputEvent] = []
		arr.append(event)
		return arr

	func teardown() -> void:
		if _unsubscribe != Callable() and _unsubscribe.is_valid():
			_unsubscribe.call()
			_unsubscribe = Callable()
		# Restore original InputMap events.
		for action in _saved_events.keys():
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
				for ev in _saved_events[action]:
					InputMap.action_add_event(action, ev)
		_saved_events.clear()
		_tracked_actions.clear()

class SceneManagerMock extends Node:
	var call_count: int = 0

	func pop_overlay() -> void:
		call_count += 1

	func transition_to_scene(_scene_id: StringName, _transition_type: String, _priority: int = 0) -> void:
		call_count += 1

class TestStateStore extends M_StateStore:
	var dispatched_actions: Array = []

	func dispatch(action: Dictionary) -> void:
		dispatched_actions.append(action.duplicate(true))
		super.dispatch(action)
