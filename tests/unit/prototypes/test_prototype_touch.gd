extends GutTest

const PrototypeTouch := preload("res://tests/prototypes/prototype_touch.gd")

func test_joystick_handles_press_drag_and_deadzone() -> void:
	var prototype := PrototypeTouch.new()
	prototype.configure_virtual_joystick(Vector2(100, 100), 80.0, 0.2)

	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(110, 100)
	prototype.process_touch_event(press)
	assert_true(prototype.get_joystick_vector().is_zero_approx(), "Within deadzone, vector should zero")

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(180, 40)  # large offset
	prototype.process_touch_event(drag)
	var vector := prototype.get_joystick_vector()
	assert_almost_eq(vector.length(), 1.0, 0.01, "Drag past radius should clamp to unit circle")
	assert_almost_eq(vector.x, 0.8, 0.01)
	assert_almost_eq(vector.y, -0.6, 0.01)

	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	prototype.process_touch_event(release)
	assert_true(prototype.get_joystick_vector().is_zero_approx(), "Release resets joystick")

func test_button_regions_track_press_and_release() -> void:
	var prototype := PrototypeTouch.new()
	prototype.register_button_region(StringName("jump"), Rect2(Vector2(400, 400), Vector2(100, 100)))

	var press := InputEventScreenTouch.new()
	press.index = 2
	press.pressed = true
	press.position = Vector2(420, 420)
	prototype.process_touch_event(press)
	assert_true(prototype.get_button_state(StringName("jump")))

	var release := InputEventScreenTouch.new()
	release.index = 2
	release.pressed = false
	prototype.process_touch_event(release)
	assert_false(prototype.get_button_state(StringName("jump")))

func test_multi_touch_supports_joystick_and_button_simultaneously() -> void:
	var prototype := PrototypeTouch.new()
	prototype.configure_virtual_joystick(Vector2(80, 420), 90.0, 0.1)
	prototype.register_button_region(StringName("dash"), Rect2(Vector2(500, 360), Vector2(120, 120)))

	var joystick_press := InputEventScreenTouch.new()
	joystick_press.index = 0
	joystick_press.pressed = true
	joystick_press.position = Vector2(50, 450)
	prototype.process_touch_event(joystick_press)

	var button_press := InputEventScreenTouch.new()
	button_press.index = 1
	button_press.pressed = true
	button_press.position = Vector2(550, 400)
	prototype.process_touch_event(button_press)

	assert_false(prototype.get_joystick_vector().is_zero_approx())
	assert_true(prototype.get_button_state(StringName("dash")), "Button should stay active while joystick touch exists")

	var state := prototype.snapshot_state()
	assert_eq(state.joystick_id, 0)
	assert_true(state.buttons[StringName("dash")])

	var button_release := InputEventScreenTouch.new()
	button_release.index = 1
	button_release.pressed = false
	prototype.process_touch_event(button_release)
	assert_false(prototype.get_button_state(StringName("dash")))

func test_button_drag_leaves_region_releasing_state() -> void:
	var prototype := PrototypeTouch.new()
	var button_name := StringName("fire")
	prototype.register_button_region(button_name, Rect2(Vector2(600, 200), Vector2(80, 80)))

	var press := InputEventScreenTouch.new()
	press.index = 3
	press.pressed = true
	press.position = Vector2(610, 210)
	prototype.process_touch_event(press)
	assert_true(prototype.get_button_state(button_name))

	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(720, 320)  # outside region
	prototype.process_touch_event(drag)
	assert_false(prototype.get_button_state(button_name))

func test_frame_timing_evaluation_confirms_sixty_fps_budget() -> void:
	var prototype := PrototypeTouch.new()
	var good := prototype.evaluate_frame_timings([15.2, 16.5, 14.8])
	assert_true(good.meets_target)
	assert_almost_eq(good.max_ms, 16.5, 0.01)

	var bad := prototype.evaluate_frame_timings([14.0, 17.2, 18.5])
	assert_false(bad.meets_target)
	assert_almost_eq(bad.max_ms, 18.5, 0.01)
