extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")
const DeviceType := M_InputDeviceManager.DeviceType

class LocalizationManagerStub extends Node:
	var translations: Dictionary = {}

	func translate(key: StringName) -> String:
		return String(translations.get(String(key), String(key)))

	func register_ui_root(_root: Node) -> void:
		pass

	func unregister_ui_root(_root: Node) -> void:
		pass

var _store: M_StateStore
var _device_manager: M_InputDeviceManager
var _hud: CanvasLayer
var _localization_manager: LocalizationManagerStub

func before_each() -> void:
	U_ServiceLocator.clear()
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

	_localization_manager = LocalizationManagerStub.new()
	_localization_manager.translations = {
		"hud.interact_read": "Read",
	}
	add_child_autofree(_localization_manager)
	U_ServiceLocator.register(StringName("localization_manager"), _localization_manager)

	_hud = HUD_SCENE.instantiate()
	add_child_autofree(_hud)

	await _await_frames(2)
	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.physical_keycode = KEY_A
	_device_manager._input(keyboard_event)
	await _await_frames(1)

func after_each() -> void:
	U_ServiceLocator.clear()
	U_StateHandoff.clear_all()
	_store = null
	_device_manager = null
	_hud = null
	_localization_manager = null
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

func test_visible_prompt_relocalizes_after_localization_slice_update() -> void:
	var text_label: Label = _hud.get_node("MarginContainer/InteractPrompt/Text")

	U_ECSEventBus.publish(StringName("interact_prompt_show"), {
		"controller_id": 777,
		"action": StringName("interact"),
		"prompt": "hud.interact_read"
	})
	await _await_frames(1)
	assert_eq(text_label.text, "Read", "Prompt should start with current locale text")

	_localization_manager.translations["hud.interact_read"] = "Leer"
	_hud._on_slice_updated(StringName("localization"), {})
	await _await_frames(1)

	assert_eq(
		text_label.text,
		"Leer",
		"Visible prompt should refresh immediately after localization slice updates"
	)
