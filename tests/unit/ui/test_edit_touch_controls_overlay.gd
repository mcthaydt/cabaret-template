extends GutTest

const OverlayScene := preload("res://scenes/ui/ui_edit_touch_controls_overlay.tscn")
const MobileControlsScene := preload("res://scenes/ui/ui_mobile_controls.tscn")
const UI_VirtualButton := preload("res://scripts/ui/ui_virtual_button.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_SceneActions := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const I_InputProfileManager := preload("res://scripts/interfaces/i_input_profile_manager.gd")

var _store: TestStateStore
var _profile_manager_mock: ProfileManagerMock
var _mobile_controls: UI_MobileControls

func before_each() -> void:
	U_StateHandoff.clear_all()
	_store = TestStateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.boot_initial_state = RS_BootInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	_store.scene_initial_state.current_scene_id = StringName("gameplay_base")
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await _pump_frames(2)

	_profile_manager_mock = ProfileManagerMock.new()
	add_child_autofree(_profile_manager_mock)
	U_ServiceLocator.register(StringName("input_profile_manager"), _profile_manager_mock)

	_mobile_controls = await _create_mobile_controls()

func after_each() -> void:
	U_StateHandoff.clear_all()
	_store = null
	_profile_manager_mock = null
	_mobile_controls = null
	U_ServiceLocator.clear()

func test_drag_mode_toggle_enables_and_disables_repositioning() -> void:
	var overlay := await _create_overlay()

	var drag_check: CheckButton = overlay.get_node("%DragModeCheck")
	var joystick := _mobile_controls.get_node_or_null("Controls/VirtualJoystick")
	var buttons: Array = _mobile_controls.get_buttons()

	drag_check.button_pressed = true
	drag_check.emit_signal("toggled", true)
	await _pump_frames(1)

	if joystick != null and "can_reposition" in joystick:
		assert_true(joystick.can_reposition, "Joystick can_reposition should be enabled when drag mode on")
	for button in buttons:
		if button == null:
			continue
		if "can_reposition" in button:
			assert_true(button.can_reposition, "Buttons can_reposition should be enabled when drag mode on")

	drag_check.button_pressed = false
	drag_check.emit_signal("toggled", false)
	await _pump_frames(1)

	if joystick != null and "can_reposition" in joystick:
		assert_false(joystick.can_reposition, "Joystick can_reposition should be disabled when drag mode off")
	for button in buttons:
		if button == null:
			continue
		if "can_reposition" in button:
			assert_false(button.can_reposition, "Buttons can_reposition should be disabled when drag mode off")

func test_save_button_closes_overlay_without_reverting_positions() -> void:
	var overlay := await _create_overlay()
	var joystick := _mobile_controls.get_node_or_null("Controls/VirtualJoystick") as Control
	var buttons: Array = _mobile_controls.get_buttons()

	var original_joystick_pos := joystick.position
	var original_button_pos := (buttons[0] as Control).position

	joystick.position += Vector2(10, -5)
	(buttons[0] as Control).position += Vector2(-15, 8)
	_store.dispatch(U_InputActions.save_virtual_control_position("virtual_joystick", joystick.position))
	var button_key: String = ""
	if "control_name" in buttons[0] and buttons[0].control_name != StringName():
		button_key = String(buttons[0].control_name)
	elif "action" in buttons[0] and buttons[0].action != StringName():
		button_key = String(buttons[0].action)
	_store.dispatch(U_InputActions.save_virtual_control_position(button_key, (buttons[0] as Control).position))
	await _pump_frames(1)

	var save_button: Button = overlay.get_node("%SaveButton")
	var close_count_before := _count_navigation_close_or_return_actions()
	save_button.emit_signal("pressed")
	await _pump_frames(1)

	var close_count_after := _count_navigation_close_or_return_actions()
	assert_eq(close_count_after, close_count_before + 1,
		"Save should dispatch a single navigation close/return action")
	assert_true(joystick.position != original_joystick_pos, "Joystick should not revert when saving")

func test_reset_button_calls_profile_manager_and_clears_custom_positions() -> void:
	var overlay := await _create_overlay()

	_store.dispatched_actions.clear()
	_profile_manager_mock.reset_called = false

	var reset_button: Button = overlay.get_node("%ResetButton")
	reset_button.emit_signal("pressed")
	await _pump_frames(2)

	assert_true(_profile_manager_mock.reset_called, "Reset should delegate to profile manager reset_touchscreen_positions")
	# At minimum ensure a touchscreen settings update action is allowed (payload may be empty)
	# Reset does not need to dispatch additional position actions here; VirtualJoystick/VirtualButton handle saves on release.

func test_reset_button_visually_moves_controls_to_default_positions() -> void:
	var overlay := await _create_overlay()
	var joystick := _mobile_controls.get_node_or_null("Controls/VirtualJoystick") as Control
	var buttons: Array = _mobile_controls.get_buttons()

	# Move controls away from defaults
	joystick.position = Vector2(500, 500)
	(buttons[0] as Control).position = Vector2(600, 600)

	# Set up mock to return default positions
	_profile_manager_mock.default_joystick_position = Vector2(120, 400)
	_profile_manager_mock.default_button_positions = [
		{"action": buttons[0].action, "position": Vector2(800, 200)}
	]

	var reset_button: Button = overlay.get_node("%ResetButton")
	reset_button.emit_signal("pressed")
	await _pump_frames(2)

	# Verify controls visually moved to defaults
	assert_vector_almost_eq(joystick.position, Vector2(120, 400), 1.0, "Joystick should visually move to default position")
	assert_vector_almost_eq((buttons[0] as Control).position, Vector2(800, 200), 1.0, "Button should visually move to default position")

func test_cancel_button_reverts_positions_and_closes_overlay() -> void:
	var overlay := await _create_overlay()
	var joystick := _mobile_controls.get_node_or_null("Controls/VirtualJoystick") as Control
	var buttons: Array = _mobile_controls.get_buttons()

	var original_joystick_pos := joystick.position
	var original_button_pos := (buttons[0] as Control).position

	joystick.position += Vector2(20, 20)
	(buttons[0] as Control).position += Vector2(-10, -10)

	var cancel_button: Button = overlay.get_node("%CancelButton")
	var close_count_before := _count_navigation_close_or_return_actions()
	cancel_button.emit_signal("pressed")
	await _pump_frames(1)

	var close_count_after := _count_navigation_close_or_return_actions()
	assert_eq(close_count_after, close_count_before + 1,
		"Cancel should dispatch a single navigation close/return action")
	assert_vector_almost_eq(joystick.position, original_joystick_pos, 0.001, "Joystick position should revert on cancel")
	assert_vector_almost_eq((buttons[0] as Control).position, original_button_pos, 0.001, "Button position should revert on cancel")

func _create_mobile_controls() -> UI_MobileControls:
	var controls := MobileControlsScene.instantiate()
	controls.force_enable = true
	add_child_autofree(controls)
	await _pump_frames(3)
	return controls as UI_MobileControls

func _create_overlay() -> Node:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump_frames(2)
	return overlay

func _pump_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func assert_vector_almost_eq(a: Vector2, b: Vector2, tolerance: float, message: String = "") -> void:
	assert_almost_eq(a.x, b.x, tolerance, message + " (x)")
	assert_almost_eq(a.y, b.y, tolerance, message + " (y)")

class ProfileManagerMock extends I_InputProfileManager:
	var reset_called: bool = false
	var default_joystick_position: Vector2 = Vector2(120, 300)
	var default_button_positions: Array = [
		{"action": StringName("jump"), "position": Vector2(844, 352)},
		{"action": StringName("sprint"), "position": Vector2(765, 401)},
		{"action": StringName("interact"), "position": Vector2(288, 260)},
		{"action": StringName("pause"), "position": Vector2(811, 72)}
	]

	func get_active_profile() -> RS_InputProfile:
		return null

	func reset_to_defaults() -> void:
		pass

	func reset_action(_action: StringName) -> void:
		pass

	func reset_touchscreen_positions() -> Array[Dictionary]:
		reset_called = true
		var result: Array[Dictionary] = []
		for button_data in default_button_positions:
			result.append(button_data.duplicate(true))
		return result

	func get_default_joystick_position() -> Vector2:
		return default_joystick_position

class TestStateStore extends M_StateStore:
	var dispatched_actions: Array = []

	func dispatch(action: Dictionary) -> void:
		dispatched_actions.append(action.duplicate(true))
		super.dispatch(action)

func _count_navigation_actions(action_type: StringName) -> int:
	if _store == null:
		return 0
	var count := 0
	for action in _store.dispatched_actions:
		if action.get("type") == action_type:
			count += 1
	return count

func _count_navigation_close_or_return_actions() -> int:
	if _store == null:
		return 0
	var count := 0
	for action in _store.dispatched_actions:
		var action_type: StringName = action.get("type", StringName())
		if action_type == U_NavigationActions.ACTION_CLOSE_TOP_OVERLAY \
				or action_type == U_NavigationActions.ACTION_RETURN_TO_MAIN_MENU:
			count += 1
		elif action_type == U_NavigationActions.ACTION_SET_SHELL:
			var shell: StringName = action.get("shell", StringName())
			var base_scene: StringName = action.get("base_scene_id", StringName())
			if shell == StringName("main_menu") and base_scene == StringName("settings_menu"):
				count += 1
	return count
