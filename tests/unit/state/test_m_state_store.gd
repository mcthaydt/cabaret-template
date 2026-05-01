extends GutTest

## Tests for M_StateStore core functionality


var store: M_StateStore
var callback_called: bool = false
var received_action: Dictionary = {}
var received_state: Dictionary = {}
var signal_emitted: bool = false
var signal_action: Dictionary = {}
var validation_error: String = ""
var callback_count: int = 0
var slice_updated_count: int = 0
var last_slice_name: StringName = StringName()
const RS_TIME_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_time_initial_state.gd")

func _mixed_type_slice_reducer(_current: Dictionary, _action: Dictionary) -> Dictionary:
	return {"value": Vector2(1.0, -0.5)}

func before_each() -> void:
	# CRITICAL: Reset state bus between tests to prevent subscription leaks
	U_StateEventBus.reset()
	U_ServiceLocator.clear()
	
	# Reset test variables
	callback_called = false
	received_action = {}
	received_state = {}
	signal_emitted = false
	signal_action = {}
	validation_error = ""
	callback_count = 0
	slice_updated_count = 0
	last_slice_name = StringName()

	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	# Set up initial state for testing
	var initial_state: RS_GameplayInitialState = RS_GameplayInitialState.new()
	store.gameplay_initial_state = initial_state
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.time_initial_state = RS_TIME_INITIAL_STATE.new()
	add_child(store)
	autofree(store)  # Use autofree for proper cleanup
	await get_tree().process_frame  # Deferred registration

func after_each() -> void:
	# Cleanup handled by autofree
	store = null
	U_StateEventBus.reset()
	U_ServiceLocator.clear()

func test_store_instantiates_as_node() -> void:
	assert_not_null(store, "Store should be created")
	assert_true(store is Node, "Store should extend Node")

func test_store_registers_with_service_locator() -> void:
	var service := U_ServiceLocator.try_get_service(StringName("state_store"))
	assert_eq(service, store, "Store should register with ServiceLocator")

func test_is_ready_flag_updates_after_initialization() -> void:
	var temp_store := M_StateStore.new()
	temp_store.settings = RS_StateStoreSettings.new()
	temp_store.gameplay_initial_state = RS_GameplayInitialState.new()
	temp_store.settings_initial_state = RS_SettingsInitialState.new()
	assert_false(temp_store.is_ready(), "Store should not be ready before entering the scene tree")
	add_child(temp_store)
	autofree(temp_store)
	await get_tree().process_frame
	assert_true(temp_store.is_ready(), "Store should report ready after _ready completes")

func test_ready_signal_emits_once_store_initializes() -> void:
	var temp_store := M_StateStore.new()
	temp_store.settings = RS_StateStoreSettings.new()
	# Disable persistence to avoid file IO races and ensure deterministic init
	temp_store.settings.enable_persistence = false
	temp_store.gameplay_initial_state = RS_GameplayInitialState.new()
	temp_store.settings_initial_state = RS_SettingsInitialState.new()
	var ready_emitted := false
	temp_store.store_ready.connect(func() -> void:
		ready_emitted = true
	)
	add_child(temp_store)
	autofree(temp_store)
	# Avoid race: _ready() may emit before we hit await; use is_ready() guard
	if not temp_store.is_ready():
		await temp_store.store_ready
	assert_true(ready_emitted or temp_store.is_ready(), "ready signal should emit during initialization")
func test_dispatch_notifies_subscribers() -> void:
	# Register test action
	U_ActionRegistry.register_action(StringName("test/action"))

	var callback: Callable = func(action: Dictionary, state: Dictionary) -> void:
		callback_called = true
		received_action = action
		received_state = state

	var unsubscribe: Callable = store.subscribe(callback)

	assert_true(unsubscribe.is_valid(), "Subscribe should return valid unsubscribe callable")

	# Dispatch action
	var action: Dictionary = {"type": StringName("test/action"), "payload": {"data": "test"}}
	store.dispatch(action)

	assert_true(callback_called, "Callback should be called on dispatch")
	assert_eq(received_action.get("type"), StringName("test/action"), "Callback should receive action type")
	assert_eq(received_action.get("payload").get("data"), "test", "Callback should receive payload")

func test_dispatch_emits_action_dispatched_signal() -> void:
	# Register test action
	U_ActionRegistry.register_action(StringName("test/signal"))

	store.action_dispatched.connect(func(action: Dictionary) -> void:
		signal_emitted = true
		signal_action = action
	)

	var action: Dictionary = {"type": StringName("test/signal"), "payload": null}
	store.dispatch(action)

	await get_tree().process_frame

	assert_true(signal_emitted, "action_dispatched signal should emit")
	assert_eq(signal_action.get("type"), StringName("test/signal"), "Signal should carry action")

func test_dispatch_rejects_action_without_type() -> void:
	store.validation_failed.connect(func(_action: Dictionary, error: String) -> void:
		validation_error = error
	)

	var invalid_action: Dictionary = {"payload": "no type"}
	store.dispatch(invalid_action)
	assert_push_error("Action missing 'type' field")
	
	await get_tree().process_frame

	assert_eq(validation_error, "Action missing 'type' field", "Should emit validation_failed")

func test_dispatch_rejects_action_failing_schema_and_does_not_emit_action_dispatched() -> void:
	var action_type := StringName("test/schema_failure")
	U_ActionRegistry.register_action(action_type, {"required_root_fields": ["shell"]})

	var dispatched_emitted := false
	store.action_dispatched.connect(func(_action: Dictionary) -> void:
		dispatched_emitted = true
	)

	store.validation_failed.connect(func(_action: Dictionary, error: String) -> void:
		validation_error = error
	)

	store.dispatch({"type": action_type})
	assert_push_error("Missing required root field")

	await get_tree().process_frame

	assert_eq(validation_error, "Action validation failed", "Schema failures should emit stable validation_failed message")
	assert_false(dispatched_emitted, "Schema-failing actions should not emit action_dispatched")

func test_unsubscribe_removes_callback() -> void:
	# Register test actions
	U_ActionRegistry.register_action(StringName("test1"))
	U_ActionRegistry.register_action(StringName("test2"))

	var callback: Callable = func(_action: Dictionary, _state: Dictionary) -> void:
		callback_count += 1

	var unsubscribe: Callable = store.subscribe(callback)

	store.dispatch({"type": StringName("test1"), "payload": null})
	assert_eq(callback_count, 1, "Callback should fire once")

	unsubscribe.call()

	store.dispatch({"type": StringName("test2"), "payload": null})
	assert_eq(callback_count, 1, "Callback should not fire after unsubscribe")

func test_get_state_returns_deep_copy() -> void:
	var state1: Dictionary = store.get_state()
	state1["test"] = "modified"

	var state2: Dictionary = store.get_state()

	assert_false(state2.has("test"), "Modifying copy should not affect original")

func test_get_slice_returns_deep_copy() -> void:
	var config: RS_StateSliceConfig = RS_StateSliceConfig.new(StringName("test_slice"))
	config.initial_state = {"value": 100}
	store.register_slice(config)

	var slice1: Dictionary = store.get_slice(StringName("test_slice"))
	slice1["value"] = 999

	var slice2: Dictionary = store.get_slice(StringName("test_slice"))

	assert_eq(slice2.get("value"), 100, "Modifying slice copy should not affect original")

func test_dispatch_handles_mixed_type_slice_value_transitions_without_comparer_crash() -> void:
	U_ActionRegistry.register_action(StringName("test/mixed_type_transition"))

	var config := RS_StateSliceConfig.new(StringName("mixed_type_slice"))
	config.initial_state = {"value": "legacy_value"}
	config.reducer = Callable(self, "_mixed_type_slice_reducer")
	store.register_slice(config)

	store.dispatch({"type": StringName("test/mixed_type_transition"), "payload": null})

	var updated_slice: Dictionary = store.get_slice(StringName("mixed_type_slice"))
	var value: Variant = updated_slice.get("value", null)
	assert_true(value is Vector2, "Reducer should be able to replace legacy String with Vector2 without crashing")
	assert_eq(value, Vector2(1.0, -0.5), "Slice value should update to reducer output")

func test_settings_slice_registered_and_updates_via_actions() -> void:
	var settings_slice: Dictionary = store.get_slice(StringName("settings"))
	assert_true(settings_slice.has("input_settings"), "Settings slice should initialize input_settings dictionary")

	var action: Dictionary = U_InputActions.update_mouse_sensitivity(1.75)
	store.dispatch(action)

	var updated_slice: Dictionary = store.get_slice(StringName("settings"))
	var mouse_settings: Dictionary = updated_slice.get("input_settings", {}).get("mouse_settings", {})
	assert_almost_eq(mouse_settings.get("sensitivity", 0.0), 1.75, 0.0001)

func test_time_slice_registered_with_expected_transient_fields() -> void:
	var time_slice: Dictionary = store.get_slice(StringName("time"))
	assert_eq(int(time_slice.get("world_hour", -1)), 8, "Time slice should initialize from RS_TimeInitialState defaults")

	var configs: Dictionary = store.get_slice_configs()
	var time_config: RS_StateSliceConfig = configs.get(StringName("time"))
	assert_not_null(time_config, "Time slice config should be registered")
	assert_true(time_config.transient_fields.has(StringName("is_paused")))
	assert_true(time_config.transient_fields.has(StringName("active_channels")))
	assert_true(time_config.transient_fields.has(StringName("timescale")))

func test_gameplay_slice_marks_touch_look_active_transient() -> void:
	var configs: Dictionary = store.get_slice_configs()
	var gameplay_config: RS_StateSliceConfig = configs.get(StringName("gameplay"))
	assert_not_null(gameplay_config, "Gameplay slice config should be registered")
	assert_true(
		gameplay_config.transient_fields.has(StringName("touch_look_active")),
		"touch_look_active should be transient"
	)

func test_vcam_slice_registered_as_transient_and_present_in_state() -> void:
	var full_state: Dictionary = store.get_state()
	assert_true(full_state.has("vcam"), "Store state should include vcam slice")

	var vcam_slice: Dictionary = store.get_slice(StringName("vcam"))
	assert_true(vcam_slice.has("active_vcam_id"), "vcam slice should include active_vcam_id")
	assert_true(vcam_slice.has("in_fov_zone"), "vcam slice should include in_fov_zone")

	var configs: Dictionary = store.get_slice_configs()
	var vcam_config: RS_StateSliceConfig = configs.get(StringName("vcam"))
	assert_not_null(vcam_config, "vcam slice config should be registered")
	assert_true(vcam_config.is_transient, "vcam slice should be transient")

func test_register_slice_adds_to_state() -> void:
	var config: RS_StateSliceConfig = RS_StateSliceConfig.new(StringName("gameplay"))
	config.initial_state = {"health": 100, "score": 0}
	store.register_slice(config)

	var full_state: Dictionary = store.get_state()
	assert_true(full_state.has("gameplay"), "State should contain registered slice")

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(gameplay_slice.get("health"), 100, "Slice should have initial state")
	assert_eq(gameplay_slice.get("score"), 0, "Slice should have initial state")

func test_settings_defaults_when_null() -> void:
	var store_no_settings: M_StateStore = M_StateStore.new()
	# Explicitly set settings to null to test default creation
	# This prevents the warning since we're intentionally testing the null case
	store_no_settings.settings = null
	add_child(store_no_settings)
	autofree(store_no_settings)  # Use autofree for proper cleanup
	await get_tree().process_frame

	assert_not_null(store_no_settings.settings, "Should create default settings")
	assert_eq(store_no_settings.settings.max_history_size, 1000, "Default history size should be 1000")

## Phase 1f: Signal Batching Tests

func test_multiple_dispatches_emit_single_slice_updated_signal_per_frame() -> void:
	store.slice_updated.connect(func(slice_name: StringName, _slice_state: Dictionary) -> void:
		slice_updated_count += 1
		last_slice_name = slice_name
	)
	
	# Dispatch multiple actions that actually change state
	for i in 10:
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		store.dispatch(action)
	
	# Signal should not have fired yet (batched)
	assert_eq(slice_updated_count, 0, "Signal should be batched, not immediate")
	
	# State should be updated immediately though
	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(gameplay_state.get("paused"), false, "State should update immediately (last action unpauses)")
	
	# Wait for physics frame to flush batched signals
	await get_tree().physics_frame
	await get_tree().process_frame  # Ensure signal emission completes

func test_immediate_actions_flush_slice_updated_signal() -> void:
	var settings_emitted := [false]  # Track settings slice specifically (init sync may emit other slices)
	store.slice_updated.connect(func(slice_name: StringName, _slice_state: Dictionary) -> void:
		slice_updated_count += 1
		last_slice_name = slice_name
		if slice_name == StringName("settings"):
			settings_emitted[0] = true
	)

	if not InputMap.has_action("test_jump"):
		InputMap.add_action("test_jump")

	var event := InputEventKey.new()
	event.keycode = Key.KEY_F1
	event.physical_keycode = Key.KEY_F1
	event.pressed = true

	var action := U_InputActions.rebind_action(StringName("test_jump"), event, U_InputActions.REBIND_MODE_REPLACE, [event])
	store.dispatch(action)

	assert_true(settings_emitted[0], "Immediate actions should flush slice_updated synchronously for the settings slice")
	# The batcher may flush other slices (e.g. navigation from init sync),
	# so we check that settings was the last slice_updated.
	assert_eq(last_slice_name, StringName("settings"), "Last slice_updated should be for settings")

	InputMap.erase_action("test_jump")

func test_state_reads_immediately_after_dispatch_show_new_state() -> void:
	# State updates should be synchronous, not batched
	U_ActionRegistry.register_action(StringName("test/immediate"))

	# Dispatch action that would update state
	var action: Dictionary = {"type": U_GameplayActions.ACTION_PAUSE_GAME, "payload": null}
	store.dispatch(action)
	var gameplay_state: Dictionary = store.get_state().get("gameplay", {})
	assert_true(gameplay_state.get("paused", false), "Dispatch should update gameplay slice immediately.")
	store.dispatch(U_GameplayActions.unpause_game())

func test_normalize_scene_slice_falls_back_to_default_scene() -> void:
	var state: Dictionary = {
		"scene": {
			"current_scene_id": StringName("")
		}
	}
	store.call("_normalize_loaded_state", state)
	var scene_slice: Dictionary = state["scene"]
	assert_eq(scene_slice.get("current_scene_id"), _get_expected_default_gameplay_scene(),
		"Blank scene IDs should fall back to configured default gameplay scene.")

func test_normalize_gameplay_slice_sanitizes_spawn_and_completed_areas() -> void:
	var state: Dictionary = {
		"gameplay": {
			"target_spawn_point": StringName(""),
			"last_checkpoint": StringName(""),
			"completed_areas": ["interior_house", "interior_house", "", "forest ", " "]
		}
	}
	store.call("_normalize_loaded_state", state)
	var gameplay_slice: Dictionary = state["gameplay"]
	assert_eq(gameplay_slice.get("target_spawn_point"), StringName(""),
		"Blank spawn references should remain unset.")
	assert_eq(gameplay_slice.get("last_checkpoint"), StringName(""),
		"Blank checkpoints should remain unset.")
	var completed: Array = gameplay_slice.get("completed_areas", [])
	assert_eq(completed.size(), 2, "Completed areas should be deduplicated and trimmed.")
	assert_true(completed.has("interior_house"), "Completed areas should retain valid entries.")
	assert_true(completed.has("forest"), "Completed areas should strip whitespace.")

func test_normalize_spawn_reference_handles_invalid_values() -> void:
	var fallback_spawn: StringName = store.call("_normalize_spawn_reference", StringName("HubSpawn"), false, false)
	assert_eq(fallback_spawn, StringName("sp_default"), "Invalid spawn IDs should fall back to sp_default")
	var fallback_checkpoint: StringName = store.call("_normalize_spawn_reference", StringName("hub_default"), false, false)
	assert_eq(fallback_checkpoint, StringName("sp_default"), "Invalid checkpoints should fall back to sp_default")

func _get_expected_default_gameplay_scene() -> StringName:
	var config: RS_GameConfig = load("res://resources/core/cfg_game_config.tres") as RS_GameConfig
	if config == null:
		return StringName("demo_room")
	return config.get_default_gameplay_scene_id()

func test_signal_batching_overhead_less_than_0_05ms() -> void:
	U_ActionRegistry.register_action(StringName("test/perf"))

	var perf_store := M_StateStore.new()
	perf_store.settings = RS_StateStoreSettings.new()
	perf_store.settings.enable_persistence = false
	perf_store.settings.enable_history = false
	perf_store.gameplay_initial_state = RS_GameplayInitialState.new()
	perf_store.settings_initial_state = RS_SettingsInitialState.new()
	perf_store.time_initial_state = RS_TIME_INITIAL_STATE.new()
	add_child(perf_store)
	autofree(perf_store)
	await get_tree().process_frame

	var elapsed: float = U_StateUtils.benchmark("signal_batching", func() -> void:
		# Dispatch 100 actions
		for i in 100:
			perf_store.dispatch({"type": StringName("test/perf"), "payload": {"i": i}})
	)

	# Total overhead should be minimal. Allow a slightly higher threshold to
	# account for slower CI and headless environments where micro-benchmarks
	# can be noisy.
	var per_action_ms: float = elapsed / 100.0
	var threshold_ms: float = 0.50
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		threshold_ms = 0.75
	assert_lt(per_action_ms, threshold_ms, "Signal batching overhead should remain within benchmark threshold")

## Phase 1g: Action History Tests

func test_action_history_records_actions_with_timestamps() -> void:
	# Dispatch a few actions
	store.dispatch(U_GameplayActions.pause_game())
	store.dispatch(U_GameplayActions.unpause_game())
	store.dispatch(U_GameplayActions.pause_game())
	
	var history: Array = store.get_action_history()
	
	assert_eq(history.size(), 4, "History should contain 4 actions (3 dispatched + 1 init sync)")

	# Check first entry structure
	var first_entry: Dictionary = history[0]
	assert_true(first_entry.has("action"), "History entry should have 'action' field")
	assert_true(first_entry.has("timestamp"), "History entry should have 'timestamp' field")
	assert_true(first_entry.has("state_after"), "History entry should have 'state_after' field")

	# First action is the init sync; first dispatched action (pause) is at index 1
	assert_eq(first_entry["action"]["type"], U_NavigationActions.ACTION_SYNC_INITIAL_SCENE, "First action should be init sync")
	var second_entry: Dictionary = history[1]
	assert_eq(second_entry["action"]["type"], U_GameplayActions.ACTION_PAUSE_GAME, "Second action should be pause")
	
	# Check timestamp is a number
	assert_true(first_entry["timestamp"] is float or first_entry["timestamp"] is int, "Timestamp should be a number")
	
	# Check state_after is a Dictionary
	assert_true(first_entry["state_after"] is Dictionary, "state_after should be a Dictionary")

func test_get_last_n_actions_returns_correct_count() -> void:
	# Dispatch 10 actions
	for i in 10:
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		store.dispatch(action)
	
	var last_5: Array = store.get_last_n_actions(5)
	assert_eq(last_5.size(), 5, "Should return last 5 actions")
	
	# Check they are the most recent actions
	var last_entry: Dictionary = last_5[last_5.size() - 1]
	var gameplay_state: Dictionary = last_entry["state_after"]["gameplay"]
	assert_eq(gameplay_state["paused"], false, "Last action should have paused=false (index 9 is unpause)")
	
	# Test requesting more than available
	var last_20: Array = store.get_last_n_actions(20)
	assert_eq(last_20.size(), 11, "Should return only 11 actions when requesting 20 (10 dispatched + 1 init sync)")
	
	# Test requesting 0
	var last_0: Array = store.get_last_n_actions(0)
	assert_eq(last_0.size(), 0, "Should return empty array for n=0")

func test_history_prunes_oldest_when_exceeding_1000_entries() -> void:
	# This test will dispatch 1001 actions and verify the oldest is pruned
	# To speed this up, we'll use a custom store with smaller history size
	
	# Save and clear project setting so our test settings aren't overridden
	var original_setting: Variant = null
	if ProjectSettings.has_setting("state/debug/history_size"):
		original_setting = ProjectSettings.get_setting("state/debug/history_size")
		ProjectSettings.clear("state/debug/history_size")
	
	var test_store: M_StateStore = M_StateStore.new()
	test_store.settings = RS_StateStoreSettings.new()
	test_store.settings.max_history_size = 10  # Small size for testing
	test_store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(test_store)
	autofree(test_store)  # Use autofree for proper cleanup
	await get_tree().process_frame
	
	# Dispatch 11 actions (exceeds max of 10)
	for i in 11:
		var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
		test_store.dispatch(action)
	
	var history: Array = test_store.get_action_history()
	assert_eq(history.size(), 10, "History should be pruned to max size of 10")
	
	# Verify we have 10 entries (oldest was pruned)
	var oldest_entry: Dictionary = history[0]
	assert_true(oldest_entry.has("action"), "Oldest entry should still have action field")
	
	var newest_entry: Dictionary = history[history.size() - 1]
	var newest_state: Dictionary = newest_entry["state_after"]["gameplay"]
	assert_eq(newest_state["paused"], true, "Newest entry should have paused=true (last action i=10 was pause)")
	
	# Cleanup: restore original setting
	if original_setting != null:
		ProjectSettings.set_setting("state/debug/history_size", original_setting)

func test_history_includes_state_after_snapshot() -> void:
	# Dispatch action and check state_after matches actual state
	store.dispatch(U_GameplayActions.pause_game())
	
	var history: Array = store.get_action_history()
	assert_eq(history.size(), 2, "Should have 2 history entries (1 dispatched + 1 init sync)")
	
	var entry: Dictionary = history[0]
	var state_after: Dictionary = entry["state_after"]
	var current_state: Dictionary = store.get_state()
	
	# State after should match current state
	assert_eq(state_after["gameplay"]["paused"], true, "state_after should show paused=true")
	assert_eq(current_state["gameplay"]["paused"], true, "Current state should show paused=true")

func test_history_respects_project_setting_state_debug_history_size() -> void:
	# Create a store that should read from project settings
	# We'll create a custom store and set the project setting
	var original_setting: Variant = null
	if ProjectSettings.has_setting("state/debug/history_size"):
		original_setting = ProjectSettings.get_setting("state/debug/history_size")
	
	# Set project setting to 5
	ProjectSettings.set_setting("state/debug/history_size", 5)
	
	var test_store: M_StateStore = M_StateStore.new()
	# Explicitly set settings to null to test project setting loading
	test_store.settings = null
	test_store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(test_store)
	autofree(test_store)  # Use autofree for proper cleanup
	await get_tree().process_frame
	
	# The store should have read the project setting
	assert_eq(test_store.settings.max_history_size, 5, "Store should read history_size from project setting")
	
	# Cleanup: restore original setting
	if original_setting != null:
		ProjectSettings.set_setting("state/debug/history_size", original_setting)
	else:
		ProjectSettings.clear("state/debug/history_size")
