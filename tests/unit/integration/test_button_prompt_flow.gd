extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const RS_StateStoreSettings := preload("res://resources/state/cfg_default_state_store_settings.tres")
const RS_BootInitialState := preload("res://resources/state/cfg_default_boot_initial_state.tres")
const RS_MenuInitialState := preload("res://resources/state/cfg_default_menu_initial_state.tres")
const RS_GameplayInitialState := preload("res://resources/state/cfg_default_gameplay_initial_state.tres")
const RS_SceneInitialState := preload("res://resources/state/cfg_default_scene_initial_state.tres")
const RS_SettingsInitialState := preload("res://resources/state/cfg_default_settings_initial_state.tres")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_ECSEventBus := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const DeviceType := M_InputDeviceManager.DeviceType

var _store: M_StateStore
var _device_manager: M_InputDeviceManager
var _hud: CanvasLayer

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_ECSEventBus.reset()

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings
	_store.boot_initial_state = RS_BootInitialState
	_store.menu_initial_state = RS_MenuInitialState
	_store.gameplay_initial_state = RS_GameplayInitialState
	_store.scene_initial_state = RS_SceneInitialState
	_store.settings_initial_state = RS_SettingsInitialState
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)

	_device_manager = M_InputDeviceManager.new()
	add_child_autofree(_device_manager)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child_autofree(hud_layer)

	_hud = HUD_SCENE.instantiate()
	hud_layer.add_child(_hud)

	await _await_frames(2)
	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.physical_keycode = KEY_E
	_device_manager._input(keyboard_event)
	await _await_frames(1)

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	_store = null
	_device_manager = null
	_hud = null

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func test_device_switch_updates_hud_prompt_within_one_frame() -> void:
	var controller_id := 4242
	U_ECSEventBus.publish(StringName("interact_prompt_show"), {
		"controller_id": controller_id,
		"action": StringName("interact"),
		"prompt": "Read"
	})
	await _await_frames(1)

	var button_prompt: Control = _hud.get_node("MarginContainer/InteractPrompt")
	var text_icon: Control = button_prompt.get_node("TextIcon")
	var text_icon_texture: TextureRect = button_prompt.get_node("TextIcon/ButtonIcon")
	var label: Label = button_prompt.get_node("Text")

	assert_true(button_prompt.visible, "Prompt should be visible after show event")
	assert_true(text_icon.visible, "Keyboard prompt should include text icon panel")
	assert_true(text_icon_texture.visible, "Texture should be visible for keyboard binding")
	assert_not_null(text_icon_texture.texture, "Texture should be loaded for keyboard")
	assert_eq(label.text, "Read")

	_device_manager._on_joy_connection_changed(0, true)
	await _await_frames(1)
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.8
	_device_manager._input(motion)
	await _await_frames(1)

	assert_true(text_icon.visible, "Prompt text icon should remain visible after device change")
	assert_true(text_icon_texture.visible, "Texture should be visible for gamepad binding")
	assert_not_null(text_icon_texture.texture, "Texture should be loaded for gamepad")
	assert_eq(label.text, "Read", "Prompt message should stay in sync with HUD label")

	U_ECSEventBus.publish(StringName("interact_prompt_hide"), {"controller_id": controller_id})
	await _await_frames(1)

	assert_false(button_prompt.visible, "Prompt should hide after hide event")
	assert_false(text_icon.visible)
	assert_eq(label.text, "")
