extends GutTest

const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_InputProfileManager := preload("res://scripts/managers/m_input_profile_manager.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")

var _store: M_StateStore
var _manager: M_InputProfileManager

func before_each() -> void:
	_cleanup_input_settings_files()
	_clear_actions(["sprint", "jump"])

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	if _store.settings != null:
		_store.settings.enable_persistence = false
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	await _pump()

	_manager = M_InputProfileManager.new()
	add_child_autofree(_manager)
	await _pump()
	await _pump()

func after_each() -> void:
	if is_instance_valid(_manager):
		_manager.queue_free()
	if is_instance_valid(_store):
		_store.queue_free()
	_store = null
	_manager = null
	_clear_actions(["sprint", "jump"])
	_cleanup_input_settings_files()
	await _pump()

func test_reset_restores_keyboard_and_gamepad_defaults() -> void:
	_ensure_action(StringName("sprint"))

	# Wait for profiles to load
	await _pump()
	await _pump()

	# Verify profiles are loaded
	var profile_ids := _manager.get_available_profile_ids()
	assert_true(profile_ids.has("default_gamepad"), "Should have default_gamepad profile loaded")
	assert_true(profile_ids.has("default"), "Should have default keyboard profile loaded")

	# Get initial default bindings (should be empty from InputMap until profiles are applied)
	# The manager loads profiles but doesn't automatically apply them until an action triggers it

	# Rebind sprint gamepad to Button B (index 1)
	var custom_gamepad := InputEventJoypadButton.new()
	custom_gamepad.button_index = JOY_BUTTON_B  # Button B
	custom_gamepad.pressed = true

	# Get current events and filter to build device-aware target
	var current_events := InputMap.action_get_events("sprint")
	var custom_target: Array[InputEvent] = []

	# Preserve keyboard events
	for event in current_events:
		if event is InputEventKey:
			custom_target.append(event.duplicate(true))

	# Add custom gamepad B
	custom_target.append(custom_gamepad)

	_store.dispatch(U_InputActions.rebind_action(StringName("sprint"), custom_gamepad, U_InputActions.REBIND_MODE_REPLACE, custom_target))
	await _pump()
	await _pump()

	# Verify custom gamepad B is applied
	var custom_events: Array = InputMap.action_get_events("sprint")
	var has_button_b := false
	for event in custom_events:
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			has_button_b = true
	assert_true(has_button_b, "Should have custom Button B binding before reset")

	# Reset to defaults
	_manager.reset_to_defaults()
	await _pump()
	await _pump()

	# Verify defaults are restored for BOTH keyboard and gamepad
	var reset_events: Array = InputMap.action_get_events("sprint")

	# Should have keyboard Shift (physical_keycode 4194325)
	var has_keyboard_shift := false
	var has_gamepad_l3 := false

	for event in reset_events:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode == 4194325:  # Shift
				has_keyboard_shift = true
		elif event is InputEventJoypadButton:
			var joy_event := event as InputEventJoypadButton
			# L3 is button index 7
			if joy_event.button_index == 7:
				has_gamepad_l3 = true

	assert_true(has_keyboard_shift, "Should restore default keyboard Shift binding")
	assert_true(has_gamepad_l3, "Should restore default gamepad L3 binding")

	# Verify custom bindings cleared from Redux
	var bindings: Dictionary = _get_store_custom_bindings()
	assert_false(bindings.has(StringName("sprint")), "Custom bindings should be cleared from Redux")

func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(String(action))

func _clear_actions(names: Array[String]) -> void:
	for name in names:
		var action: StringName = StringName(name)
		if InputMap.has_action(action):
			InputMap.erase_action(action)

func _get_store_custom_bindings() -> Dictionary:
	if _store == null:
		return {}
	var state_variant: Variant = _store.get_state()
	if not (state_variant is Dictionary):
		return {}
	var state_dict: Dictionary = state_variant as Dictionary
	var settings_variant: Variant = state_dict.get("settings", {})
	if not (settings_variant is Dictionary):
		return {}
	var input_variant: Variant = (settings_variant as Dictionary).get("input_settings", {})
	if not (input_variant is Dictionary):
		return {}
	var bindings_variant: Variant = (input_variant as Dictionary).get("custom_bindings", {})
	if bindings_variant is Dictionary:
		return bindings_variant
	return {}

func _cleanup_input_settings_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("global_settings.json"):
		dir.remove("global_settings.json")
	if dir.file_exists("global_settings.json.backup"):
		dir.remove("global_settings.json.backup")

func _pump() -> void:
	await get_tree().process_frame
