extends GutTest

const SettingsMenuScene := preload("res://scenes/core/ui/menus/ui_settings_menu.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const MENU_FULLSCREEN_SHADER := preload("res://assets/core/shaders/sh_menu_fullscreen_shader.gdshader")

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null

func test_settings_menu_has_enter_exit_motion_assigned() -> void:
	await _create_state_store()
	var settings_menu: Variant = await _create_settings_menu()
	var motion_set: Variant = settings_menu.get("motion_set")

	assert_not_null(motion_set, "Settings menu should assign a motion set for enter/exit animation")
	if motion_set == null:
		return
	assert_true("enter" in motion_set, "Motion set should expose enter presets")
	assert_true("exit" in motion_set, "Motion set should expose exit presets")
	var enter_presets: Array = motion_set.enter
	var exit_presets: Array = motion_set.exit
	assert_gt(enter_presets.size(), 0, "Motion set enter presets should not be empty")
	assert_gt(exit_presets.size(), 0, "Motion set exit presets should not be empty")

func test_applies_theme_tokens_and_overlay_dim_in_overlay_context() -> void:
	var store := await _create_state_store()
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 41
	config.margin_section = 19
	config.separation_default = 14
	config.bg_base = Color(0.18, 0.27, 0.36, 1.0)
	U_UI_THEME_BUILDER.active_config = config
	_prepare_settings_overlay_context(store)

	var settings_menu := await _create_settings_menu()
	var title_label: Label = settings_menu.get_node("%TitleLabel")
	var panel_padding: MarginContainer = settings_menu.get_node("%MainPanelPadding")
	var panel_content: VBoxContainer = settings_menu.get_node("%MainPanelContent")
	var buttons_vbox: VBoxContainer = settings_menu.get_node("%ButtonsVBox")
	var overlay_background := settings_menu.get_node_or_null("OverlayBackground") as ColorRect
	var expected_dim := config.bg_base
	expected_dim.a = 0.7

	assert_eq(
		title_label.get_theme_font_size(&"font_size"),
		41,
		"Settings title should use heading token from active theme config"
	)
	assert_eq(
		panel_padding.get_theme_constant(&"margin_left"),
		19,
		"Panel padding should use margin_section token from active theme config"
	)
	assert_eq(
		panel_content.get_theme_constant(&"separation"),
		14,
		"Panel content spacing should use separation_default token"
	)
	assert_eq(
		buttons_vbox.get_theme_constant(&"separation"),
		14,
		"Button list spacing should use separation_default token"
	)
	assert_not_null(overlay_background, "Settings menu should create an overlay background panel")
	if overlay_background != null:
		assert_true(
			overlay_background.color.is_equal_approx(expected_dim),
			"Overlay dim should use bg_base with 0.7 alpha in overlay mode"
		)

func test_embedded_mode_uses_no_dim_background() -> void:
	var store := await _create_state_store()
	var config := RS_UI_THEME_CONFIG.new()
	config.bg_base = Color(0.2, 0.25, 0.3, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	store.dispatch(U_NavigationActions.return_to_main_menu())
	await wait_process_frames(2)

	var settings_menu := await _create_settings_menu()
	var overlay_background := settings_menu.get_node_or_null("OverlayBackground") as ColorRect
	assert_not_null(overlay_background, "Settings menu should create an overlay background panel")
	if overlay_background == null:
		return

	assert_almost_eq(
		overlay_background.color.a,
		0.0,
		0.001,
		"Embedded settings mode should not apply dim background"
	)

func test_standalone_scene_uses_opaque_shader_background() -> void:
	var store := await _create_state_store()
	var config := RS_UI_THEME_CONFIG.new()
	config.bg_base = Color(0.2, 0.25, 0.3, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	store.dispatch(U_SceneActions.transition_completed(StringName("settings_menu")))
	await wait_process_frames(2)

	var settings_menu := await _create_settings_menu()
	var overlay_background := settings_menu.get_node_or_null("OverlayBackground") as ColorRect
	assert_not_null(overlay_background, "Settings menu should create an overlay background panel")
	if overlay_background == null:
		return

	assert_almost_eq(
		overlay_background.color.a,
		1.0,
		0.001,
		"Standalone settings scene should render an opaque shader background"
	)

	var material := overlay_background.material as ShaderMaterial
	assert_not_null(material, "Standalone settings scene should assign backdrop shader material")
	if material != null:
		assert_eq(material.shader, MENU_FULLSCREEN_SHADER, "Standalone settings background should use shared menu shader")

func test_gamepad_settings_button_visible_when_gamepad_connected() -> void:
	await _create_state_store()
	var settings_menu := await _create_settings_menu()

	var gamepad_button: Button = settings_menu.get_node("%GamepadSettingsButton")

	var state_no_gamepad := {
		"input": {
			"gamepad_connected": false,
			"active_device_type": M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE,
		}
	}
	settings_menu._update_button_visibility(state_no_gamepad)
	assert_false(gamepad_button.visible, "Gamepad Settings should hide when no gamepad is connected")

	var state_with_gamepad := {
		"input": {
			"gamepad_connected": true,
			"active_device_type": M_InputDeviceManager.DeviceType.GAMEPAD,
		}
	}
	settings_menu._update_button_visibility(state_with_gamepad)
	assert_true(gamepad_button.visible, "Gamepad Settings should show when a gamepad is connected")

func test_rebind_controls_hidden_when_touchscreen_is_active() -> void:
	await _create_state_store()
	var settings_menu := await _create_settings_menu()

	var rebind_button: Button = settings_menu.get_node("%RebindControlsButton")

	var touch_only_state := {
		"input": {
			"gamepad_connected": false,
			"active_device_type": M_InputDeviceManager.DeviceType.TOUCHSCREEN,
		}
	}
	settings_menu._update_button_visibility(touch_only_state)
	assert_false(rebind_button.visible, "Rebind Controls should hide for touch-only device")

	var touch_with_gamepad_state := {
		"input": {
			"gamepad_connected": true,
			"active_device_type": M_InputDeviceManager.DeviceType.TOUCHSCREEN,
		}
	}
	settings_menu._update_button_visibility(touch_with_gamepad_state)
	assert_false(
		rebind_button.visible,
		"Rebind Controls should remain hidden when the active device is touchscreen, even if a gamepad is connected"
	)

func test_keyboard_mouse_settings_hidden_in_mobile_context() -> void:
	await _create_state_store()
	var settings_menu := await _create_settings_menu()
	settings_menu.emulate_mobile_override = true

	var keyboard_mouse_button: Button = settings_menu.get_node("%KeyboardMouseSettingsButton")

	var state_keyboard_mouse_active := {
		"input": {
			"gamepad_connected": false,
			"active_device_type": M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE,
		}
	}
	settings_menu._update_button_visibility(state_keyboard_mouse_active)
	assert_false(
		keyboard_mouse_button.visible,
		"Keyboard/Mouse Settings should be hidden in mobile context"
	)

	var state_gamepad_active := {
		"input": {
			"gamepad_connected": true,
			"active_device_type": M_InputDeviceManager.DeviceType.GAMEPAD,
		}
	}
	settings_menu._update_button_visibility(state_gamepad_active)
	assert_false(
		keyboard_mouse_button.visible,
		"Keyboard/Mouse Settings should remain hidden in mobile context when gamepad is active"
	)

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store

func _create_settings_menu() -> Control:
	var settings_menu := SettingsMenuScene.instantiate()
	add_child_autofree(settings_menu)
	await wait_process_frames(3)
	return settings_menu

func _prepare_settings_overlay_context(store: M_StateStore) -> void:
	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	store.dispatch(U_NavigationActions.open_pause())
	store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
