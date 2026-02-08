extends GutTest

const VirtualJoystickScene := preload("res://scenes/ui/widgets/ui_virtual_joystick.tscn")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_touch_press_and_release_changes_active_state() -> void:
	var joystick := await _create_joystick()
	var release_tracker := {"count": 0}
	joystick.joystick_released.connect(func():
		release_tracker["count"] += 1
	)

	var press := _make_touch_event(0, Vector2(120, 120), true)
	joystick._input(press)
	assert_true(joystick.is_active(), "Joystick should become active after touch press")

	var release := _make_touch_event(0, press.position, false)
	joystick._input(release)
	assert_false(joystick.is_active(), "Joystick should deactivate after release")
	assert_eq(release_tracker["count"], 1, "Release signal should emit once")

func test_drag_updates_vector_and_emits_signal() -> void:
	var joystick := await _create_joystick(func(instance):
		instance.deadzone = 0.0
		instance.joystick_radius = 100.0
	)

	var moved_vectors: Array[Vector2] = []
	joystick.joystick_moved.connect(func(vector: Vector2): moved_vectors.append(vector))

	# Touch inside joystick bounds (joystick is at 0,0 with size 200x200)
	var press := _make_touch_event(1, Vector2(100, 100), true)
	joystick._input(press)

	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = press.position + Vector2(200, 0)  # Exceeds radius to test clamping
	joystick._input(drag)

	var vector := joystick.get_vector()
	assert_almost_eq(vector.x, 1.0, 0.001, "Vector should clamp to radius and normalize to 1 on X axis")
	assert_almost_eq(vector.y, 0.0, 0.001)
	assert_true(moved_vectors.size() >= 1, "Drag should emit joystick_moved at least once")
	assert_vector_almost_eq(moved_vectors.back(), vector, 0.001, "Signal payload should match stored vector")

func test_deadzone_filters_small_movements() -> void:
	var joystick := await _create_joystick(func(instance):
		instance.deadzone = 0.25
		instance.joystick_radius = 120.0
	)
	var press := _make_touch_event(2, Vector2(100, 100), true)
	joystick._input(press)

	var small_drag := InputEventScreenDrag.new()
	small_drag.index = 2
	small_drag.position = press.position + Vector2(10, 0)
	joystick._input(small_drag)
	assert_vector_almost_eq(joystick.get_vector(), Vector2.ZERO, 0.001, "Vector below deadzone should zero out")

	var large_drag := InputEventScreenDrag.new()
	large_drag.index = 2
	large_drag.position = press.position + Vector2(60, 0)
	joystick._input(large_drag)

	var result := joystick.get_vector()
	assert_true(result.x > 0.0, "Vector should be positive after exceeding deadzone")
	assert_true(result.x < 1.0, "Vector should be rescaled to 0-1 range after deadzone")
	assert_almost_eq(result.y, 0.0, 0.001)

func test_touch_outside_bounds_is_ignored() -> void:
	var joystick := await _create_joystick(func(instance):
		instance.joystick_radius = 120.0  # Size 240x240 at position (0,0)
	)

	# Touch outside the joystick bounds (joystick is at 0,0 with size 240x240)
	var press := _make_touch_event(0, Vector2(500, 500), true)
	joystick._input(press)
	assert_false(joystick.is_active(), "Touch outside bounds should not activate joystick")

	# Touch inside should work
	var inside_press := _make_touch_event(1, Vector2(120, 120), true)
	joystick._input(inside_press)
	assert_true(joystick.is_active(), "Touch inside bounds should activate joystick")

func test_multi_touch_ignored_until_primary_released() -> void:
	var joystick := await _create_joystick()
	var press := _make_touch_event(3, Vector2(150, 150), true)
	joystick._input(press)
	assert_true(joystick.is_active(), "Primary touch should activate joystick")

	var other_drag := InputEventScreenDrag.new()
	other_drag.index = 4
	other_drag.position = press.position + Vector2(0, 50)
	joystick._input(other_drag)
	assert_vector_almost_eq(joystick.get_vector(), Vector2.ZERO, 0.001, "Other touches should be ignored")

	var other_release := _make_touch_event(4, other_drag.position, false)
	joystick._input(other_release)
	assert_true(joystick.is_active(), "Releasing secondary touch should not deactivate joystick")

	var release := _make_touch_event(3, press.position, false)
	joystick._input(release)
	assert_false(joystick.is_active(), "Primary release should deactivate joystick")

func test_drag_to_reposition_updates_position_and_dispatches() -> void:
	var store := await _create_state_store()
	var joystick := await _create_joystick(func(instance):
		instance.can_reposition = true
		instance.control_name = StringName("test_joystick")
		instance.position = Vector2(50, 80)
	)

	# Touch inside joystick bounds (joystick is at 50,80 with size 240x240)
	var press := _make_touch_event(5, Vector2(150, 200), true)
	joystick._input(press)

	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = Vector2(210, 260)
	joystick._input(drag)

	assert_false(joystick.position.is_equal_approx(Vector2(50, 80)), "Position should change while repositioning")
	assert_vector_almost_eq(joystick.get_vector(), Vector2.ZERO, 0.001, "Repositioning should not update joystick vector")

	var release := _make_touch_event(5, drag.position, false)
	joystick._input(release)

	assert_false(joystick.is_active(), "Joystick should release after reposition drag")
	assert_eq(store.dispatched_actions.size(), 1, "Reposition release should dispatch save action")
	var action: Dictionary = store.dispatched_actions[0]
	assert_eq(StringName(action.get("type", "")), StringName("input/save_virtual_control_position"))
	var payload: Dictionary = action.get("payload", {})
	assert_eq(payload.get("control_name", ""), String(joystick.control_name))
	assert_vector_almost_eq(payload.get("position", Vector2.ZERO), joystick.position, 0.001,
		"Saved position should match joystick position after drag")

func _make_touch_event(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event

func _create_joystick(configure: Callable = Callable()) -> UI_VirtualJoystick:
	var joystick := VirtualJoystickScene.instantiate()
	if configure != Callable() and configure.is_valid():
		configure.call(joystick)
	add_child_autofree(joystick)
	await _await_frames(1)
	return joystick

func _create_state_store() -> TestStateStore:
	var store := TestStateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await _await_frames(2)
	return store

func assert_vector_almost_eq(a: Vector2, b: Vector2, tolerance: float, message: String = "") -> void:
	assert_almost_eq(a.x, b.x, tolerance, message + " (x)")
	assert_almost_eq(a.y, b.y, tolerance, message + " (y)")

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

class TestStateStore extends M_StateStore:
	var dispatched_actions: Array = []

	func dispatch(action: Dictionary) -> void:
		dispatched_actions.append(action.duplicate(true))
		super.dispatch(action)
