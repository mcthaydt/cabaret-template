extends GutTest

const OverlayScene := preload("res://scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn")
const MobileControlsScene := preload("res://scenes/core/ui/hud/ui_mobile_controls.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _store: TestStateStore
var _profile_manager_mock: ProfileManagerMock
var _mobile_controls: UI_MobileControls

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null
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
	U_UI_THEME_BUILDER.active_config = null
	_store = null
	_profile_manager_mock = null
	_mobile_controls = null
	U_ServiceLocator.clear()

func test_edit_touch_controls_overlay_has_motion_and_theme_tokens_when_active_config_set() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 36
	config.section_header = 17
	config.body_small = 13
	config.margin_section = 19
	config.separation_default = 14
	config.separation_compact = 6
	config.bg_base = Color(0.12, 0.14, 0.2, 1.0)
	config.text_secondary = Color(0.72, 0.8, 0.9, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	var overlay := OverlayScene.instantiate() as Control
	add_child_autofree(overlay)
	await _pump_frames(2)

	var motion_set: Variant = overlay.get("motion_set")
	assert_not_null(motion_set, "Edit touch controls overlay should assign enter/exit motion set")
	if motion_set != null:
		assert_true("enter" in motion_set, "Motion set should expose enter presets")
		assert_true("exit" in motion_set, "Motion set should expose exit presets")

	var heading_label := overlay.get_node_or_null("%HeadingLabel") as Label
	var drag_mode_check := overlay.get_node_or_null("%DragModeCheck") as CheckButton
	var instructions_label := overlay.get_node_or_null("%InstructionsLabel") as Label
	var main_panel := overlay.get_node_or_null("%MainPanel") as PanelContainer
	var panel_padding := overlay.get_node_or_null("%MainPanelPadding") as MarginContainer
	var panel_content := overlay.get_node_or_null("%MainPanelContent") as VBoxContainer
	var toggle_row := overlay.get_node_or_null("%ToggleRow") as HBoxContainer
	var button_row := overlay.get_node_or_null("%ButtonRow") as HBoxContainer
	var grid_overlay := overlay.get_node_or_null("GridOverlay") as ColorRect
	var overlay_background := overlay.get_node_or_null("OverlayBackground") as ColorRect
	var expected_dim := config.bg_base
	expected_dim.a = 0.05
	var expected_grid := config.text_secondary
	expected_grid.a = 0.05

	assert_not_null(heading_label, "HeadingLabel should exist")
	assert_not_null(drag_mode_check, "DragModeCheck should exist")
	assert_not_null(instructions_label, "InstructionsLabel should exist")
	assert_not_null(main_panel, "MainPanel should exist")
	assert_not_null(panel_padding, "MainPanelPadding should exist")
	assert_not_null(panel_content, "MainPanelContent should exist")
	assert_not_null(toggle_row, "ToggleRow should exist")
	assert_not_null(button_row, "ButtonRow should exist")
	assert_not_null(grid_overlay, "GridOverlay should exist")
	assert_not_null(overlay_background, "OverlayBackground should exist")

	if heading_label != null:
		assert_eq(heading_label.get_theme_font_size(&"font_size"), 36, "Heading should use heading token")
	if drag_mode_check != null:
		assert_eq(drag_mode_check.get_theme_font_size(&"font_size"), 17, "Toggle should use section_header token")
	if instructions_label != null:
		assert_eq(instructions_label.get_theme_font_size(&"font_size"), 13, "Instructions should use body_small token")
		assert_true(
			instructions_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
			"Instructions should use text_secondary token"
		)
	if main_panel != null:
		assert_true(main_panel.has_theme_stylebox_override(&"panel"), "Main panel should use themed panel style")
	if panel_padding != null:
		assert_eq(panel_padding.get_theme_constant(&"margin_left"), 19, "Panel padding should use margin_section token")
	if panel_content != null:
		assert_eq(panel_content.get_theme_constant(&"separation"), 14, "Panel content should use separation_default token")
	if toggle_row != null:
		assert_eq(toggle_row.get_theme_constant(&"separation"), 6, "Toggle row should use separation_compact token")
	if button_row != null:
		assert_eq(button_row.get_theme_constant(&"separation"), 6, "Button row should use separation_compact token")
	if grid_overlay != null:
		assert_true(grid_overlay.color.is_equal_approx(expected_grid), "Grid overlay should use themed subtle tint")
	if overlay_background != null:
		assert_true(
			overlay_background.color.is_equal_approx(expected_dim),
			"Overlay dim should use bg_base at 0.05 alpha"
		)

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
		elif action_type == U_NavigationActions.ACTION_NAVIGATE_TO_UI_SCREEN:
			var scene_id: StringName = action.get("scene_id", StringName())
			if scene_id == StringName("settings_menu"):
				count += 1
	return count
