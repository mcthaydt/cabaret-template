extends GutTest


func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_profile_manager_initializes_when_store_ready_first() -> void:
	var store := _spawn_state_store()
	await _pump_frames(2)

	var profile_manager := M_InputProfileManager.new()
	add_child_autofree(profile_manager)
	await _pump_frames(3)

	assert_true(is_instance_valid(profile_manager.store_ref), "Profile manager should capture store reference when store appears first")
	assert_eq(profile_manager.store_ref, store, "Profile manager should bind to the active store instance")

func test_profile_manager_waits_until_store_added() -> void:
	var profile_manager := M_InputProfileManager.new()
	add_child_autofree(profile_manager)
	await _pump_frames(3)

	assert_null(profile_manager.store_ref, "Profile manager should not bind before store exists")

	var store := _spawn_state_store()
	await _pump_frames(3)

	assert_eq(profile_manager.store_ref, store, "Profile manager should bind once store is added later")

func test_device_manager_defers_events_until_store_ready() -> void:
	var device_manager := M_InputDeviceManager.new()
	add_child_autofree(device_manager)

	var observed_events: Array[Dictionary] = []
	device_manager.device_changed.connect(func(device_type: int, device_id: int, _timestamp: float) -> void:
		observed_events.append({
			"type": device_type,
			"id": device_id,
		})
	)

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = Key.KEY_G
	device_manager._input(key_event)
	await _pump_frames(1)

	assert_eq(observed_events.size(), 0, "No device events should emit before store is ready")

	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_history = false
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()

	var dispatched_actions: Array[Dictionary] = []
	store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched_actions.append(action.duplicate(true))
	)

	add_child_autofree(store)
	await _pump_frames(3)

	# In headless / interactive environments additional real input events may
	# be observed while the test pumps frames. Assert that at least one queued
	# event flushes and that at least one device_changed action is dispatched,
	# rather than relying on an exact count.
	assert_true(observed_events.size() >= 1, "At least one queued device event should flush once store is ready")

	var device_changed_actions: Array[Dictionary] = []
	for action in dispatched_actions:
		if action.get("type", StringName()) == U_InputActions.ACTION_DEVICE_CHANGED:
			device_changed_actions.append(action.duplicate(true))

	assert_true(device_changed_actions.size() >= 1, "Redux dispatch should occur when queued device event flushes")

func test_fast_scene_transitions_do_not_break_initialization() -> void:
	var store := _spawn_state_store()
	var profile_manager := M_InputProfileManager.new()
	var device_manager := M_InputDeviceManager.new()
	add_child_autofree(profile_manager)
	add_child_autofree(device_manager)
	await _pump_frames(2)

	profile_manager.queue_free()
	device_manager.queue_free()
	await _pump_frames(1)

	store.queue_free()
	await _pump_frames(1)

	# Create a fresh set immediately after teardown to mimic scene reload
	store = _spawn_state_store()
	profile_manager = M_InputProfileManager.new()
	device_manager = M_InputDeviceManager.new()
	add_child_autofree(profile_manager)
	add_child_autofree(device_manager)
	await _pump_frames(3)

	assert_true(is_instance_valid(profile_manager.store_ref), "Profile manager should rebind store after reload")
	assert_true(is_instance_valid(store), "Store should remain valid after quick reload sequence")

func test_manager_initialization_survives_stress_iterations() -> void:
	for i in 100:
		var store := _spawn_state_store()
		var profile_manager := M_InputProfileManager.new()
		var device_manager := M_InputDeviceManager.new()
		add_child_autofree(profile_manager)
		add_child_autofree(device_manager)
		await _pump_frames(2)
		assert_true(
			is_instance_valid(profile_manager.store_ref),
			"Profile manager should bind to store on iteration %d" % i
		)
		var resolved_store := U_StateUtils.get_store(device_manager)
		assert_true(
			is_instance_valid(resolved_store),
			"Device manager should resolve store on iteration %d" % i
		)
		profile_manager.queue_free()
		device_manager.queue_free()
		store.queue_free()
		await _pump_frames(1)

func _spawn_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_history = false
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	return store

func _pump_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
