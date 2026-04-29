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

	var heading_label := _tab.find_child("HeadingLabel", true, false) as Label
	var language_section := _tab.find_child("Section", true, false) as VBoxContainer
	var language_option := _tab.find_child("LanguageOption", true, false) as OptionButton
	var action_buttons := _tab.find_child("ActionButtons", true, false) as HBoxContainer
	
	var language_section_header: Label = null
	var language_label: Label = null
	if language_section != null:
		language_section_header = language_section.find_child("SectionHeader", true, false) as Label
		language_label = language_section.find_child("LanguageLabel", true, false) as Label

	assert_not_null(heading_label, "Heading label should exist")
	assert_not_null(language_section, "Language section should exist")
	assert_not_null(language_option, "Language option should exist")
	assert_not_null(action_buttons, "Action buttons row should exist")

	var setting_rows := _find_setting_rows(_tab)
	assert_true(setting_rows.size() >= 1, "Should have at least 1 setting row")
	for row in setting_rows:
		assert_eq(
			row.get_theme_constant(&"separation"),
			config.separation_default,
			"Setting row separation should use separation_default token"
		)

	if action_buttons != null:
		assert_eq(
			action_buttons.get_theme_constant(&"separation"),
			config.separation_compact,
			"Action buttons row separation should use separation_compact token"
		)

	if heading_label != null:
		assert_eq(
			heading_label.get_theme_font_size(&"font_size"),
			config.heading,
			"Heading should use heading font token"
		)
	if language_section_header != null:
		assert_eq(
			language_section_header.get_theme_font_size(&"font_size"),
			config.section_header,
			"Language section header should use section_header font token"
		)
		assert_true(
			language_section_header.get_theme_color(&"font_color").is_equal_approx(config.section_header_color),
			"Language section header should use section_header_color token"
		)

	if language_label != null:
		assert_eq(
			language_label.get_theme_font_size(&"font_size"),
			config.body_small,
			"Language label should use body_small font token"
		)
		assert_true(
			language_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
			"Language label should use text_secondary color token"
		)

	if language_option != null:
		assert_eq(
			language_option.get_theme_font_size(&"font_size"),
			config.section_header,
			"Language option should use section_header font token"
		)

	var test_button := _tab.find_child("TestLocalizationButton", true, false) as Button
	if test_button != null:
		assert_eq(
			test_button.get_theme_font_size(&"font_size"),
			config.section_header,
			"Test button should use section_header font token"
		)

func _find_setting_rows(root: Node) -> Array[HBoxContainer]:
	var rows: Array[HBoxContainer] = []
	for child in root.get_children():
		if child is HBoxContainer and child.name == "SettingRow":
			rows.append(child as HBoxContainer)
		else:
			rows.append_array(_find_setting_rows(child))
	return rows
