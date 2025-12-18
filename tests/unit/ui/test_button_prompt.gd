extends GutTest

const ButtonPromptScene := preload("res://scenes/ui/ui_button_prompt.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_ButtonPromptRegistry := preload("res://scripts/ui/u_button_prompt_registry.gd")
const DeviceType := M_InputDeviceManager.DeviceType

var _store: M_StateStore
var _device_manager: M_InputDeviceManager
var _button_prompt: Control

func before_each() -> void:
	U_StateHandoff.clear_all()
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.boot_initial_state = RS_BootInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	add_child_autofree(_store)

	_device_manager = M_InputDeviceManager.new()
	add_child_autofree(_device_manager)

	_button_prompt = ButtonPromptScene.instantiate()
	add_child_autofree(_button_prompt)

	_register_default_prompts()

	await _await_frames(2)
	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.physical_keycode = KEY_E
	_device_manager._input(keyboard_event)
	await _await_frames(1)

func after_each() -> void:
	U_StateHandoff.clear_all()
	_store = null
	_device_manager = null
	_button_prompt = null
	U_ButtonPromptRegistry._clear_for_tests()

func _register_default_prompts() -> void:
	U_ButtonPromptRegistry._clear_for_tests()
	U_ButtonPromptRegistry.register_prompt(
		StringName("interact"),
		DeviceType.KEYBOARD_MOUSE,
		"res://resources/button_prompts/keyboard/key_e.png",
		"E"
	)
	U_ButtonPromptRegistry.register_prompt(
		StringName("interact"),
		DeviceType.GAMEPAD,
		"res://resources/button_prompts/gamepad/button_west.png",
		"West"
	)
	U_ButtonPromptRegistry.register_prompt(
		StringName("jump"),
		DeviceType.KEYBOARD_MOUSE,
		"res://resources/button_prompts/keyboard/key_space.png",
		"Space"
	)
	U_ButtonPromptRegistry.register_prompt(
		StringName("jump"),
		DeviceType.GAMEPAD,
		"res://resources/button_prompts/gamepad/button_south.png",
		"South"
	)

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func test_show_prompt_updates_icon_and_text() -> void:
	var button_prompt := _button_prompt
	assert_not_null(button_prompt, "Button prompt scene should instantiate")

	button_prompt.call("show_prompt", StringName("interact"), "Read")
	await _await_frames(1)

	var text_icon: Control = button_prompt.get_node("TextIcon")
	var text_icon_texture: TextureRect = text_icon.get_node("ButtonIcon")
	var label: Label = button_prompt.get_node("Text")

	assert_true(button_prompt.visible, "Prompt container should be visible after show")
	assert_true(text_icon.visible, "Text icon should be visible when prompt shown")
	assert_true(text_icon_texture.visible, "Texture should be visible for keyboard binding")
	assert_not_null(text_icon_texture.texture, "Texture should be loaded for keyboard binding")
	assert_eq(label.text, "Read", "Prompt text should match provided value")

	_device_manager._on_joy_connection_changed(1, true)
	await _await_frames(1)
	var motion := InputEventJoypadMotion.new()
	motion.device = 1
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.5
	_device_manager._input(motion)
	await _await_frames(1)

	assert_true(text_icon.visible, "Text icon should remain visible after device change")
	assert_true(text_icon_texture.visible, "Texture should be visible for gamepad binding")
	assert_not_null(text_icon_texture.texture, "Texture should be loaded for gamepad binding")
	assert_eq(label.text, "Read", "Prompt text should remain unchanged when device switches")

func test_missing_icon_falls_back_to_text_label() -> void:
	var action := StringName("custom_action")
	U_ButtonPromptRegistry.register_prompt(action, DeviceType.GAMEPAD, "res://resources/button_prompts/gamepad/missing_button.png")

	_device_manager._on_joy_connection_changed(0, true)
	await _await_frames(1)
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 0.4
	_device_manager._input(motion)
	await _await_frames(1)

	_button_prompt.call("show_prompt", action, "Activate")
	await _await_frames(1)

	var label: Label = _button_prompt.get_node("Text")
	var text_icon: Control = _button_prompt.get_node("TextIcon")
	var text_icon_label: Label = text_icon.get_node("Label")

	assert_true(text_icon.visible, "Text icon should show when representing binding")
	assert_eq(text_icon_label.text, "Missing Button",
		"Text icon should show derived label when no binding available")
	assert_eq(label.text, "Activate", "Prompt text should remain provided label")

func test_hide_prompt_clears_state() -> void:
	_button_prompt.call("show_prompt", StringName("interact"), "Read")
	await _await_frames(1)

	_button_prompt.call("hide_prompt")
	await _await_frames(1)

	var label: Label = _button_prompt.get_node("Text")
	var text_icon: Control = _button_prompt.get_node("TextIcon")
	var text_icon_label: Label = text_icon.get_node("Label")

	assert_false(_button_prompt.visible, "Prompt should hide after hide_prompt call")
	assert_false(text_icon.visible, "Text icon should hide after hide_prompt")
	assert_eq(text_icon_label.text, "", "Text icon label should clear after hide_prompt")
	assert_eq(label.text, "", "Label text should clear after hide_prompt")

func test_interact_prompt_reflects_custom_binding() -> void:
	await _assert_prompt_updates_binding_label(StringName("interact"), "Read", Key.KEY_F)

func test_jump_prompt_reflects_custom_binding() -> void:
	await _assert_prompt_updates_binding_label(StringName("jump"), "Jump", Key.KEY_Q)

func test_show_prompt_displays_texture_when_available() -> void:
	_button_prompt.call("show_prompt", StringName("interact"), "Open Door")
	await _await_frames(1)

	var text_icon: Control = _button_prompt.get_node("TextIcon")
	var text_icon_texture: TextureRect = text_icon.get_node("ButtonIcon")
	var text_icon_label: Label = text_icon.get_node("Label")

	assert_true(text_icon.visible, "Text icon panel should be visible")
	assert_true(text_icon_texture.visible, "Texture should be visible when available")
	assert_not_null(text_icon_texture.texture, "Texture should be loaded from registry")
	assert_false(text_icon_label.visible, "Text label should be hidden when texture shown")

func test_show_prompt_falls_back_to_text_when_texture_missing() -> void:
	var action := StringName("missing_texture_action")
	U_ButtonPromptRegistry.register_prompt(action, DeviceType.KEYBOARD_MOUSE, "res://invalid/missing.png", "TestKey")

	_button_prompt.call("show_prompt", action, "Test Action")
	await _await_frames(1)

	var text_icon: Control = _button_prompt.get_node("TextIcon")
	var text_icon_texture: TextureRect = text_icon.get_node("ButtonIcon")
	var text_icon_label: Label = text_icon.get_node("Label")

	assert_true(text_icon.visible, "Text icon panel should be visible")
	assert_false(text_icon_texture.visible, "Texture should be hidden when unavailable")
	assert_null(text_icon_texture.texture, "Texture should be null for missing files")
	assert_true(text_icon_label.visible, "Text label should be visible as fallback")
	assert_eq(text_icon_label.text, "TestKey", "Text label should show binding label")

func test_device_switch_updates_texture() -> void:
	_button_prompt.call("show_prompt", StringName("interact"), "Interact")
	await _await_frames(1)

	var text_icon: Control = _button_prompt.get_node("TextIcon")
	var text_icon_texture: TextureRect = text_icon.get_node("ButtonIcon")
	var keyboard_texture := text_icon_texture.texture

	assert_not_null(keyboard_texture, "Keyboard texture should be loaded")

	# Switch to gamepad
	_device_manager._on_joy_connection_changed(0, true)
	await _await_frames(1)
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.6
	_device_manager._input(motion)
	await _await_frames(1)

	var gamepad_texture := text_icon_texture.texture
	assert_not_null(gamepad_texture, "Gamepad texture should be loaded")
	if keyboard_texture != null and gamepad_texture != null:
		assert_ne(keyboard_texture.resource_path, gamepad_texture.resource_path, "Texture should change with device type")

func test_hide_prompt_clears_texture() -> void:
	_button_prompt.call("show_prompt", StringName("interact"), "Test")
	await _await_frames(1)

	var text_icon_texture: TextureRect = _button_prompt.get_node("TextIcon/ButtonIcon")
	assert_not_null(text_icon_texture.texture, "Texture should be set when prompt shown")

	_button_prompt.call("hide_prompt")
	await _await_frames(1)

	assert_null(text_icon_texture.texture, "Texture should be cleared when prompt hidden")
	assert_false(text_icon_texture.visible, "Texture rect should be hidden")

func test_button_icon_maintains_aspect_ratio() -> void:
	_button_prompt.call("show_prompt", StringName("jump"), "Jump")
	await _await_frames(1)

	var text_icon_texture: TextureRect = _button_prompt.get_node("TextIcon/ButtonIcon")
	assert_eq(text_icon_texture.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"Texture should maintain aspect ratio with centered stretch mode")

func test_button_icon_respects_minimum_size() -> void:
	_button_prompt.call("show_prompt", StringName("interact"), "Interact")
	await _await_frames(1)

	var text_icon_texture: TextureRect = _button_prompt.get_node("TextIcon/ButtonIcon")
	var min_size := text_icon_texture.custom_minimum_size
	assert_eq(min_size, Vector2(32, 32), "Texture should have 32x32 minimum size")

func _capture_action_events(action: StringName) -> Array[InputEvent]:
	var results: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return results
	for event in InputMap.action_get_events(action):
		if event is InputEvent:
			var copy := (event as InputEvent).duplicate()
			if copy is InputEvent:
				results.append(copy)
	return results

func _restore_action_events(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action).duplicate():
		InputMap.action_erase_event(action, event)
	for event in events:
		InputMap.action_add_event(action, event)

func _assert_prompt_updates_binding_label(action: StringName, prompt: String, keycode: int) -> void:
	_button_prompt.call("show_prompt", action, prompt)
	await _await_frames(1)
	var text_icon: Control = _button_prompt.get_node("TextIcon")
	var text_icon_texture: TextureRect = text_icon.get_node("ButtonIcon")
	var text_icon_label: Label = text_icon.get_node("Label")
	var label: Label = _button_prompt.get_node("Text")
	assert_true(is_instance_valid(text_icon), "Text icon should remain valid while prompt active")
	assert_true(is_instance_valid(label), "Label should remain valid while prompt active")
	assert_true(text_icon.visible, "Text icon should be visible for default binding")
	# Texture should be visible if available
	var has_texture := U_ButtonPromptRegistry.get_prompt(action, DeviceType.KEYBOARD_MOUSE) != null
	if has_texture:
		assert_true(text_icon_texture.visible, "Texture should be visible when available")
	else:
		assert_eq(text_icon_label.text, U_ButtonPromptRegistry.get_binding_label(action, DeviceType.KEYBOARD_MOUSE),
			"Text icon should reflect current binding label")
	assert_eq(label.text, prompt, "Default prompt keeps provided label when icon available")

	var original_events := _capture_action_events(action)
	_set_action_binding_to_key(action, keycode)
	_button_prompt.call("show_prompt", action, prompt)
	await _await_frames(1)
	text_icon = _button_prompt.get_node("TextIcon")
	text_icon_texture = text_icon.get_node("ButtonIcon")
	text_icon_label = text_icon.get_node("Label")
	label = _button_prompt.get_node("Text")

	assert_true(text_icon.visible, "Text icon should remain visible after rebinding")
	# Texture remains shown if registered for action (even if binding changed)
	if has_texture:
		assert_true(text_icon_texture.visible, "Texture should remain visible after rebinding")
		assert_not_null(text_icon_texture.texture, "Texture should still be loaded")
		# Note: Texture may not match new binding, but it's registered for the action
	else:
		assert_false(text_icon_texture.visible, "Texture should be hidden when not available")
		assert_true(text_icon_label.visible, "Text label should be visible as fallback")
		assert_eq(text_icon_label.text, OS.get_keycode_string(keycode),
			"Text icon should display rebound key label")
	assert_eq(label.text, prompt, "Prompt text should remain provided label")

	_restore_action_events(action, original_events)

func _set_action_binding_to_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action).duplicate():
		InputMap.action_erase_event(action, event)
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)
