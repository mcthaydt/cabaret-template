extends GutTest

const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_InputProfileManager := preload("res://scripts/managers/m_input_profile_manager.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")

class FaultyStateStore extends M_StateStore:
	var intercepted_actions: Array = []
	var fail_types: Array[StringName] = []

	func dispatch(action: Dictionary) -> void:
		intercepted_actions.append(action.duplicate(true))
		var action_type: StringName = action.get("type", StringName())
		if action_type in fail_types:
			# Surface dispatch attempt without mutating state
			action_dispatched.emit(action.duplicate(true))
			return
		super.dispatch(action)

var _store: M_StateStore
var _manager: M_InputProfileManager

func before_each() -> void:
	_cleanup_input_settings_files()
	_clear_actions(["jump", "interact"])

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
	_clear_actions(["jump", "interact"])
	_cleanup_input_settings_files()
	await _pump()

func test_rebind_updates_store_and_input_map() -> void:
	_ensure_action(StringName("jump"))

	var new_event := InputEventKey.new()
	new_event.keycode = Key.KEY_F5
	new_event.physical_keycode = Key.KEY_F5
	new_event.pressed = true

	var action := U_InputActions.rebind_action(StringName("jump"), new_event, U_InputActions.REBIND_MODE_REPLACE, [new_event])
	_store.dispatch(action)
	await _pump()

	var events: Array = InputMap.action_get_events("jump")
	assert_eq(events.size(), 1, "InputMap should contain single binding after replace")
	assert_true((events[0] as InputEventKey).is_match(new_event), "InputMap should reflect rebind event")

	var bindings: Dictionary = _get_store_custom_bindings()
	var jump_key: Variant = _resolve_binding_key(bindings, StringName("jump"))
	assert_not_null(jump_key, "Store should record jump binding")
	var stored_events_variant: Variant = bindings.get(jump_key, [])
	assert_true(stored_events_variant is Array, "Stored binding should be serialized array")
	var stored_events: Array = stored_events_variant
	assert_eq(stored_events.size(), 1, "Stored binding array should contain single event")
	var stored_event_dict: Dictionary = stored_events[0]
	assert_eq(int(stored_event_dict.get("keycode", 0)), Key.KEY_F5, "Stored binding should match dispatched keycode")
	assert_eq(String(stored_event_dict.get("type", "")), "key", "Stored binding should serialize key event")

func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(String(action))

func test_conflicting_rebind_swaps_bindings() -> void:
	_ensure_action(StringName("jump"))
	_ensure_action(StringName("interact"))

	var jump_event := InputEventKey.new()
	jump_event.keycode = Key.KEY_SPACE
	jump_event.physical_keycode = Key.KEY_SPACE
	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", jump_event)

	var interact_event := InputEventKey.new()
	interact_event.keycode = Key.KEY_E
	interact_event.physical_keycode = Key.KEY_E
	InputMap.action_erase_events("interact")
	InputMap.action_add_event("interact", interact_event)

	var replacement := InputEventKey.new()
	replacement.keycode = Key.KEY_G
	replacement.physical_keycode = Key.KEY_G

	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), replacement, U_InputActions.REBIND_MODE_REPLACE))
	await _pump()

	_store.dispatch(U_InputActions.rebind_action(StringName("interact"), replacement, U_InputActions.REBIND_MODE_REPLACE))
	await _pump()

	var jump_events: Array = InputMap.action_get_events("jump")
	var jump_has_conflict := false
	for event in jump_events:
		if event is InputEventKey and (event as InputEventKey).keycode == Key.KEY_G:
			jump_has_conflict = true
			break
	assert_false(jump_has_conflict, "Jump should no longer reference conflicting key")

	var interact_events: Array = InputMap.action_get_events("interact")
	assert_eq(interact_events.size(), 1, "Interact should keep single binding after swap")
	var interact_key: InputEventKey = interact_events[0] as InputEventKey
	assert_eq(interact_key.keycode, Key.KEY_G, "Interact should adopt replacement key")

	var bindings: Dictionary = _get_store_custom_bindings()
	assert_false(bindings.has(StringName("jump")), "Jump should be removed from custom bindings after conflict swap")
	assert_true(bindings.has(StringName("interact")), "Interact should retain serialized binding after swap")

func test_save_and_load_roundtrip_preserves_bindings() -> void:
	_ensure_action(StringName("jump"))
	_ensure_action(StringName("interact"))

	var jump_event := InputEventKey.new()
	jump_event.keycode = Key.KEY_V
	jump_event.physical_keycode = Key.KEY_V
	var interact_event := InputEventKey.new()
	interact_event.keycode = Key.KEY_B
	interact_event.physical_keycode = Key.KEY_B

	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), jump_event, U_InputActions.REBIND_MODE_REPLACE))
	_store.dispatch(U_InputActions.rebind_action(StringName("interact"), interact_event, U_InputActions.REBIND_MODE_REPLACE))
	await _pump()

	var save_success: bool = _manager.save_custom_bindings()
	assert_true(save_success, "Save should succeed after applying custom bindings")

	if is_instance_valid(_manager):
		_manager.queue_free()
	if is_instance_valid(_store):
		_store.queue_free()
	await _pump()

	InputMap.action_erase_events("jump")
	InputMap.action_erase_events("interact")

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	await _pump()

	_manager = M_InputProfileManager.new()
	add_child_autofree(_manager)
	await _pump()
	await _pump()

	var load_success: bool = _manager.load_custom_bindings()
	await _pump()
	assert_true(load_success, "Load should succeed and dispatch payload to store")

	var restored_jump: Array = InputMap.action_get_events("jump")
	assert_eq(restored_jump.size(), 1, "Jump binding should be restored from disk")
	assert_eq((restored_jump[0] as InputEventKey).keycode, Key.KEY_V, "Jump restored key should match saved key")

	var restored_interact: Array = InputMap.action_get_events("interact")
	assert_eq(restored_interact.size(), 1, "Interact binding should be restored from disk")
	assert_eq((restored_interact[0] as InputEventKey).keycode, Key.KEY_B, "Interact restored key should match saved key")

	var reloaded_bindings: Dictionary = _get_store_custom_bindings()
	assert_true(reloaded_bindings.has(StringName("jump")))
	assert_true(reloaded_bindings.has(StringName("interact")))

func test_add_mode_preserves_existing_binding() -> void:
	_ensure_action(StringName("jump"))

	var default_event := InputEventKey.new()
	default_event.keycode = Key.KEY_J
	default_event.physical_keycode = Key.KEY_J
	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", default_event)

	var additional_event := InputEventKey.new()
	additional_event.keycode = Key.KEY_P
	additional_event.physical_keycode = Key.KEY_P

	var final_events: Array[InputEvent] = [
		default_event.duplicate(true),
		additional_event.duplicate(true)
	]

	_store.dispatch(
		U_InputActions.rebind_action(
			StringName("jump"),
			additional_event.duplicate(true),
			U_InputActions.REBIND_MODE_ADD,
			final_events
		)
	)
	await _pump()

	var events: Array = InputMap.action_get_events("jump")
	assert_eq(events.size(), 2, "InputMap should retain default and new bindings in add mode")

	var bindings: Dictionary = _get_store_custom_bindings()
	var jump_key: Variant = _resolve_binding_key(bindings, StringName("jump"))
	assert_not_null(jump_key, "Store should contain jump entry after add mode rebind")
	var stored_variant: Variant = bindings.get(jump_key, [])
	assert_true(stored_variant is Array, "Stored jump bindings should serialize as array")
	var stored_events: Array = []
	if stored_variant is Array:
		stored_events = stored_variant as Array
	assert_eq(stored_events.size(), 2, "Store should persist both default and additional bindings")
	var stored_keycodes: Array[int] = []
	for entry in stored_events:
		if entry is Dictionary:
			stored_keycodes.append(int((entry as Dictionary).get("keycode", -1)))
	stored_keycodes.sort()
	assert_true(stored_keycodes.has(Key.KEY_J), "Custom bindings should include default keycode in add mode")
	assert_true(stored_keycodes.has(Key.KEY_P), "Custom bindings should include added keycode in add mode")

func test_failed_dispatch_does_not_mutate_inputmap() -> void:
	if is_instance_valid(_manager):
		_manager.queue_free()
	if is_instance_valid(_store):
		_store.queue_free()
	await _pump()

	U_StateHandoff.clear_all()
	_cleanup_input_settings_files()

	var faulty := FaultyStateStore.new()
	faulty.settings = RS_StateStoreSettings.new()
	if faulty.settings != null:
		faulty.settings.enable_persistence = false
	faulty.gameplay_initial_state = RS_GameplayInitialState.new()
	faulty.settings_initial_state = RS_SettingsInitialState.new()
	faulty.fail_types.append(U_InputActions.ACTION_REBIND_ACTION)
	add_child_autofree(faulty)
	await _pump()

	_store = faulty

	_manager = M_InputProfileManager.new()
	add_child_autofree(_manager)
	await _pump()
	await _pump()

	var action_name := StringName("jump")
	_ensure_action(action_name)

	InputMap.action_erase_events(action_name)
	var baseline := InputEventKey.new()
	baseline.keycode = Key.KEY_SPACE
	baseline.physical_keycode = Key.KEY_SPACE
	InputMap.action_add_event(action_name, baseline)

	var failing_event := InputEventKey.new()
	failing_event.keycode = Key.KEY_Z
	failing_event.physical_keycode = Key.KEY_Z

	var action_dict: Dictionary = U_InputActions.rebind_action(action_name, failing_event)
	faulty.dispatch(action_dict)
	await _pump()

	var current_events: Array = InputMap.action_get_events(action_name)
	assert_eq(current_events.size(), 1, "InputMap should retain single event when dispatch fails")
	assert_true((current_events[0] as InputEventKey).is_match(baseline), "Baseline key should remain active after failed dispatch")

	var bindings_after_fail: Dictionary = _get_store_custom_bindings()
	assert_false(bindings_after_fail.has(action_name), "Store should not record bindings for failed dispatch")

	assert_eq(faulty.intercepted_actions.size(), 1, "Faulty store should have intercepted single action")

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

func _resolve_binding_key(bindings: Dictionary, action: StringName) -> Variant:
	if bindings.has(action):
		return action
	var action_str: String = String(action)
	if bindings.has(action_str):
		return action_str
	return null

func _cleanup_input_settings_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("global_settings.json"):
		dir.remove("global_settings.json")
	if dir.file_exists("global_settings.json.backup"):
		dir.remove("global_settings.json.backup")

func test_rebind_keyboard_preserves_gamepad_bindings() -> void:
	_ensure_action(StringName("jump"))

	# Set up initial bindings via Redux (keyboard Space + gamepad Button A)
	var keyboard_event := InputEventKey.new()
	keyboard_event.keycode = Key.KEY_SPACE
	keyboard_event.physical_keycode = Key.KEY_SPACE
	keyboard_event.pressed = true

	var gamepad_event := InputEventJoypadButton.new()
	gamepad_event.button_index = JOY_BUTTON_A
	gamepad_event.pressed = true

	var initial_events: Array[InputEvent] = [keyboard_event, gamepad_event]
	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), keyboard_event, U_InputActions.REBIND_MODE_REPLACE, initial_events))
	await _pump()

	# Verify initial state
	var setup_events: Array = InputMap.action_get_events("jump")
	assert_eq(setup_events.size(), 2, "Should start with both keyboard and gamepad bindings")

	# Rebind keyboard to K (device-aware: preserve gamepad, replace keyboard)
	var new_keyboard_event := InputEventKey.new()
	new_keyboard_event.keycode = Key.KEY_K
	new_keyboard_event.physical_keycode = Key.KEY_K
	new_keyboard_event.pressed = true

	# Simulate UI logic: filter events to preserve OTHER device types only
	var current_events := InputMap.action_get_events("jump")
	var final_target: Array[InputEvent] = []
	for event in current_events:
		# Preserve gamepad events (different device type)
		if event is InputEventJoypadButton:
			final_target.append(event.duplicate(true))
	# Add the new keyboard event (replaces old keyboard)
	final_target.append(new_keyboard_event)

	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), new_keyboard_event, U_InputActions.REBIND_MODE_REPLACE, final_target))
	await _pump()

	# Verify gamepad binding still exists
	var final_events: Array = InputMap.action_get_events("jump")
	assert_eq(final_events.size(), 2, "Should have both keyboard and gamepad bindings after keyboard rebind")

	var has_keyboard := false
	var has_gamepad := false
	for event in final_events:
		if event is InputEventKey:
			assert_eq((event as InputEventKey).keycode, Key.KEY_K, "Keyboard binding should be updated to K")
			has_keyboard = true
		elif event is InputEventJoypadButton:
			assert_eq((event as InputEventJoypadButton).button_index, JOY_BUTTON_A, "Gamepad binding should be preserved")
			has_gamepad = true

	assert_true(has_keyboard, "Should have keyboard binding")
	assert_true(has_gamepad, "Should have gamepad binding")

func test_rebind_gamepad_preserves_keyboard_bindings() -> void:
	_ensure_action(StringName("sprint"))

	# Set up initial bindings via Redux (keyboard Shift + gamepad L3)
	var keyboard_event := InputEventKey.new()
	keyboard_event.keycode = Key.KEY_SHIFT
	keyboard_event.physical_keycode = Key.KEY_SHIFT
	keyboard_event.pressed = true

	var gamepad_event := InputEventJoypadButton.new()
	gamepad_event.button_index = JOY_BUTTON_LEFT_STICK
	gamepad_event.pressed = true

	var initial_events: Array[InputEvent] = [keyboard_event, gamepad_event]
	_store.dispatch(U_InputActions.rebind_action(StringName("sprint"), keyboard_event, U_InputActions.REBIND_MODE_REPLACE, initial_events))
	await _pump()

	# Verify initial state
	var setup_events: Array = InputMap.action_get_events("sprint")
	assert_eq(setup_events.size(), 2, "Should start with both keyboard and gamepad bindings")

	# Rebind gamepad to Button B (device-aware: preserve keyboard, replace gamepad)
	var new_gamepad_event := InputEventJoypadButton.new()
	new_gamepad_event.button_index = JOY_BUTTON_B
	new_gamepad_event.pressed = true

	# Simulate UI logic: filter events to preserve OTHER device types only
	var current_events := InputMap.action_get_events("sprint")
	var final_target: Array[InputEvent] = []
	for event in current_events:
		# Preserve keyboard events (different device type)
		if event is InputEventKey:
			final_target.append(event.duplicate(true))
	# Add the new gamepad event (replaces old gamepad)
	final_target.append(new_gamepad_event)

	_store.dispatch(U_InputActions.rebind_action(StringName("sprint"), new_gamepad_event, U_InputActions.REBIND_MODE_REPLACE, final_target))
	await _pump()

	# Verify keyboard binding still exists
	var final_events: Array = InputMap.action_get_events("sprint")
	assert_eq(final_events.size(), 2, "Should have both keyboard and gamepad bindings after gamepad rebind")

	var has_keyboard := false
	var has_gamepad := false
	for event in final_events:
		if event is InputEventKey:
			assert_eq((event as InputEventKey).keycode, Key.KEY_SHIFT, "Keyboard binding should be preserved")
			has_keyboard = true
		elif event is InputEventJoypadButton:
			assert_eq((event as InputEventJoypadButton).button_index, JOY_BUTTON_B, "Gamepad binding should be updated to B")
			has_gamepad = true

	assert_true(has_keyboard, "Should have keyboard binding")
	assert_true(has_gamepad, "Should have gamepad binding")

func test_reset_bindings_clears_redux_custom_bindings() -> void:
	_ensure_action(StringName("jump"))

	# Set up default bindings via Redux (keyboard Space + gamepad Button A)
	# This simulates what the profile manager would do when loading a profile
	var default_keyboard := InputEventKey.new()
	default_keyboard.keycode = Key.KEY_SPACE
	default_keyboard.physical_keycode = Key.KEY_SPACE
	default_keyboard.pressed = true

	var default_gamepad := InputEventJoypadButton.new()
	default_gamepad.button_index = JOY_BUTTON_A
	default_gamepad.pressed = true

	# Apply defaults via custom bindings (this will be cleared on reset)
	var default_events: Array[InputEvent] = [default_keyboard, default_gamepad]
	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), default_keyboard, U_InputActions.REBIND_MODE_REPLACE, default_events))
	await _pump()

	# Verify defaults are set
	var initial_events: Array = InputMap.action_get_events("jump")
	assert_eq(initial_events.size(), 2, "Should have both default bindings")

	# Rebind to custom keyboard binding (device-aware: preserves gamepad)
	var custom_keyboard := InputEventKey.new()
	custom_keyboard.keycode = Key.KEY_K
	custom_keyboard.physical_keycode = Key.KEY_K
	custom_keyboard.pressed = true

	# Filter to preserve gamepad, replace keyboard
	var current_for_custom := InputMap.action_get_events("jump")
	var custom_target: Array[InputEvent] = []
	for event in current_for_custom:
		if event is InputEventJoypadButton:
			custom_target.append(event.duplicate(true))
	custom_target.append(custom_keyboard)

	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), custom_keyboard, U_InputActions.REBIND_MODE_REPLACE, custom_target))
	await _pump()

	# Verify custom keyboard binding applied (K + gamepad A)
	var custom_events: Array = InputMap.action_get_events("jump")
	assert_eq(custom_events.size(), 2, "Should have custom keyboard + default gamepad")
	var has_custom_k := false
	for event in custom_events:
		if event is InputEventKey and (event as InputEventKey).keycode == Key.KEY_K:
			has_custom_k = true
	assert_true(has_custom_k, "Should have custom K binding before reset")

	# Reset to defaults (clears custom_bindings)
	# Note: This test verifies that reset clears custom bindings, but restoring
	# profile defaults requires the manager to have an active profile loaded.
	# In this integration test, we're testing the Redux flow, not the full
	# manager profile restoration (that would be a separate manager unit test).
	_store.dispatch(U_InputActions.reset_bindings())
	await _pump()

	# After reset, custom_bindings is empty
	# The manager would normally reapply the active profile, but in this
	# integration test context, the InputMap will be cleared
	var reset_events: Array = InputMap.action_get_events("jump")

	# Since we don't have a real profile manager with loaded profiles in this test,
	# we can only verify that custom bindings were cleared from Redux state
	var bindings_after_reset: Dictionary = _get_store_custom_bindings()
	assert_false(bindings_after_reset.has(StringName("jump")), "Custom bindings should be cleared after reset")

func _pump() -> void:
	await get_tree().process_frame
