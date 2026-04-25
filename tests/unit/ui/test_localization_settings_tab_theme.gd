extends GutTest

const TAB_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_localization_settings_tab.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _store: M_StateStore
var _tab: UI_LocalizationSettingsTab

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
	_store.localization_initial_state = RS_LocalizationInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_tab = null

func test_localization_settings_tab_applies_theme_tokens_when_active_config_set() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 41
	config.section_header = 19
	config.body_small = 17
	config.separation_default = 18
	config.separation_compact = 6
	config.section_header_color = Color(0.42, 0.68, 0.93, 1.0)
	config.text_secondary = Color(0.81, 0.77, 0.62, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	_tab = TAB_SCENE.instantiate() as UI_LocalizationSettingsTab
	add_child_autofree(_tab)
	await get_tree().process_frame

	assert_eq(
		_tab.get_theme_constant(&"separation"),
		config.separation_default,
		"Tab root separation should use separation_default token"
	)

	var language_row := _tab.get_node_or_null("LanguageRow") as HBoxContainer
	var dyslexia_row := _tab.get_node_or_null("DyslexiaRow") as HBoxContainer
	var button_row := _tab.get_node_or_null("ButtonRow") as HBoxContainer
	assert_not_null(language_row, "Language row should exist")
	assert_not_null(dyslexia_row, "Dyslexia row should exist")
	assert_not_null(button_row, "Button row should exist")

	if language_row != null:
		assert_eq(
			language_row.get_theme_constant(&"separation"),
			config.separation_default,
			"Language row separation should use separation_default token"
		)
	if dyslexia_row != null:
		assert_eq(
			dyslexia_row.get_theme_constant(&"separation"),
			config.separation_default,
			"Dyslexia row separation should use separation_default token"
		)
	if button_row != null:
		assert_eq(
			button_row.get_theme_constant(&"separation"),
			config.separation_compact,
			"Button row separation should use separation_compact token"
		)

	assert_eq(
		_tab._heading_label.get_theme_font_size(&"font_size"),
		config.heading,
		"Heading should use heading font token"
	)
	assert_eq(
		_tab._language_section_label.get_theme_font_size(&"font_size"),
		config.section_header,
		"Language section label should use section_header font token"
	)
	assert_true(
		_tab._language_section_label.get_theme_color(&"font_color").is_equal_approx(config.section_header_color),
		"Language section label should use section_header_color token"
	)
	assert_eq(
		_tab._accessibility_section_label.get_theme_font_size(&"font_size"),
		config.section_header,
		"Accessibility section label should use section_header font token"
	)
	assert_true(
		_tab._accessibility_section_label.get_theme_color(&"font_color").is_equal_approx(config.section_header_color),
		"Accessibility section label should use section_header_color token"
	)

	assert_eq(
		_tab._language_label.get_theme_font_size(&"font_size"),
		config.body_small,
		"Language label should use body_small font token"
	)
	assert_true(
		_tab._language_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
		"Language label should use text_secondary color token"
	)
	assert_eq(
		_tab._dyslexia_label.get_theme_font_size(&"font_size"),
		config.body_small,
		"Dyslexia label should use body_small font token"
	)
	assert_true(
		_tab._dyslexia_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
		"Dyslexia label should use text_secondary color token"
	)

	assert_eq(
		_tab._language_option.get_theme_font_size(&"font_size"),
		config.section_header,
		"Language option should use section_header font token"
	)
	assert_eq(
		_tab._dyslexia_toggle.get_theme_font_size(&"font_size"),
		config.section_header,
		"Dyslexia toggle should use section_header font token"
	)
	assert_eq(
		_tab._cancel_button.get_theme_font_size(&"font_size"),
		config.section_header,
		"Cancel button should use section_header font token"
	)
	assert_eq(
		_tab._reset_button.get_theme_font_size(&"font_size"),
		config.section_header,
		"Reset button should use section_header font token"
	)
	assert_eq(
		_tab._apply_button.get_theme_font_size(&"font_size"),
		config.section_header,
		"Apply button should use section_header font token"
	)
