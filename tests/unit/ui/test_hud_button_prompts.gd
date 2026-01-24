extends GutTest

const HUD_SCENE := preload("res://scenes/ui/ui_hud_overlay.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const U_ECSEventBus := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_ButtonPromptRegistry := preload("res://scripts/ui/utils/u_button_prompt_registry.gd")
const DeviceType := M_InputDeviceManager.DeviceType

var _store: M_StateStore
var _device_manager: M_InputDeviceManager
var _hud: CanvasLayer

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_ECSEventBus.reset()

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.boot_initial_state = RS_BootInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	add_child_autofree(_store)

	_device_manager = M_InputDeviceManager.new()
	add_child_autofree(_device_manager)

	_hud = HUD_SCENE.instantiate()
	add_child_autofree(_hud)

	await _await_frames(2)
	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.physical_keycode = KEY_A
	_device_manager._input(keyboard_event)
	await _await_frames(1)

func after_each() -> void:
	U_StateHandoff.clear_all()
	_store = null
	_device_manager = null
	_hud = null
	U_ButtonPromptRegistry._clear_for_tests()

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func test_interact_prompt_updates_icon_on_device_switch() -> void:
	var text_label: Label = _hud.get_node("MarginContainer/InteractPrompt/Text")
	var text_icon: Control = _hud.get_node("MarginContainer/InteractPrompt/TextIcon")
	var text_icon_texture: TextureRect = text_icon.get_node("ButtonIcon")

	U_ECSEventBus.publish(StringName("interact_prompt_show"), {
		"controller_id": 99,
		"action": StringName("interact"),
		"prompt": "Read"
	})
	await _await_frames(1)

	assert_true(text_icon.visible, "HUD prompt should display icon")
	assert_true(text_icon_texture.visible, "HUD should show keyboard texture")
	assert_not_null(text_icon_texture.texture, "Texture should be loaded for keyboard")
	assert_eq(text_label.text, "Read", "Prompt text should reflect interact message")

	_device_manager._on_joy_connection_changed(1, true)
	await _await_frames(1)
	var motion := InputEventJoypadMotion.new()
	motion.device = 1
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 0.6
	_device_manager._input(motion)
	await _await_frames(1)

	assert_true(text_icon.visible, "HUD text icon stays visible after device switch")
	assert_true(text_icon_texture.visible, "HUD should show gamepad texture")
	assert_not_null(text_icon_texture.texture, "Texture should be loaded for gamepad")
	assert_eq(text_label.text, "Read", "Prompt text should remain unchanged when device switches")

func test_interact_prompt_falls_back_to_text_when_icon_missing() -> void:
	var action := StringName("custom_prompt_action")
	U_ButtonPromptRegistry.register_prompt(action, DeviceType.GAMEPAD, "res://assets/button_prompts/gamepad/missing_button.png")

	_device_manager._on_joy_connection_changed(2, true)
	await _await_frames(1)
	var motion := InputEventJoypadMotion.new()
	motion.device = 2
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.7
	_device_manager._input(motion)
	await _await_frames(1)

	var text_label: Label = _hud.get_node("MarginContainer/InteractPrompt/Text")
	var text_icon: Control = _hud.get_node("MarginContainer/InteractPrompt/TextIcon")
	var text_icon_label: Label = text_icon.get_node("Label")

	U_ECSEventBus.publish(StringName("interact_prompt_show"), {
		"controller_id": 123,
		"action": action,
		"prompt": "Activate"
	})
	await _await_frames(1)

	assert_true(text_icon.visible, "Text icon should appear regardless of texture availability")
	assert_eq(text_icon_label.text, "Missing Button",
		"Text icon should display derived label when icon asset unavailable")
	assert_eq(text_label.text, "Activate", "Prompt text remains provided text when fallback icon shows")
