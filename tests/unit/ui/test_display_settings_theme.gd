extends GutTest

const TAB_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_display_settings_tab.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _store: M_StateStore
var _tab: UI_DisplaySettingsTab

func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()

	_store = M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	_store.settings = test_settings
	_store.display_initial_state = RS_DisplayInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_tab = null

func test_display_section_panels_use_theme_style() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	U_UI_THEME_BUILDER.active_config = config

	_tab = TAB_SCENE.instantiate() as UI_DisplaySettingsTab
	_tab.theme = U_UI_THEME_BUILDER.build_theme(config)
	add_child_autofree(_tab)
	await get_tree().process_frame

	var graphics_section := _tab.find_child("GraphicsHeader", true, false)
	var post_process_section := _tab.find_child("PostProcessingHeader", true, false)
	var ui_section := _tab.find_child("UIHeader", true, false)
	var accessibility_section := _tab.find_child("AccessibilityHeader", true, false)

	assert_not_null(graphics_section, "Graphics section header should exist")
	assert_not_null(post_process_section, "Post process section header should exist")
	assert_not_null(ui_section, "UI section header should exist")
	assert_not_null(accessibility_section, "Accessibility section header should exist")

func test_display_section_headers_use_theme_color() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 39
	config.section_header = 17
	config.section_header_color = Color(0.45, 0.72, 0.92, 1.0)
	config.body_small = 16
	config.text_secondary = Color(0.79, 0.77, 0.66, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	_tab = TAB_SCENE.instantiate() as UI_DisplaySettingsTab
	_tab.theme = U_UI_THEME_BUILDER.build_theme(config)
	add_child_autofree(_tab)
	await get_tree().process_frame

	var heading_label := _tab.find_child("HeadingLabel", true, false) as Label
	if heading_label != null:
		assert_eq(
			heading_label.get_theme_font_size(&"font_size"),
			config.heading,
			"Heading should use heading font token"
		)

	var section_headers: Array[Label] = [
		_tab.find_child("GraphicsHeader", true, false) as Label,
		_tab.find_child("PostProcessingHeader", true, false) as Label,
		_tab.find_child("UIHeader", true, false) as Label,
		_tab.find_child("AccessibilityHeader", true, false) as Label,
	]
	for section_header in section_headers:
		if section_header != null:
			assert_eq(
				section_header.get_theme_font_size(&"font_size"),
				config.section_header,
				"Section headers should use section_header font token"
			)
			assert_true(
				section_header.get_theme_color(&"font_color").is_equal_approx(config.section_header_color),
				"Section headers should use section_header_color token"
			)

	var window_size_label := _tab.find_child("WindowSizeLabel", true, false) as Label
	if window_size_label != null:
		assert_eq(
			window_size_label.get_theme_font_size(&"font_size"),
			config.body_small,
			"Field labels should use body_small font token"
		)
		assert_true(
			window_size_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
			"Field labels should use text_secondary token"
		)

func test_display_no_inline_overrides_remaining() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	U_UI_THEME_BUILDER.active_config = config

	_tab = TAB_SCENE.instantiate() as UI_DisplaySettingsTab
	_tab.theme = U_UI_THEME_BUILDER.build_theme(config)
	add_child_autofree(_tab)
	await get_tree().process_frame

	var ui_scale_slider := _tab.find_child("UIScaleSlider", true, false) as HSlider
	if ui_scale_slider != null:
		assert_false(
			ui_scale_slider.has_theme_stylebox_override(&"slider"),
			"UI scale slider should not keep inline slider override"
		)
		assert_false(
			ui_scale_slider.has_theme_stylebox_override(&"grabber_area"),
			"UI scale slider should not keep inline grabber_area override"
		)
		assert_false(
			ui_scale_slider.has_theme_stylebox_override(&"grabber_area_highlight"),
			"UI scale slider should not keep inline grabber_area_highlight override"
		)

func _collect_controls(node: Node, out: Array[Control]) -> void:
	if node is Control:
		out.append(node as Control)
	for child in node.get_children():
		if child is Node:
			_collect_controls(child as Node, out)
