extends GutTest


const DEVICE_TYPE := M_InputDeviceManager.DeviceType

func before_each() -> void:
	_reset_registry()

func after_each() -> void:
	_reset_registry()

func test_register_prompt_provides_binding_label() -> void:
	var action := StringName("test_prompt_action")
	var texture_path := "res://assets/button_prompts/keyboard/key_e.png"
	U_ButtonPromptRegistry.register_prompt(action, DEVICE_TYPE.KEYBOARD_MOUSE, texture_path, "E")

	var label := U_ButtonPromptRegistry.get_binding_label(action, DEVICE_TYPE.KEYBOARD_MOUSE)
	assert_eq(label, "E", "Registry should return explicit binding label for registered prompts")

func test_get_prompt_returns_texture_for_registered_action() -> void:
	var texture := U_ButtonPromptRegistry.get_prompt(StringName("interact"), DEVICE_TYPE.KEYBOARD_MOUSE)
	assert_not_null(texture, "Prompt registry should supply textures for registered actions")
	assert_true(texture is Texture2D, "Returned prompt should be a Texture2D")

func test_get_prompt_text_uses_keyboard_binding_label() -> void:
	var text := U_ButtonPromptRegistry.get_prompt_text(StringName("jump"), DEVICE_TYPE.KEYBOARD_MOUSE)
	assert_eq(text, "Press [Space]", "Keyboard fallback text should reflect primary key binding")

func test_get_prompt_text_returns_gamepad_label_from_registry_metadata() -> void:
	var action := StringName("test_gamepad_action")
	var texture_path := "res://assets/button_prompts/gamepad/button_west.png"
	U_ButtonPromptRegistry.register_prompt(action, DEVICE_TYPE.GAMEPAD, texture_path, "West")
	var text := U_ButtonPromptRegistry.get_prompt_text(action, DEVICE_TYPE.GAMEPAD)
	assert_eq(text, "Press [West]", "Gamepad fallback should derive label from registered prompt metadata")

func test_get_prompt_text_uses_touchscreen_template() -> void:
	var text := U_ButtonPromptRegistry.get_prompt_text(StringName("jump"), DEVICE_TYPE.TOUCHSCREEN)
	assert_eq(text, "Tap Jump", "Touchscreen fallback should use tap template with capitalized action name")

func test_ui_accept_uses_keyboard_and_gamepad_labels() -> void:
	var keyboard_text := U_ButtonPromptRegistry.get_prompt_text(StringName("ui_accept"), DEVICE_TYPE.KEYBOARD_MOUSE)
	assert_eq(keyboard_text, "Press [Enter]", "ui_accept should display Enter for keyboard prompts")
	var gamepad_text := U_ButtonPromptRegistry.get_prompt_text(StringName("ui_accept"), DEVICE_TYPE.GAMEPAD)
	assert_eq(gamepad_text, "Press [A]", "ui_accept should display A for gamepad prompts")

func test_ui_cancel_and_pause_use_expected_touch_and_gamepad_labels() -> void:
	var cancel_text := U_ButtonPromptRegistry.get_prompt_text(StringName("ui_cancel"), DEVICE_TYPE.GAMEPAD)
	assert_eq(cancel_text, "Press [B]", "ui_cancel should map to B for gamepad prompts")
	var pause_touch_text := U_ButtonPromptRegistry.get_prompt_text(StringName("ui_pause"), DEVICE_TYPE.TOUCHSCREEN)
	assert_eq(pause_touch_text, "Tap Pause", "ui_pause should present pause label for touchscreen")

func test_get_prompt_returns_texture_when_registered() -> void:
	var action := StringName("interact")
	var texture := U_ButtonPromptRegistry.get_prompt(action, DEVICE_TYPE.KEYBOARD_MOUSE)
	assert_not_null(texture, "Registered prompt with valid texture path should return loaded texture")
	assert_true(texture is Texture2D, "Returned texture should be of type Texture2D")

func test_get_prompt_caches_loaded_textures() -> void:
	var action := StringName("jump")
	var texture1 := U_ButtonPromptRegistry.get_prompt(action, DEVICE_TYPE.GAMEPAD)
	var texture2 := U_ButtonPromptRegistry.get_prompt(action, DEVICE_TYPE.GAMEPAD)
	assert_same(texture1, texture2, "Registry should return same texture instance for cached prompts")

func test_get_prompt_returns_null_for_missing_file() -> void:
	var action := StringName("nonexistent_action")
	U_ButtonPromptRegistry.register_prompt(action, DEVICE_TYPE.KEYBOARD_MOUSE, "res://invalid/path/missing.png", "Test")
	var texture := U_ButtonPromptRegistry.get_prompt(action, DEVICE_TYPE.KEYBOARD_MOUSE)
	assert_null(texture, "Registry should return null for missing texture files")

func test_get_prompt_returns_null_for_unregistered_action() -> void:
	var texture := U_ButtonPromptRegistry.get_prompt(StringName("unknown_action"), DEVICE_TYPE.GAMEPAD)
	assert_null(texture, "Registry should return null for actions not in registry")

func test_get_prompt_handles_empty_texture_path() -> void:
	var action := StringName("empty_path_action")
	U_ButtonPromptRegistry.register_prompt(action, DEVICE_TYPE.KEYBOARD_MOUSE, "", "Label")
	var texture := U_ButtonPromptRegistry.get_prompt(action, DEVICE_TYPE.KEYBOARD_MOUSE)
	assert_null(texture, "Registry should return null for empty texture paths")

func test_get_prompt_handles_device_type_mismatch() -> void:
	var action := StringName("interact")
	var keyboard_texture := U_ButtonPromptRegistry.get_prompt(action, DEVICE_TYPE.KEYBOARD_MOUSE)
	var gamepad_texture := U_ButtonPromptRegistry.get_prompt(action, DEVICE_TYPE.GAMEPAD)
	assert_not_null(keyboard_texture, "Keyboard prompt should exist")
	assert_not_null(gamepad_texture, "Gamepad prompt should exist")
	if keyboard_texture != null and gamepad_texture != null:
		assert_ne(keyboard_texture.resource_path, gamepad_texture.resource_path, "Different device types should return different textures")

func test_camera_center_defaults_use_keyboard_c_and_gamepad_rs_icons() -> void:
	var keyboard_texture := U_ButtonPromptRegistry.get_prompt(StringName("camera_center"), DEVICE_TYPE.KEYBOARD_MOUSE)
	var gamepad_texture := U_ButtonPromptRegistry.get_prompt(StringName("camera_center"), DEVICE_TYPE.GAMEPAD)
	assert_not_null(keyboard_texture, "camera_center should have a default keyboard glyph")
	assert_not_null(gamepad_texture, "camera_center should have a default gamepad glyph")
	if keyboard_texture != null:
		assert_true(
			keyboard_texture.resource_path.contains("key_c"),
			"camera_center keyboard glyph should resolve to key_c"
		)
	if gamepad_texture != null:
		assert_true(
			gamepad_texture.resource_path.contains("button_rs"),
			"camera_center gamepad glyph should resolve to button_rs"
		)

func test_gamepad_binding_labels_use_godot_button_constants() -> void:
	assert_eq(int(JOY_BUTTON_LEFT_STICK), 7, "Godot constant JOY_BUTTON_LEFT_STICK should remain index 7")
	assert_eq(int(JOY_BUTTON_RIGHT_STICK), 8, "Godot constant JOY_BUTTON_RIGHT_STICK should remain index 8")
	assert_eq(int(JOY_BUTTON_RIGHT_SHOULDER), 10, "Godot constant JOY_BUTTON_RIGHT_SHOULDER should remain index 10")

	var action := StringName("test_gamepad_label_action")
	var original_events := _capture_action_events(action)
	_set_gamepad_binding(action, JOY_BUTTON_LEFT_STICK)
	assert_eq(U_ButtonPromptRegistry.get_binding_label(action, DEVICE_TYPE.GAMEPAD), "L3", "Left stick button should label as L3")
	_set_gamepad_binding(action, JOY_BUTTON_RIGHT_STICK)
	assert_eq(U_ButtonPromptRegistry.get_binding_label(action, DEVICE_TYPE.GAMEPAD), "R3", "Right stick button should label as R3")
	_set_gamepad_binding(action, JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(U_ButtonPromptRegistry.get_binding_label(action, DEVICE_TYPE.GAMEPAD), "R1", "Right shoulder button should label as R1")
	_restore_action_events(action, original_events)

func test_binding_aware_prompt_prefers_current_binding_texture_before_registry_default() -> void:
	var action := StringName("camera_center")
	var original_events := _capture_action_events(action)
	_set_gamepad_binding(action, JOY_BUTTON_RIGHT_SHOULDER)
	var rebound_texture := U_ButtonPromptRegistry.get_prompt_for_current_binding(action, DEVICE_TYPE.GAMEPAD)
	assert_not_null(rebound_texture, "Binding-aware prompt lookup should return a texture for rebound actions")
	if rebound_texture != null:
		assert_true(
			rebound_texture.resource_path.contains("button_rb"),
			"Binding-aware prompt lookup should use current InputMap binding texture"
		)
	_restore_action_events(action, original_events)

func _capture_action_events(action: StringName) -> Array[InputEvent]:
	var results: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return results
	for event in InputMap.action_get_events(action):
		if event is InputEvent:
			results.append((event as InputEvent).duplicate(true))
	return results

func _restore_action_events(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action).duplicate():
		InputMap.action_erase_event(action, event)
	for event in events:
		InputMap.action_add_event(action, event)

func _set_gamepad_binding(action: StringName, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action).duplicate():
		InputMap.action_erase_event(action, event)
	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = button_index
	InputMap.action_add_event(action, joy_event)

static func _reset_registry() -> void:
	U_ButtonPromptRegistry._clear_for_tests()
