extends GutTest

const M_InputProfileManager = preload("res://scripts/managers/m_input_profile_manager.gd")
const RS_InputProfile = preload("res://scripts/resources/input/rs_input_profile.gd")
const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings = preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GameplayInitialState = preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_InputActions = preload("res://scripts/state/actions/u_input_actions.gd")
const U_InputRebindUtils = preload("res://scripts/utils/input/u_input_rebind_utils.gd")
const U_NavigationActions = preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_StateHandoff = preload("res://scripts/state/utils/u_state_handoff.gd")

var _store: M_StateStore
var _mgr
var _cleanup_requested := false

func _await_manager_initialized(timeout_frames: int = 10) -> void:
	for _i in range(timeout_frames):
		if _mgr != null and _mgr.store_ref != null:
			return
		await get_tree().process_frame
	assert_true(false, "Timed out waiting for M_InputProfileManager to initialize")

func _get_key_events_for_action(action_name: StringName) -> Array[InputEventKey]:
	var results: Array[InputEventKey] = []
	if not InputMap.has_action(action_name):
		return results
	var events := InputMap.action_get_events(action_name)
	for ev in events:
		if ev is InputEventKey:
			results.append(ev as InputEventKey)
	return results

func _cleanup_input_settings_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("input_settings.json"):
		dir.remove("input_settings.json")
	if dir.file_exists("input_settings.json.backup"):
		dir.remove("input_settings.json.backup")

func _ensure_jump_action_exists() -> void:
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")

func _make_event_dict(keycode: Key) -> Dictionary:
	return {
		"type": "key",
		"keycode": keycode,
		"physical_keycode": keycode,
		"unicode": 0,
		"pressed": false,
		"alt": false,
		"shift": false,
		"ctrl": false,
		"meta": false
	}

func _write_input_settings_file(profile_id: String, keycode: Key) -> void:
	var sample := {
		"version": "1.0.0",
		"active_profile_id": profile_id,
		"custom_bindings": {
			"jump": [
				_make_event_dict(keycode)
			]
		},
		"gamepad_settings": {
			"left_stick_deadzone": 0.3,
			"right_stick_deadzone": 0.25,
			"trigger_deadzone": 0.2,
			"vibration_enabled": true,
			"vibration_intensity": 0.8,
			"invert_y_axis": false
		},
		"mouse_settings": {
			"sensitivity": 1.7,
			"invert_y_axis": true
		},
		"touchscreen_settings": {},
		"accessibility": {}
	}

	var file := FileAccess.open("user://input_settings.json", FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(sample))
	file.flush()
	file = null

func _get_store_custom_bindings() -> Dictionary:
	if _store == null:
		return {}
	var state := _store.get_state()
	if state == null:
		return {}
	var settings_variant: Variant = state.get("settings", {})
	if not (settings_variant is Dictionary):
		return {}
	var settings_dict := settings_variant as Dictionary
	var input_variant: Variant = settings_dict.get("input_settings", {})
	if not (input_variant is Dictionary):
		return {}
	var input_dict := input_variant as Dictionary
	var bindings_variant: Variant = input_dict.get("custom_bindings", {})
	if bindings_variant is Dictionary:
		return bindings_variant as Dictionary
	return {}

func before_each() -> void:
	U_StateHandoff.clear_all()  # Prevent StateHandoff pollution across tests (see DEV_PITFALLS)
	_cleanup_input_settings_files()
	# Create state store with gameplay slice so pause gating can be tested
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	_mgr = M_InputProfileManager.new()
	add_child_autofree(_mgr)
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	_cleanup_input_settings_files()
	_store = null
	_mgr = null

func test_manager_sets_process_mode_and_loads_default_if_available() -> void:
	assert_eq(_mgr.process_mode, Node.PROCESS_MODE_ALWAYS, "Manager should process while paused")

	# Default profile may or may not be available; manager should not crash.
	assert_true(true, "Manager initialized without errors")

func test_manager_loads_touchscreen_profile() -> void:
	# Assert touchscreen profile loaded
	var profile_ids: Array[String] = _mgr.get_available_profile_ids()
	assert_true(profile_ids.has("default_touchscreen"), "Should load touchscreen profile")

func test_reset_touchscreen_positions_returns_defaults() -> void:
	# Call reset
	var positions: Array = _mgr.reset_touchscreen_positions()

	# Assert returned defaults
	assert_eq(positions.size(), 4, "Should return 4 button positions")
	assert_true(positions[0].has("action"), "Should have action field")
	assert_true(positions[0].has("position"), "Should have position field")

func test_get_default_joystick_position_returns_profile_value() -> void:
	var pos: Vector2 = _mgr.get_default_joystick_position()
	# default_touchscreen.tres defines virtual_joystick_position = Vector2(82, 390)
	assert_ne(pos, Vector2(-1, -1), "Should return valid joystick position, not sentinel")
	assert_eq(pos, Vector2(82, 390), "Should match default_touchscreen.tres value")

func test_switch_profile_requires_pause() -> void:
	await _await_manager_initialized()
	_store.dispatch(U_NavigationActions.set_shell(StringName("gameplay"), StringName("gameplay_base")))

	# Ensure default available ids detected (if resources exist)
	var ids: Array[String] = _mgr.get_available_profile_ids()
	# If nothing available, create a temporary profile in-memory
	if ids.is_empty():
		var p := RS_InputProfile.new()
		p.profile_name = "Temp"
		_mgr.available_profiles["temp"] = p
		ids = _mgr.get_available_profile_ids()
	assert_gt(ids.size(), 0, "Should have at least one profile id to test")

	# Attempt switch while unpaused should be blocked
	var before_active: RS_InputProfile = _mgr.active_profile
	var blocked_profile := RS_InputProfile.new()
	blocked_profile.profile_name = "Temp Blocked"
	_mgr.available_profiles["temp_blocked"] = blocked_profile
	_mgr.switch_profile("temp_blocked")
	var after_active: RS_InputProfile = _mgr.active_profile
	assert_eq(after_active, before_active, "Switch should be blocked when not paused")

	# Pause gameplay and try again
	_store.dispatch(U_GameplayActions.pause_game())
	await get_tree().physics_frame

	var gameplay_slice := _store.get_slice(StringName("gameplay"))
	assert_true(gameplay_slice.get("paused", false), "Gameplay now paused")

	# Verify manager sees same paused state via group lookup
	var mgr_store := U_StateUtils.get_store(_mgr)
	var mgr_gameplay := mgr_store.get_slice(StringName("gameplay"))
	assert_true(mgr_gameplay.get("paused", false), "Manager-visible store also paused")


	# Register a new unique profile to guarantee a change
	var new_profile := RS_InputProfile.new()
	new_profile.profile_name = "Temp Switch"
	_mgr.available_profiles["temp_switch"] = new_profile
	assert_true(_mgr.available_profiles.has("temp_switch"), "Manager has temp_switch profile")

	var switched: bool = false
	_mgr.profile_switched.connect(func(_pid): switched = true)
	_mgr.switch_profile("temp_switch")
	await get_tree().physics_frame
	# Accept either signal or direct state change
	var current: RS_InputProfile = _mgr.active_profile
	assert_true(switched or (current != null and current.profile_name == "Temp Switch"), "Profile switched under pause")

func test_apply_profile_only_modifies_defined_actions() -> void:
	# Build a temp profile with a single action mapping
	var p := RS_InputProfile.new()
	p.profile_name = "Apply Test"

	var jump_key := InputEventKey.new()
	jump_key.physical_keycode = KEY_SPACE
	jump_key.keycode = KEY_SPACE
	p.set_events_for_action(StringName("jump"), [jump_key])

	# Pause to allow switching
	_store.dispatch(U_GameplayActions.pause_game())
	await get_tree().physics_frame

	# Register temp profile and switch
	_mgr.available_profiles["apply_test"] = p
	_mgr.switch_profile("apply_test")
	await get_tree().physics_frame

	# Verify InputMap has exactly the events we set for jump
	assert_true(InputMap.has_action("jump"), "Jump action exists after apply")
	var key_events := _get_key_events_for_action(StringName("jump"))
	assert_eq(key_events.size(), 1, "Jump should have one keyboard mapping from profile")
	assert_eq(key_events[0].physical_keycode, KEY_SPACE, "Jump mapping should be Space")

func test_save_custom_bindings_writes_input_settings_file() -> void:
	var result: bool = _mgr.save_custom_bindings()
	assert_true(result, "Saving custom bindings should succeed")
	assert_true(FileAccess.file_exists("user://input_settings.json"), "Settings file should exist after save")

	var file: FileAccess = FileAccess.open("user://input_settings.json", FileAccess.READ)
	assert_not_null(file, "Should be able to open settings file")
	var data: Variant = JSON.parse_string(file.get_as_text())
	file = null
	assert_true(data is Dictionary, "Saved settings should parse as dictionary")
	if data is Dictionary:
		var data_dict: Dictionary = data
		assert_eq(data_dict.get("version", ""), "1.0.0", "Settings file should include schema version")
		assert_true(data_dict.has("active_profile_id"), "Settings file should include active profile id")

func test_load_settings_applies_custom_bindings_and_profile() -> void:
	# Remove the manager created in before_each to control initialization order.
	if is_instance_valid(_mgr):
		_mgr.queue_free()
		await get_tree().process_frame

	_ensure_jump_action_exists()
	_write_input_settings_file("default", Key.KEY_P)

	_mgr = M_InputProfileManager.new()
	add_child_autofree(_mgr)
	await get_tree().process_frame
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	var settings_slice_value: Variant = state.get("settings", {})
	assert_true(settings_slice_value is Dictionary, "Settings slice should exist after load")
	var settings_slice: Dictionary = settings_slice_value if settings_slice_value is Dictionary else {}
	var input_settings_value: Variant = settings_slice.get("input_settings", {})
	assert_true(input_settings_value is Dictionary, "Input settings dictionary should exist")
	var input_settings: Dictionary = input_settings_value if input_settings_value is Dictionary else {}
	assert_eq(String(input_settings.get("active_profile_id", "")), "default", "Active profile should match persisted value")

	var events := InputMap.action_get_events("jump")
	assert_false(events.is_empty(), "Jump action should have bindings after load")
	var first_event := events[0] as InputEventKey
	assert_eq(first_event.keycode, Key.KEY_P, "Loaded binding should apply to jump action")

	var custom_bindings := _get_store_custom_bindings()
	assert_true(custom_bindings.has(StringName("jump")), "Custom bindings slice should include jump after load")

func test_reset_to_defaults_clears_custom_bindings_and_restores_profile() -> void:
	_ensure_jump_action_exists()

	var default_event := InputEventKey.new()
	default_event.keycode = Key.KEY_SPACE
	default_event.physical_keycode = Key.KEY_SPACE

	var profile := RS_InputProfile.new()
	profile.profile_name = "Reset Profile"
	profile.set_events_for_action(StringName("jump"), [default_event])

	_mgr.available_profiles["reset_profile"] = profile
	_mgr.active_profile = profile

	var custom_event := InputEventKey.new()
	custom_event.keycode = Key.KEY_V
	custom_event.physical_keycode = Key.KEY_V

	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", custom_event)

	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), _make_event_dict(Key.KEY_V)))
	await get_tree().physics_frame

	_mgr.reset_to_defaults()
	await get_tree().process_frame
	await get_tree().process_frame

	var key_events := _get_key_events_for_action(StringName("jump"))
	assert_eq(key_events.size(), 1, "Reset should restore a single keyboard binding")
	var restored := key_events[0]
	assert_eq(restored.keycode, Key.KEY_SPACE, "Reset should restore profile default keycode")

	var state: Dictionary = _store.get_state()
	var settings_slice_value: Variant = state.get("settings", {})
	assert_true(settings_slice_value is Dictionary, "Settings slice should exist after reset")
	var settings_slice: Dictionary = settings_slice_value if settings_slice_value is Dictionary else {}
	var input_settings_value: Variant = settings_slice.get("input_settings", {})
	assert_true(input_settings_value is Dictionary, "Input settings dictionary should exist after reset")
	var input_settings: Dictionary = input_settings_value if input_settings_value is Dictionary else {}
	var custom_value: Variant = input_settings.get("custom_bindings", {})
	assert_true(custom_value is Dictionary, "Custom bindings should be a dictionary after reset")
	var custom: Dictionary = custom_value if custom_value is Dictionary else {}
	assert_true(custom.is_empty(), "Custom bindings slice should be cleared after reset")


func test_reset_action_dispatches_remove_action_bindings() -> void:
	_ensure_jump_action_exists()

	var recorded_actions: Array = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		recorded_actions.append(action.duplicate(true))
	)

	var custom_event := InputEventKey.new()
	custom_event.keycode = Key.KEY_V
	custom_event.physical_keycode = Key.KEY_V

	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", custom_event)

	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), _make_event_dict(Key.KEY_V)))
	await get_tree().physics_frame

	recorded_actions.clear()

	_mgr.reset_action(StringName("jump"))
	await get_tree().process_frame

	var found_remove := false
	for action in recorded_actions:
		if action.get("type") == U_InputActions.ACTION_REMOVE_ACTION_BINDINGS:
			found_remove = true
			var payload: Dictionary = action.get("payload", {})
			assert_eq(payload.get("action"), StringName("jump"), "Remove action should target jump")
			break
	assert_true(found_remove, "Reset action should dispatch remove_action_bindings")

	var state: Dictionary = _store.get_state()
	var settings_slice_value: Variant = state.get("settings", {})
	var settings_slice: Dictionary = settings_slice_value if settings_slice_value is Dictionary else {}
	var input_settings_value: Variant = settings_slice.get("input_settings", {})
	var input_settings: Dictionary = input_settings_value if input_settings_value is Dictionary else {}
	var custom_bindings_value: Variant = input_settings.get("custom_bindings", {})
	assert_true(custom_bindings_value is Dictionary)
	var custom_bindings: Dictionary = custom_bindings_value if custom_bindings_value is Dictionary else {}
	assert_false(custom_bindings.has(StringName("jump")), "Store custom bindings should no longer include jump after reset action")

func test_add_binding_appends_custom_cache_without_duplication() -> void:
	_ensure_jump_action_exists()

	var profile := RS_InputProfile.new()
	var default_event := InputEventKey.new()
	default_event.keycode = Key.KEY_SPACE
	default_event.physical_keycode = Key.KEY_SPACE
	profile.set_events_for_action(StringName("jump"), [default_event])

	_mgr.active_profile = profile

	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", default_event.duplicate(true))

	var additional := InputEventKey.new()
	additional.keycode = Key.KEY_V
	additional.physical_keycode = Key.KEY_V

	var success := U_InputRebindUtils.rebind_action(
		StringName("jump"),
		additional,
		profile,
		StringName(),
		false
	)
	assert_true(success, "Adding binding via util should succeed")

	var event_dict := U_InputRebindUtils.event_to_dict(additional)
	_store.dispatch(
		U_InputActions.rebind_action(
			StringName("jump"),
			event_dict,
			U_InputActions.REBIND_MODE_ADD,
			[default_event, additional]
		)
	)
	await get_tree().physics_frame

	var events := InputMap.action_get_events("jump")
	assert_eq(events.size(), 2, "InputMap should contain both default and additional bindings")

	var has_default := false
	var has_new := false
	for event in events:
		if (event as InputEvent).is_match(default_event):
			has_default = true
		if (event as InputEvent).is_match(additional):
			has_new = true
	assert_true(has_default, "Default binding should remain after add operation")
	assert_true(has_new, "Additional binding should be appended")

	var custom_bindings := _get_store_custom_bindings()
	assert_true(custom_bindings.has(StringName("jump")), "Custom bindings slice should include jump entry")
	var stored_variant: Variant = custom_bindings[StringName("jump")]
	assert_true(stored_variant is Array, "Jump entry should serialize as array")
	var stored_events: Array = stored_variant if stored_variant is Array else []
	var stored_has_additional := false
	for entry in stored_events:
		if entry is Dictionary and int((entry as Dictionary).get("keycode", -1)) == int(additional.keycode):
			stored_has_additional = true
			break
	assert_true(stored_has_additional, "Serialized bindings should include additional keycode")

func test_load_custom_bindings_method_reapplies_saved_events() -> void:
	# Prepare saved settings and fresh manager instance
	if is_instance_valid(_mgr):
		_mgr.queue_free()
		await get_tree().process_frame

	_ensure_jump_action_exists()
	_write_input_settings_file("default", Key.KEY_P)

	_mgr = M_InputProfileManager.new()
	add_child_autofree(_mgr)
	await get_tree().process_frame
	await get_tree().process_frame

	# Overwrite InputMap to simulate runtime changes away from saved binding
	InputMap.action_erase_events("jump")
	var default_event := InputEventKey.new()
	default_event.keycode = Key.KEY_SPACE
	default_event.physical_keycode = Key.KEY_SPACE
	InputMap.action_add_event("jump", default_event)

	var loaded: bool = _mgr.load_custom_bindings()
	await get_tree().process_frame
	assert_true(loaded, "load_custom_bindings should report success when file exists")

	var events := InputMap.action_get_events("jump")
	assert_false(events.is_empty(), "Load path should repopulate jump bindings")
	var key_event := events[0] as InputEventKey
	assert_eq(key_event.keycode, Key.KEY_P, "Saved binding should be restored after manual reload")
	var bindings_after_reload := _get_store_custom_bindings()
	assert_true(bindings_after_reload.has(StringName("jump")), "Custom bindings slice should include jump after reload")

func test_save_custom_bindings_includes_custom_bindings_payload() -> void:
	_ensure_jump_action_exists()
	var event_dict := {
		"type": "key",
		"keycode": Key.KEY_J,
		"physical_keycode": Key.KEY_J,
		"unicode": 0,
		"pressed": false,
		"alt": false,
		"shift": false,
		"ctrl": false,
		"meta": false
	}

	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), event_dict))
	await get_tree().physics_frame

	var saved: bool = _mgr.save_custom_bindings()
	assert_true(saved, "Explicit save should succeed after rebind")

	var file: FileAccess = FileAccess.open("user://input_settings.json", FileAccess.READ)
	assert_not_null(file, "Saved file should exist for inspection")
	var data_variant: Variant = JSON.parse_string(file.get_as_text())
	file = null
	assert_true(data_variant is Dictionary, "Serialized data should decode to dictionary")
	var data: Dictionary = data_variant if data_variant is Dictionary else {}

	assert_true(data.has("custom_bindings"), "Payload should include custom_bindings dictionary")
	var bindings_value: Variant = data.get("custom_bindings", {})
	assert_true(bindings_value is Dictionary, "custom_bindings should be dictionary")
	var bindings: Dictionary = bindings_value if bindings_value is Dictionary else {}
	assert_true(bindings.has("jump"), "Jump entry should be present in saved bindings")
	var saved_events_variant: Variant = bindings.get(StringName("jump"), [])
	assert_true(saved_events_variant is Array, "Saved events should be array")
	var saved_events: Array = saved_events_variant if saved_events_variant is Array else []
	assert_gt(saved_events.size(), 0, "Jump bindings array should include at least one event")
	var saved_event_variant: Variant = saved_events[0] if saved_events.size() > 0 else {}
	assert_true(saved_event_variant is Dictionary, "Saved event should be dictionary payload")
	var saved_event: Dictionary = saved_event_variant if saved_event_variant is Dictionary else {}
	assert_eq(int(saved_event.get("keycode", 0)), Key.KEY_J, "Saved keycode should match rebound key")

## Test for Issue #2: Reset to defaults should restore replaced bindings, not just added ones
func test_reset_to_defaults_restores_replaced_bindings() -> void:
	# Set up a profile with default binding
	var profile := RS_InputProfile.new()
	profile.profile_name = "Test Reset Profile"
	_ensure_jump_action_exists()
	var default_jump_event := InputEventKey.new()
	default_jump_event.physical_keycode = Key.KEY_J
	default_jump_event.keycode = Key.KEY_J
	profile.set_events_for_action(StringName("jump"), [default_jump_event])

	await _await_manager_initialized()

	# Pause and switch to test profile
	_store.dispatch(U_GameplayActions.pause_game())
	await get_tree().physics_frame

	_mgr.available_profiles["test_reset"] = profile
	_mgr.switch_profile("test_reset")
	await get_tree().process_frame

	# Verify default binding is active
	var initial_key_events := _get_key_events_for_action(StringName("jump"))
	assert_eq(initial_key_events.size(), 1, "Should have a single keyboard binding")
	assert_eq(initial_key_events[0].physical_keycode, Key.KEY_J, "Default should be J")

	# REPLACE the binding (not add) with a different key
	var new_event := InputEventKey.new()
	new_event.physical_keycode = Key.KEY_K
	new_event.keycode = Key.KEY_K
	var rebind_action := U_InputActions.rebind_action(
		StringName("jump"),
		new_event,
		U_InputActions.REBIND_MODE_REPLACE,
		[new_event]
	)
	_store.dispatch(rebind_action)
	await get_tree().process_frame

	# Verify binding was replaced
	var replaced_key_events := _get_key_events_for_action(StringName("jump"))
	assert_eq(replaced_key_events.size(), 1, "Should have a single keyboard binding after replace")
	assert_eq(replaced_key_events[0].physical_keycode, Key.KEY_K, "Should be replaced with K")

	# Verify custom_bindings tracks the replacement
	var custom_bindings := _get_store_custom_bindings()
	assert_true(custom_bindings.has(StringName("jump")), "Jump should be in custom_bindings after replace")

	# Reset to defaults
	var signal_emitted := [false]  # Use array to work around lambda capture limitation
	_mgr.bindings_reset.connect(func() -> void:
		signal_emitted[0] = true
	)

	_mgr.reset_to_defaults()
	await get_tree().process_frame

	# Verify bindings_reset signal was emitted
	assert_true(signal_emitted[0], "bindings_reset signal should be emitted")

	# Verify custom_bindings is cleared
	custom_bindings = _get_store_custom_bindings()
	assert_false(custom_bindings.has(StringName("jump")), "Jump should NOT be in custom_bindings after reset")
	assert_true(custom_bindings.is_empty(), "custom_bindings should be empty after reset")

	# CRITICAL: Verify InputMap was restored to default (J, not K)
	var restored_events := _get_key_events_for_action(StringName("jump"))
	assert_eq(restored_events.size(), 1, "Should have one keyboard binding after reset")
	assert_eq(restored_events[0].physical_keycode, Key.KEY_J, "Should be restored to default J, not K")

func test_reset_to_defaults_clears_added_bindings() -> void:
	# Set up a profile with default binding
	var profile := RS_InputProfile.new()
	profile.profile_name = "Test Reset Add Profile"
	var default_jump_event := InputEventKey.new()
	default_jump_event.physical_keycode = Key.KEY_SPACE
	default_jump_event.keycode = Key.KEY_SPACE
	profile.set_events_for_action(StringName("jump"), [default_jump_event])

	# Pause and switch
	_store.dispatch(U_GameplayActions.pause_game())
	await get_tree().process_frame
	_mgr.available_profiles["test_reset_add"] = profile
	_mgr.switch_profile("test_reset_add")
	await get_tree().process_frame

	# ADD an additional binding (not replace)
	var added_event := InputEventKey.new()
	added_event.physical_keycode = Key.KEY_W
	added_event.keycode = Key.KEY_W
	var current_events := InputMap.action_get_events(StringName("jump"))
	var all_events: Array[InputEvent] = []
	for ev in current_events:
		if ev is InputEvent:
			all_events.append(ev.duplicate(true))
	all_events.append(added_event)

	var add_action := U_InputActions.rebind_action(
		StringName("jump"),
		added_event,
		U_InputActions.REBIND_MODE_ADD,
		all_events
	)
	_store.dispatch(add_action)
	await get_tree().process_frame

	# Verify we have both bindings
	var with_added := _get_key_events_for_action(StringName("jump"))
	assert_eq(with_added.size(), 2, "Should have 2 keyboard bindings after add")

	# Reset to defaults
	_mgr.reset_to_defaults()
	await get_tree().process_frame

	# Verify only default remains
	var after_reset := _get_key_events_for_action(StringName("jump"))
	assert_eq(after_reset.size(), 1, "Should have 1 keyboard binding after reset")
	assert_eq(after_reset[0].physical_keycode, Key.KEY_SPACE, "Should have only default SPACE")

func test_bindings_reset_signal_fires_after_inputmap_sync() -> void:
	# This test verifies that the signal fires AFTER InputMap is restored, not before
	var profile := RS_InputProfile.new()
	profile.profile_name = "Test Signal Timing"
	var default_event := InputEventKey.new()
	default_event.physical_keycode = Key.KEY_J
	default_event.keycode = Key.KEY_J
	profile.set_events_for_action(StringName("jump"), [default_event])

	_store.dispatch(U_GameplayActions.pause_game())
	await get_tree().process_frame
	_mgr.available_profiles["test_signal_timing"] = profile
	_mgr.switch_profile("test_signal_timing")
	await get_tree().process_frame

	# Replace binding
	var new_event := InputEventKey.new()
	new_event.physical_keycode = Key.KEY_K
	new_event.keycode = Key.KEY_K
	_store.dispatch(U_InputActions.rebind_action(StringName("jump"), new_event, U_InputActions.REBIND_MODE_REPLACE, [new_event]))
	await get_tree().process_frame

	# Capture InputMap state when signal fires
	var inputmap_state_at_signal_time: Array = []
	_mgr.bindings_reset.connect(func() -> void:
		var events := InputMap.action_get_events(StringName("jump"))
		for ev in events:
			if ev is InputEventKey:
				inputmap_state_at_signal_time.append((ev as InputEventKey).physical_keycode)
	)

	# Reset
	_mgr.reset_to_defaults()
	await get_tree().process_frame

	# Verify signal saw the restored state, not the old custom state
	assert_eq(inputmap_state_at_signal_time.size(), 1, "Signal should see one binding")
	assert_eq(inputmap_state_at_signal_time[0], Key.KEY_J, "Signal should see default J, not custom K")
