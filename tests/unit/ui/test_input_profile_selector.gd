extends GutTest

## Regression test for InputProfileSelector navigation.
##
## Expected: Pressing ui_left/ui_right while ProfileButton is focused cycles profiles immediately.

const INPUT_PROFILE_SELECTOR_SCENE := preload("res://scenes/ui/overlays/ui_input_profile_selector.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/resources/ui/rs_ui_theme_config.gd")

class MockInputProfileManager:
	extends I_InputProfileManager

	signal profile_switched(profile_id: String)

	func get_active_profile() -> RS_InputProfile:
		return null

	func reset_to_defaults() -> void:
		pass

	func reset_action(_action: StringName) -> void:
		pass

	func reset_touchscreen_positions() -> Array[Dictionary]:
		return []

	func get_available_profile_ids() -> Array[String]:
		return ["profile_a", "profile_b", "profile_c"]

	func switch_profile(profile_id: String) -> void:
		profile_switched.emit(profile_id)

var _manager: Node
var _store: M_StateStore

func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.boot_initial_state = RS_BootInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)

	_manager = MockInputProfileManager.new()
	add_child_autofree(_manager)
	U_ServiceLocator.register(StringName("input_profile_manager"), _manager)
	await get_tree().process_frame

func after_each() -> void:
	U_ServiceLocator.clear()
	U_UI_THEME_BUILDER.active_config = null

func test_input_profile_selector_has_motion_and_theme_tokens_when_active_config_set() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 36
	config.subheading = 26
	config.body_small = 17
	config.section_header = 15
	config.margin_section = 19
	config.separation_default = 13
	config.separation_compact = 7
	config.bg_base = Color(0.1, 0.14, 0.2, 1.0)
	config.text_secondary = Color(0.78, 0.83, 0.9, 1.0)
	config.text_disabled = Color(0.55, 0.6, 0.68, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	var overlay := INPUT_PROFILE_SELECTOR_SCENE.instantiate() as Control
	add_child_autofree(overlay)
	await wait_process_frames(4)

	var motion_set: Variant = overlay.get("motion_set")
	assert_not_null(motion_set, "Input profile selector should assign enter/exit motion set")
	if motion_set != null:
		assert_true("enter" in motion_set, "Motion set should expose enter presets")
		assert_true("exit" in motion_set, "Motion set should expose exit presets")

	var heading_label := overlay.get_node_or_null("%HeadingLabel") as Label
	var header_label := overlay.get_node_or_null("%HeaderLabel") as Label
	var description_label := overlay.get_node_or_null("%DescriptionLabel") as Label
	var panel_padding := overlay.get_node_or_null("%MainPanelPadding") as MarginContainer
	var profile_row := overlay.get_node_or_null("%ProfileRow") as HBoxContainer
	var button_row := overlay.get_node_or_null("%ButtonRow") as HBoxContainer
	var overlay_background := overlay.get_node_or_null("OverlayBackground") as ColorRect
	var expected_dim := config.bg_base
	expected_dim.a = 0.5

	assert_not_null(heading_label, "HeadingLabel should exist")
	assert_not_null(header_label, "HeaderLabel should exist")
	assert_not_null(description_label, "DescriptionLabel should exist")
	assert_not_null(panel_padding, "MainPanelPadding should exist")
	assert_not_null(profile_row, "ProfileRow should exist")
	assert_not_null(button_row, "ButtonRow should exist")
	assert_not_null(overlay_background, "OverlayBackground should exist")

	if heading_label != null:
		assert_eq(heading_label.get_theme_font_size(&"font_size"), 36, "Heading should use heading token")
	if header_label != null:
		assert_eq(header_label.get_theme_font_size(&"font_size"), 26, "Header should use subheading token")
	if description_label != null:
		assert_eq(description_label.get_theme_font_size(&"font_size"), 17, "Description should use body_small token")
		assert_true(
			description_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
			"Description should use text_secondary token"
		)
	if panel_padding != null:
		assert_eq(panel_padding.get_theme_constant(&"margin_left"), 19, "Panel padding should use margin_section token")
	if profile_row != null:
		assert_eq(profile_row.get_theme_constant(&"separation"), 13, "Profile row should use separation_default token")
	if button_row != null:
		assert_eq(button_row.get_theme_constant(&"separation"), 7, "Button row should use separation_compact token")
	if overlay_background != null:
		assert_true(
			overlay_background.color.is_equal_approx(expected_dim),
			"Overlay dim should use bg_base at 0.5 alpha"
		)

func test_ui_right_cycles_profile_when_profile_button_focused() -> void:
	var overlay := INPUT_PROFILE_SELECTOR_SCENE.instantiate() as Control
	add_child_autofree(overlay)
	await wait_process_frames(4)

	var profile_button := overlay.get_node_or_null("%ProfileButton") as Button
	assert_not_null(profile_button, "ProfileButton must exist")

	profile_button.grab_focus()
	await get_tree().process_frame

	var initial_text := profile_button.text
	assert_true(not initial_text.is_empty(), "ProfileButton should have initial profile text")

	var right_event := InputEventAction.new()
	right_event.action = "ui_right"
	right_event.pressed = true

	overlay._unhandled_input(right_event)
	await get_tree().process_frame

	assert_ne(profile_button.text, initial_text,
		"ui_right should cycle profile without requiring ui_accept")
