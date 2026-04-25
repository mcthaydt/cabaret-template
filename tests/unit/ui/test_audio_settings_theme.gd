extends GutTest

const TAB_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_audio_settings_tab.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _store: M_StateStore
var _tab: UI_AudioSettingsTab

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
	_store.audio_initial_state = RS_AudioInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_tab = null

func test_audio_sliders_use_theme_styles() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	U_UI_THEME_BUILDER.active_config = config

	_tab = TAB_SCENE.instantiate() as UI_AudioSettingsTab
	_tab.theme = U_UI_THEME_BUILDER.build_theme(config)
	add_child_autofree(_tab)
	await get_tree().process_frame

	var sliders: Array[HSlider] = [
		_tab._master_volume_slider,
		_tab._music_volume_slider,
		_tab._sfx_volume_slider,
		_tab._ambient_volume_slider,
	]
	for slider in sliders:
		assert_true(
			slider.get_theme_stylebox(&"slider") is StyleBoxFlat,
			"Slider track should come from theme styleboxes"
		)
		assert_true(
			slider.get_theme_stylebox(&"grabber_area") is StyleBoxFlat,
			"Slider grabber area should come from theme styleboxes"
		)
		assert_true(
			slider.get_theme_stylebox(&"grabber_area_highlight") is StyleBoxFlat,
			"Slider highlighted grabber area should come from theme styleboxes"
		)

func test_audio_sliders_no_inline_overrides() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	U_UI_THEME_BUILDER.active_config = config

	_tab = TAB_SCENE.instantiate() as UI_AudioSettingsTab
	_tab.theme = U_UI_THEME_BUILDER.build_theme(config)
	add_child_autofree(_tab)
	await get_tree().process_frame

	var sliders: Array[HSlider] = [
		_tab._master_volume_slider,
		_tab._music_volume_slider,
		_tab._sfx_volume_slider,
		_tab._ambient_volume_slider,
	]
	for slider in sliders:
		assert_false(slider.has_theme_stylebox_override(&"slider"), "Slider should not keep inline slider override")
		assert_false(slider.has_theme_stylebox_override(&"grabber_area"), "Slider should not keep inline grabber_area override")
		assert_false(slider.has_theme_stylebox_override(&"grabber_area_highlight"), "Slider should not keep inline grabber_area_highlight override")

func test_audio_settings_tab_applies_row_separation_tokens_when_active_config_set() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 40
	config.section_header = 18
	config.body_small = 17
	config.separation_default = 19
	config.separation_compact = 7
	config.text_secondary = Color(0.81, 0.77, 0.62, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	_tab = TAB_SCENE.instantiate() as UI_AudioSettingsTab
	_tab.theme = U_UI_THEME_BUILDER.build_theme(config)
	add_child_autofree(_tab)
	await get_tree().process_frame

	assert_eq(
		_tab.get_theme_constant(&"separation"),
		config.separation_default,
		"Tab root separation should use separation_default token"
	)

	var master_row := _tab.get_node_or_null("MasterRow") as HBoxContainer
	var music_row := _tab.get_node_or_null("MusicRow") as HBoxContainer
	var sfx_row := _tab.get_node_or_null("SFXRow") as HBoxContainer
	var ambient_row := _tab.get_node_or_null("AmbientRow") as HBoxContainer
	var button_row := _tab.get_node_or_null("ButtonRow") as HBoxContainer

	var default_rows: Array[HBoxContainer] = [master_row, music_row, sfx_row, ambient_row]
	for row in default_rows:
		assert_not_null(row, "Audio slider rows should exist")
		if row != null:
			assert_eq(
				row.get_theme_constant(&"separation"),
				config.separation_default,
				"Audio slider rows should use separation_default token"
			)

	assert_not_null(button_row, "Button row should exist")
	if button_row != null:
		assert_eq(
			button_row.get_theme_constant(&"separation"),
			config.separation_compact,
			"Button row should use separation_compact token"
		)

	assert_eq(
		_tab._heading_label.get_theme_font_size(&"font_size"),
		config.heading,
		"Heading should use heading font token"
	)
	assert_eq(
		_tab._master_label.get_theme_font_size(&"font_size"),
		config.body_small,
		"Master label should use body_small font token"
	)
	assert_true(
		_tab._master_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
		"Master label should use text_secondary color token"
	)
	assert_eq(
		_tab._apply_button.get_theme_font_size(&"font_size"),
		config.section_header,
		"Apply button should use section_header font token"
	)
