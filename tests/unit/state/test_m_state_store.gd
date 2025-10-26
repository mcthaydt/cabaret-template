extends GutTest

## Tests for M_StateStore core functionality

const StateStoreEventBus := preload("res://scripts/state/state_event_bus.gd")

var store: M_StateStore

func before_each() -> void:
	# CRITICAL: Reset state bus between tests to prevent subscription leaks
	StateStoreEventBus.reset()

	store = M_StateStore.new()
	add_child(store)
	await get_tree().process_frame  # Deferred registration

func after_each() -> void:
	if store and is_instance_valid(store):
		store.queue_free()
	store = null
	StateStoreEventBus.reset()

func test_store_instantiates_as_node() -> void:
	assert_not_null(store, "Store should be created")
	assert_true(store is Node, "Store should extend Node")

func test_store_adds_to_state_store_group() -> void:
	assert_true(store.is_in_group("state_store"), "Store should be in 'state_store' group")

func test_dispatch_notifies_subscribers() -> void:
	# Register test action
	ActionRegistry.register_action(StringName("test/action"))
	
	var callback_called := false
	var received_action: Dictionary = {}
	var received_state: Dictionary = {}

	var callback := func(action: Dictionary, state: Dictionary) -> void:
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
	ActionRegistry.register_action(StringName("test/signal"))
	
	var signal_emitted := false
	var signal_action: Dictionary = {}

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
	gut.p("Expect error: Action missing 'type' field")
	var validation_error := ""

	store.validation_failed.connect(func(_action: Dictionary, error: String) -> void:
		validation_error = error
	)

	var invalid_action: Dictionary = {"payload": "no type"}
	store.dispatch(invalid_action)

	assert_eq(validation_error, "Action missing 'type' field", "Should emit validation_failed")

func test_unsubscribe_removes_callback() -> void:
	# Register test actions
	ActionRegistry.register_action(StringName("test1"))
	ActionRegistry.register_action(StringName("test2"))
	
	var callback_count := 0

	var callback := func(_action: Dictionary, _state: Dictionary) -> void:
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
	var config := StateSliceConfig.new(StringName("test_slice"))
	config.initial_state = {"value": 100}
	store.register_slice(config)

	var slice1: Dictionary = store.get_slice(StringName("test_slice"))
	slice1["value"] = 999

	var slice2: Dictionary = store.get_slice(StringName("test_slice"))

	assert_eq(slice2.get("value"), 100, "Modifying slice copy should not affect original")

func test_register_slice_adds_to_state() -> void:
	var config := StateSliceConfig.new(StringName("gameplay"))
	config.initial_state = {"health": 100, "score": 0}
	store.register_slice(config)

	var full_state: Dictionary = store.get_state()
	assert_true(full_state.has("gameplay"), "State should contain registered slice")

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(gameplay_slice.get("health"), 100, "Slice should have initial state")
	assert_eq(gameplay_slice.get("score"), 0, "Slice should have initial state")

func test_settings_defaults_when_null() -> void:
	gut.p("Expect warning: No settings assigned, using defaults")
	var store_no_settings := M_StateStore.new()
	add_child(store_no_settings)
	await get_tree().process_frame

	assert_not_null(store_no_settings.settings, "Should create default settings")
	assert_eq(store_no_settings.settings.max_history_size, 1000, "Default history size should be 1000")
	
	store_no_settings.queue_free()
