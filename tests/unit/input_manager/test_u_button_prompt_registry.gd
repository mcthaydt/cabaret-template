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

static func _reset_registry() -> void:
	U_ButtonPromptRegistry._clear_for_tests()
