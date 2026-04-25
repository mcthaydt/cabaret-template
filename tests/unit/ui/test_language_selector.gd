extends GutTest

const LanguageSelectorScene := preload("res://scenes/core/ui/menus/ui_language_selector.tscn")
const MockSceneManagerScript := preload("res://tests/mocks/mock_scene_manager_with_transition.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const MENU_FULLSCREEN_SHADER := preload("res://assets/core/shaders/sh_menu_fullscreen_shader.gdshader")


func before_each() -> void:
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	U_UI_THEME_BUILDER.active_config = null

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	U_UI_THEME_BUILDER.active_config = null

func test_language_selector_has_motion_and_theme_tokens_when_active_config_set() -> void:
	await _create_state_store()
	_register_mock_scene_manager()
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 44
	config.bg_base = Color(0.16, 0.13, 0.24, 1.0)
	config.separation_default = 18
	config.separation_compact = 7
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.24, 0.2, 0.34, 1.0)
	config.panel_section = panel_style
	U_UI_THEME_BUILDER.active_config = config

	var screen: Variant = await _instantiate_language_selector()
	var motion_set: Variant = screen.get("motion_set")
	var button_container: Control = screen.get_node("%ButtonContainer")
	var title_label: Label = screen.get_node("%TitleLabel")
	var background: ColorRect = screen.get_node("Background")
	var content_vbox: VBoxContainer = screen.get_node("%ContentVBox")
	var grid_container: GridContainer = screen.get_node("%GridContainer")
	var panel: PanelContainer = screen.get_node("%PanelContainer")
	var panel_stylebox: StyleBoxFlat = panel.get_theme_stylebox(&"panel") as StyleBoxFlat

	assert_true(button_container.visible, "Language selector buttons should be visible for first-run flow")
	assert_not_null(motion_set, "Language selector should assign enter/exit motion set")
	assert_eq(title_label.get_theme_font_size(&"font_size"), 44, "Title should use heading token")
	assert_true(background.color.is_equal_approx(config.bg_base), "Background should use bg_base token")
	var material := background.material as ShaderMaterial
	assert_not_null(material, "Language selector should apply configured fullscreen backdrop shader")
	if material != null:
		assert_eq(material.shader, MENU_FULLSCREEN_SHADER, "Language selector backdrop should use shared shader")
	assert_eq(content_vbox.get_theme_constant(&"separation"), 18, "VBox separation should use token value")
	assert_eq(grid_container.get_theme_constant(&"h_separation"), 7, "Grid h-separation should use compact token")
	assert_eq(grid_container.get_theme_constant(&"v_separation"), 7, "Grid v-separation should use compact token")
	assert_not_null(panel_stylebox, "Panel should resolve a stylebox")
	if panel_stylebox != null:
		assert_true(
			panel_stylebox.bg_color.is_equal_approx(panel_style.bg_color),
			"Panel should use panel_section style token"
		)

func test_language_selector_skips_to_main_menu_when_language_already_selected() -> void:
	var store := await _create_state_store()
	var scene_manager := _register_mock_scene_manager()
	store.dispatch(U_LocalizationActions.mark_language_selected())
	await wait_process_frames(2)

	var screen: Variant = await _instantiate_language_selector()
	var button_container: Control = screen.get_node("%ButtonContainer")

	assert_true(scene_manager.get("_transition_called"), "Language selector should transition immediately")
	assert_eq(scene_manager.get("_transition_target"), StringName("main_menu"))
	assert_eq(scene_manager.get("_transition_type"), "instant")
	assert_false(button_container.visible, "Button container should stay hidden on skip path")

func test_language_selector_selecting_locale_dispatches_and_transitions() -> void:
	var store := await _create_state_store()
	var scene_manager := _register_mock_scene_manager()
	var screen: Variant = await _instantiate_language_selector()
	var en_button: Button = screen.get_node("%EnButton")

	en_button.emit_signal("pressed")
	await wait_process_frames(2)

	var localization: Dictionary = store.get_slice(StringName("localization"))
	assert_eq(localization.get("current_locale"), StringName("en"))
	assert_true(bool(localization.get("has_selected_language", false)), "Selecting locale should mark language as selected")
	assert_true(scene_manager.get("_transition_called"), "Selecting locale should transition to main menu")
	assert_eq(scene_manager.get("_transition_target"), StringName("main_menu"))
	assert_eq(scene_manager.get("_transition_type"), "fade")

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.localization_initial_state = RS_LocalizationInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.scene_initial_state.current_scene_id = StringName("language_selector")
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store

func _register_mock_scene_manager() -> Node:
	var scene_manager: Node = MockSceneManagerScript.new()
	add_child_autofree(scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), scene_manager)
	return scene_manager

func _instantiate_language_selector() -> Control:
	var screen := LanguageSelectorScene.instantiate()
	add_child_autofree(screen)
	await wait_process_frames(3)
	return screen
