extends GutTest

const OverlayScene := preload("res://scenes/ui/overlays/ui_gamepad_settings_overlay.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _store: TestStateStore

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null
	_store = TestStateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	await _pump()
	await _pump()

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null
	_store = null

func test_gamepad_settings_overlay_has_motion_and_theme_tokens_when_active_config_set() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 38
	config.section_header = 16
	config.body_small = 14
	config.margin_section = 23
	config.separation_compact = 9
	config.bg_base = Color(0.13, 0.17, 0.22, 1.0)
	config.text_secondary = Color(0.72, 0.79, 0.87, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var motion_set: Variant = overlay.get("motion_set")
	assert_not_null(motion_set, "Gamepad settings overlay should assign enter/exit motion set")
	if motion_set != null:
		assert_true("enter" in motion_set, "Motion set should expose enter presets")
		assert_true("exit" in motion_set, "Motion set should expose exit presets")

	var heading_label := overlay.get_node_or_null("%HeadingLabel") as Label
	var left_text_label := overlay.get_node_or_null("%LeftLabel") as Label
	var left_value_label := overlay.get_node_or_null("%LeftDeadzoneValue") as Label
	var main_panel := overlay.get_node_or_null("%MainPanel") as PanelContainer
	var preview_panel := overlay.get_node_or_null("%PreviewPanel") as PanelContainer
	var panel_padding := overlay.get_node_or_null("%MainPanelPadding") as MarginContainer
	var left_row := overlay.get_node_or_null("%LeftRow") as HBoxContainer
	var button_row := overlay.get_node_or_null("%ButtonRow") as HBoxContainer
	var overlay_background := overlay.get_node_or_null("OverlayBackground") as ColorRect
	var expected_dim := config.bg_base
	expected_dim.a = 0.5

	assert_not_null(heading_label, "HeadingLabel should exist")
	assert_not_null(left_text_label, "LeftLabel should exist")
	assert_not_null(left_value_label, "LeftDeadzoneValue should exist")
	assert_not_null(main_panel, "MainPanel should exist")
	assert_not_null(preview_panel, "PreviewPanel should exist")
	assert_not_null(panel_padding, "MainPanelPadding should exist")
	assert_not_null(left_row, "LeftRow should exist")
	assert_not_null(button_row, "ButtonRow should exist")
	assert_not_null(overlay_background, "OverlayBackground should exist")

	if heading_label != null:
		assert_eq(heading_label.get_theme_font_size(&"font_size"), 38, "Heading should use heading token")
	if left_text_label != null:
		assert_eq(left_text_label.get_theme_font_size(&"font_size"), 16, "Row labels should use section_header token")
	if left_value_label != null:
		assert_eq(left_value_label.get_theme_font_size(&"font_size"), 14, "Slider values should use body_small token")
		assert_true(
			left_value_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
			"Slider values should use text_secondary token"
		)
	if main_panel != null:
		assert_true(main_panel.has_theme_stylebox_override(&"panel"), "Main panel should use themed panel style")
	if preview_panel != null:
		assert_true(preview_panel.has_theme_stylebox_override(&"panel"), "Preview panel should use themed panel style")
	if panel_padding != null:
		assert_eq(panel_padding.get_theme_constant(&"margin_left"), 23, "Panel padding should use margin_section token")
	if left_row != null:
		assert_eq(left_row.get_theme_constant(&"separation"), 9, "Rows should use separation_compact token")
	if button_row != null:
		assert_eq(button_row.get_theme_constant(&"separation"), 9, "Button row should use separation_compact token")
	if overlay_background != null:
		assert_true(
			overlay_background.color.is_equal_approx(expected_dim),
			"Overlay dim should use bg_base at 0.5 alpha"
		)

func test_overlay_populates_values_from_store() -> void:
	_store.dispatch(U_InputActions.update_gamepad_deadzone("left", 0.45))
	_store.dispatch(U_InputActions.update_gamepad_deadzone("right", 0.35))
	_store.dispatch(U_InputActions.toggle_vibration(false))
	_store.dispatch(U_InputActions.set_vibration_intensity(0.5))
	_store.dispatch(U_InputActions.update_gamepad_sensitivity(1.8))
	await _pump()

	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)
	assert_not_null(overlay.get("_store"), "Overlay should locate M_StateStore")
	assert_eq(overlay.get("_store"), _store, "Overlay should use the active store instance")

	var left_slider: HSlider = overlay.get_node("%LeftDeadzoneSlider")
	var right_slider: HSlider = overlay.get_node("%RightDeadzoneSlider")
	var right_sensitivity_slider: HSlider = overlay.get_node("%RightSensitivitySlider")
	var vibration_checkbox: CheckButton = overlay.get_node("%VibrationCheck")
	var vibration_slider: HSlider = overlay.get_node("%VibrationSlider")

	assert_almost_eq(left_slider.value, 0.45, 0.001)
	assert_almost_eq(right_slider.value, 0.35, 0.001)
	assert_almost_eq(right_sensitivity_slider.value, 1.8, 0.001)
	assert_false(vibration_checkbox.button_pressed)
	assert_almost_eq(vibration_slider.value, 0.5, 0.001)

func test_apply_updates_state_settings() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)
	assert_not_null(overlay.get("_store"), "Overlay should locate M_StateStore")
	assert_eq(overlay.get("_store"), _store, "Overlay should use the active store instance")

	var left_slider: HSlider = overlay.get_node("%LeftDeadzoneSlider")
	left_slider.value = 0.6
	var right_slider: HSlider = overlay.get_node("%RightDeadzoneSlider")
	right_slider.value = 0.1
	var right_sensitivity_slider: HSlider = overlay.get_node("%RightSensitivitySlider")
	right_sensitivity_slider.value = 2.4
	var vibration_checkbox: CheckButton = overlay.get_node("%VibrationCheck")
	vibration_checkbox.button_pressed = false
	var vibration_slider: HSlider = overlay.get_node("%VibrationSlider")
	vibration_slider.value = 0.25

	_store.dispatched_actions.clear()
	var close_before := _count_navigation_close_or_return_actions()
	overlay.call("_on_apply_pressed")
	await _pump()
	await _pump()

	assert_eq(_store.dispatched_actions.size(), 6, "Overlay should dispatch five input actions plus one navigation close action")
	var close_after := _count_navigation_close_or_return_actions()
	assert_eq(close_after, close_before + 1, "Apply should dispatch a single navigation close/navigation return action")

	var state: Dictionary = _store.get_state()
	var input_settings: Dictionary = (state.get("settings", {}) as Dictionary).get("input_settings", {})
	var gamepad_settings: Dictionary = input_settings.get("gamepad_settings", {})
	assert_almost_eq(float(gamepad_settings.get("right_stick_sensitivity", 0.0)), 2.4, 0.001)

func test_vibration_toggle_does_not_use_expand_fill_layout() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var vibration_checkbox := overlay.get_node_or_null("%VibrationCheck") as CheckButton
	assert_not_null(vibration_checkbox, "VibrationCheck should exist")
	if vibration_checkbox != null:
		assert_ne(
			vibration_checkbox.size_flags_horizontal,
			Control.SIZE_EXPAND_FILL,
			"Vibration toggle should not stretch across the full row"
		)

func test_overlay_layout_remains_compact_after_adding_sensitivity_row() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var motion_host := overlay.get_node_or_null("%MainPanelMotionHost") as Control
	assert_not_null(motion_host, "MainPanelMotionHost should exist")
	if motion_host != null:
		assert_lte(
			motion_host.custom_minimum_size.y,
			540.0,
			"Gamepad settings panel should stay compact enough to avoid forcing scroll"
		)

func _pump() -> void:
	await get_tree().process_frame

func _refresh_overlay_state(overlay: Node) -> void:
	if overlay == null:
		return
	overlay.call("_on_state_changed", {}, _store.get_state())
	await _pump()

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
