extends GutTest

const OverlayScene := preload("res://scenes/ui/overlays/ui_input_rebinding_overlay.tscn")
const M_InputProfileManager := preload("res://scripts/managers/m_input_profile_manager.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const TEST_SAVEGAME_PATH := "user://test_savegame.json"
var _store: M_StateStore
var _manager: M_InputProfileManager
var _overlay: Control

func _get_keyboard_events(action_name: StringName) -> Array[InputEventKey]:
	var results: Array[InputEventKey] = []
	if not InputMap.has_action(action_name):
		return results
	var events := InputMap.action_get_events(action_name)
	for ev in events:
		if ev is InputEventKey:
			results.append(ev as InputEventKey)
	return results

func before_each() -> void:
	U_StateHandoff.clear_all()
	_cleanup_input_settings_files()
	_spawn_store_and_manager()
	_spawn_overlay()
	await _pump()
	await _pump()
	await _pump()

func after_each() -> void:
	if is_instance_valid(_manager):
		_manager.reset_to_defaults()
		await _pump()
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		await _pump()
	if is_instance_valid(_manager):
		_manager.queue_free()
		await _pump()
	if is_instance_valid(_store):
		_store.queue_free()
		await _pump()
	_store = null
	_manager = null
	_overlay = null
	_cleanup_input_settings_files()
	U_StateHandoff.clear_all()
	# Extra pumps to ensure all deferred calls from previous test are complete
	await _pump()
	await _pump()
	await _pump()

func test_rebinding_workflow_end_to_end() -> void:
	var rows := _get_action_rows()
	var jump_replace: Button = rows[StringName("jump")].get("replace_button")
	jump_replace.emit_signal("pressed")
	await _pump()

	var conflict_event := InputEventKey.new()
	conflict_event.keycode = Key.KEY_E
	conflict_event.physical_keycode = Key.KEY_E
	conflict_event.pressed = true
	_overlay.call("_input", conflict_event)
	await _pump()
	_overlay._on_conflict_confirmed()
	await _pump()

	var jump_events: Array = InputMap.action_get_events(StringName("jump"))
	assert_eq(jump_events.size(), 1, "Replace binding should result in single jump binding")
	assert_true((jump_events[0] as InputEvent).is_match(conflict_event))
	var original_jump := InputEventKey.new()
	original_jump.keycode = Key.KEY_SPACE
	original_jump.physical_keycode = Key.KEY_SPACE
	var interact_events := InputMap.action_get_events(StringName("interact"))
	var interact_has_original_jump := false
	for interact_event in interact_events:
		if (interact_event as InputEvent).is_match(original_jump):
			interact_has_original_jump = true
	var debug_state: Dictionary = _store.get_state()
	var debug_settings: Dictionary = debug_state.get("settings", {})
	var debug_input_settings: Dictionary = debug_settings.get("input_settings", {})
	var debug_custom_bindings: Dictionary = debug_input_settings.get("custom_bindings", {})
	assert_true(interact_has_original_jump, "Conflict confirm should transfer previous Jump binding to Interact")
	var state: Dictionary = _store.get_state()
	var settings_slice_value: Variant = state.get("settings", {})
	var settings_slice: Dictionary = settings_slice_value if settings_slice_value is Dictionary else {}
	var input_settings_value: Variant = settings_slice.get("input_settings", {})
	var input_settings: Dictionary = input_settings_value if input_settings_value is Dictionary else {}
	var custom_bindings_value: Variant = input_settings.get("custom_bindings", {})
	var custom_bindings: Dictionary = custom_bindings_value if custom_bindings_value is Dictionary else {}
	var jump_key: Variant = StringName("jump")
	if not custom_bindings.has(jump_key) and custom_bindings.has("jump"):
		jump_key = "jump"
	assert_true(custom_bindings.has(jump_key), "Store should record custom jump bindings")
	var stored_jump_events_value: Variant = custom_bindings.get(jump_key, [])
	assert_true(stored_jump_events_value is Array, "Stored jump events should be an array")
	var stored_jump_events: Array = stored_jump_events_value if stored_jump_events_value is Array else []
	assert_eq(stored_jump_events.size(), 1)
	var stored_event_value: Variant = stored_jump_events[0] if stored_jump_events.size() > 0 else {}
	assert_true(stored_event_value is Dictionary, "Stored event payload should be dictionary")
	var stored_event: Dictionary = stored_event_value if stored_event_value is Dictionary else {}
	assert_eq(int(stored_event.get("keycode", 0)), Key.KEY_E)

	var jump_add: Button = rows[StringName("jump")].get("add_button")
	jump_add.emit_signal("pressed")
	await _pump()

	var add_event := InputEventKey.new()
	add_event.keycode = Key.KEY_K
	add_event.physical_keycode = Key.KEY_K
	add_event.pressed = true
	_overlay.call("_input", add_event)
	await _pump()

	jump_events = InputMap.action_get_events(StringName("jump"))
	assert_eq(jump_events.size(), 2, "Add binding should retain existing mapping and append new input")
	var has_e := false
	var has_k := false
	for event in jump_events:
		var key_event := event as InputEventKey
		if key_event == null:
			continue
		if key_event.keycode == Key.KEY_E:
			has_e = true
		if key_event.keycode == Key.KEY_K:
			has_k = true
	assert_true(has_e, "Original replacement binding should remain after add")
	assert_true(has_k, "Added binding should be present")

	state = _store.get_state()
	settings_slice_value = state.get("settings", {})
	settings_slice = settings_slice_value if settings_slice_value is Dictionary else {}
	input_settings_value = settings_slice.get("input_settings", {})
	input_settings = input_settings_value if input_settings_value is Dictionary else {}
	custom_bindings_value = input_settings.get("custom_bindings", {})
	custom_bindings = custom_bindings_value if custom_bindings_value is Dictionary else {}
	jump_key = StringName("jump")
	if not custom_bindings.has(jump_key) and custom_bindings.has("jump"):
		jump_key = "jump"
	stored_jump_events_value = custom_bindings.get(jump_key, [])
	assert_true(stored_jump_events_value is Array, "Stored jump events should be an array after add")
	stored_jump_events = stored_jump_events_value if stored_jump_events_value is Array else []
	assert_eq(stored_jump_events.size(), 2, "Custom binding cache should track both bindings")
	var stored_keys: Array = stored_jump_events.map(func(entry):
		var entry_dict: Dictionary = entry if entry is Dictionary else {}
		return int(entry_dict.get("keycode", -1))
	)
	assert_true(stored_keys.has(Key.KEY_E))
	assert_true(stored_keys.has(Key.KEY_K))

func test_custom_bindings_persist_via_save_and_reload() -> void:
	var rows := _get_action_rows()
	var replace_button: Button = rows[StringName("jump")].get("replace_button")
	replace_button.emit_signal("pressed")
	await _pump()
	await _pump()  # Wait additional frame for capture guard to clear

	var new_event := InputEventKey.new()
	new_event.keycode = Key.KEY_V
	new_event.physical_keycode = Key.KEY_V
	new_event.pressed = true
	_overlay.call("_input", new_event)
	await _pump()

	# KEY_V conflicts with ui_paste, so we need to confirm the conflict
	_overlay._on_conflict_confirmed()
	await _pump()

	var overlay_store_value: Variant = _overlay.get("_store") if _overlay != null else null
	assert_not_null(overlay_store_value, "Overlay should maintain store reference during capture flow")

	var pre_save_state: Dictionary = _store.get_state()
	var pre_save_settings_value: Variant = pre_save_state.get("settings", {})
	var pre_save_settings: Dictionary = pre_save_settings_value if pre_save_settings_value is Dictionary else {}
	var pre_save_input_settings_value: Variant = pre_save_settings.get("input_settings", {})
	var pre_save_input_settings: Dictionary = pre_save_input_settings_value if pre_save_input_settings_value is Dictionary else {}
	var pre_save_bindings_value: Variant = pre_save_input_settings.get("custom_bindings", {})
	var pre_save_bindings: Dictionary = pre_save_bindings_value if pre_save_bindings_value is Dictionary else {}

	var save_success := _manager.save_custom_bindings()
	assert_true(save_success, "Manager should report successful save")
	assert_true(FileAccess.file_exists("user://input_settings.json"), "Save file should be written to disk")
	# Log the raw JSON saved to disk for verification
	var saved_json := _read_user_input_settings_json()

	if is_instance_valid(_overlay):
		_overlay.queue_free()
		await _pump()
	_overlay = null
	if is_instance_valid(_manager):
		_manager.queue_free()
		await _pump()
	if is_instance_valid(_store):
		_store.queue_free()
		await _pump()
	_store = null
	_manager = null

	_reset_input_map()

	_spawn_store_and_manager()
	await _pump()
	await _pump()
	# One more frame to ensure manager applied pending bindings
	await _pump()

	# Diagnostics after reload
	assert_not_null(_manager, "Manager should reload after reset")
	if _manager != null:
		var ap: Variant = _manager.get("active_profile") if "active_profile" in _manager else null
		assert_not_null(ap, "Active profile should be set after reload")

	# Also re-read the file to confirm persisted content remains intact
	saved_json = _read_user_input_settings_json()

	var jump_events := _get_keyboard_events(StringName("jump"))
	assert_false(jump_events.is_empty(), "Jump action should have keyboard events after reload")
	assert_eq(jump_events[0].keycode, Key.KEY_V, "Custom binding should be restored on new manager initialization")

	var state: Dictionary = _store.get_state()
	var settings_slice_value: Variant = state.get("settings", {})
	var settings_slice: Dictionary = settings_slice_value if settings_slice_value is Dictionary else {}
	var input_settings_value: Variant = settings_slice.get("input_settings", {})
	var input_settings: Dictionary = input_settings_value if input_settings_value is Dictionary else {}
	var custom_bindings_value: Variant = input_settings.get("custom_bindings", {})
	var custom_bindings: Dictionary = custom_bindings_value if custom_bindings_value is Dictionary else {}
	var jump_key: Variant = StringName("jump")
	if not custom_bindings.has(jump_key) and custom_bindings.has("jump"):
		jump_key = "jump"
	assert_true(custom_bindings.has(jump_key), "Settings slice should contain restored custom binding entry")
	var stored_events_value: Variant = custom_bindings.get(jump_key, [])
	assert_true(stored_events_value is Array, "Stored events list should be an array")
	var stored_events: Array = stored_events_value if stored_events_value is Array else []
	assert_gt(stored_events.size(), 0, "Stored events should include at least one entry")
	var found_key_binding := false
	for stored_event_value in stored_events:
		if not (stored_event_value is Dictionary):
			continue
		var stored_event: Dictionary = stored_event_value
		if int(stored_event.get("keycode", -1)) == Key.KEY_V or int(stored_event.get("physical_keycode", -1)) == Key.KEY_V:
			found_key_binding = true
			break
	assert_true(found_key_binding, "Stored events should include the custom keyboard binding")

func _spawn_store_and_manager() -> void:
	if not is_instance_valid(_store):
		_store = M_StateStore.new()
		_store.settings = RS_StateStoreSettings.new()
		_store.settings.save_path_override = TEST_SAVEGAME_PATH
		_store.gameplay_initial_state = RS_GameplayInitialState.new()
		_store.settings_initial_state = RS_SettingsInitialState.new()
		add_child_autofree(_store)
	if not is_instance_valid(_manager):
		_manager = M_InputProfileManager.new()
		add_child_autofree(_manager)

func _spawn_overlay() -> void:
	if is_instance_valid(_overlay):
		return
	_overlay = OverlayScene.instantiate()
	add_child_autofree(_overlay)

func _get_action_rows() -> Dictionary:
	var rows_value: Variant = _overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose _action_rows dictionary")
	return rows_value if rows_value is Dictionary else {}

func _cleanup_input_settings_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("input_settings.json"):
		dir.remove("input_settings.json")
	if dir.file_exists("input_settings.json.backup"):
		dir.remove("input_settings.json.backup")
	if dir.file_exists(TEST_SAVEGAME_PATH.get_file()):
		dir.remove(TEST_SAVEGAME_PATH.get_file())

func _reset_input_map() -> void:
	var actions := ["jump", "interact", "move_forward", "move_backward", "move_left", "move_right", "sprint"]
	for action_name in actions:
		var action := StringName(action_name)
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action).duplicate():
				InputMap.action_erase_event(action, event)

func _pump() -> void:
	await get_tree().process_frame

func _describe_events(action: StringName) -> Array:
	var summaries: Array = []
	if action == StringName():
		return summaries
	for raw_event in InputMap.action_get_events(action):
		if raw_event is InputEventKey:
			var key_event := raw_event as InputEventKey
			summaries.append("key:%d phys:%d unicode:%d pressed:%s" % [
				key_event.keycode,
				key_event.physical_keycode,
				key_event.unicode,
				str(key_event.pressed)
			])
		elif raw_event is InputEventMouseButton:
			var mouse_event := raw_event as InputEventMouseButton
			summaries.append("mouse_button:%d pressed:%s" % [
				mouse_event.button_index,
				str(mouse_event.pressed)
			])
		else:
			summaries.append(raw_event.get_class())
	return summaries

func _read_user_input_settings_json() -> String:
	var path := "user://input_settings.json"
	if not FileAccess.file_exists(path):
		return "<missing>"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "<open failed>"
	var text := f.get_as_text()
	f = null
	return text
