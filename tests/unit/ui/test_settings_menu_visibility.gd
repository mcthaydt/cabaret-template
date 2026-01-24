extends GutTest

const SettingsMenuScene := preload("res://scenes/ui/ui_settings_menu.tscn")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_gamepad_settings_button_visible_when_gamepad_connected() -> void:
	await _create_state_store()
	var settings_menu := await _create_settings_menu()

	var gamepad_button: Button = settings_menu.get_node("CenterContainer/VBoxContainer/GamepadSettingsButton")

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

	var rebind_button: Button = settings_menu.get_node("CenterContainer/VBoxContainer/RebindControlsButton")

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
