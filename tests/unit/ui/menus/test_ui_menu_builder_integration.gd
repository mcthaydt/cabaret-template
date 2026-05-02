extends GutTest

const MAIN_MENU_SCENE := preload("res://scenes/core/ui/menus/ui_main_menu.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/core/ui/menus/ui_pause_menu.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null


func test_main_menu_is_builder_backed() -> void:
	await _create_state_store()
	var menu := await _instantiate_main_menu()

	assert_not_null(menu.get("_menu_builder"), "Main menu should use U_UIMenuBuilder")

	var continue_button: Button = menu.get_node("%ContinueButton")
	assert_ne(continue_button.focus_neighbor_bottom, NodePath(), "Builder should configure vertical focus on buttons")


func test_main_menu_builder_wires_button_signals() -> void:
	await _create_state_store()
	var menu := await _instantiate_main_menu()

	var settings_button: Button = menu.get_node("%SettingsButton")
	assert_true(
		settings_button.pressed.is_connected(menu._on_settings_pressed),
		"Builder should wire settings button pressed signal"
	)

	var quit_button: Button = menu.get_node("%QuitButton")
	assert_true(
		quit_button.pressed.is_connected(menu._on_quit_pressed),
		"Builder should wire quit button pressed signal"
	)


func test_main_menu_builder_applies_theme_tokens() -> void:
	await _create_state_store()
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 55
	config.section_header = 20
	U_UI_THEME_BUILDER.active_config = config

	var menu := await _instantiate_main_menu()
	var continue_button: Button = menu.get_node("%ContinueButton")

	assert_eq(
		continue_button.get_theme_font_size(&"font_size"),
		20,
		"Main menu buttons should use builder section_header theme token"
	)


func test_pause_menu_is_builder_backed() -> void:
	await _create_state_store()
	var pause_menu := await _instantiate_pause_menu()

	assert_not_null(pause_menu.get("_menu_builder"), "Pause menu should use U_UIMenuBuilder")

	var resume_button: Button = pause_menu.get_node("%ResumeButton")
	assert_ne(resume_button.focus_neighbor_bottom, NodePath(), "Builder should configure vertical focus on buttons")


func test_pause_menu_builder_wires_button_signals() -> void:
	await _create_state_store()
	var pause_menu := await _instantiate_pause_menu()

	var resume_button: Button = pause_menu.get_node("%ResumeButton")
	assert_true(
		resume_button.pressed.is_connected(pause_menu._on_resume_pressed),
		"Builder should wire resume button pressed signal"
	)

	var settings_button: Button = pause_menu.get_node("%SettingsButton")
	assert_true(
		settings_button.pressed.is_connected(pause_menu._on_settings_pressed),
		"Builder should wire settings button pressed signal"
	)


func test_pause_menu_builder_applies_theme_tokens() -> void:
	await _create_state_store()
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 44
	config.section_header = 18
	U_UI_THEME_BUILDER.active_config = config

	var pause_menu := await _instantiate_pause_menu()
	var resume_button: Button = pause_menu.get_node("%ResumeButton")

	assert_eq(
		resume_button.get_theme_font_size(&"font_size"),
		18,
		"Pause menu buttons should use builder section_header theme token"
	)


func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	store.settings = test_settings
	add_child_autofree(store)
	return store


func _instantiate_main_menu() -> UI_MainMenu:
	var menu := MAIN_MENU_SCENE.instantiate() as UI_MainMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	return menu


func _instantiate_pause_menu() -> UI_PauseMenu:
	var pause_menu := PAUSE_MENU_SCENE.instantiate() as UI_PauseMenu
	add_child_autofree(pause_menu)
	await get_tree().process_frame
	return pause_menu