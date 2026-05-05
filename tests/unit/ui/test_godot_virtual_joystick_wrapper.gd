extends GutTest

## Tests for UI_VirtualJoystick wrapper around Godot 4.7's VirtualJoystick.
## Verifies API compatibility with original implementation.

const VirtualJoystickScene := preload("res://scenes/core/ui/widgets/ui_virtual_joystick.tscn")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_wrapper_has_required_methods() -> void:
	var joystick := await _create_joystick()
	
	assert_true(joystick.has_method("get_vector"), "Wrapper must have get_vector() method")
	assert_true(joystick.has_method("is_active"), "Wrapper must have is_active() method")

func test_wrapper_get_vector_returns_vector2() -> void:
	var joystick := await _create_joystick()
	
	var vector := joystick.get_vector()
	
	assert_eq(typeof(vector), TYPE_VECTOR2, "get_vector() should return Vector2")
	assert_eq(vector, Vector2.ZERO, "Initial vector should be zero")

func test_wrapper_is_active_returns_bool() -> void:
	var joystick := await _create_joystick()
	
	var active := joystick.is_active()
	
	assert_eq(typeof(active), TYPE_BOOL, "is_active() should return bool")
	assert_false(active, "Initial state should be inactive")

func test_wrapper_has_required_signals() -> void:
	var joystick := await _create_joystick()
	
	assert_true(joystick.has_signal("joystick_moved"), "Wrapper must have joystick_moved signal")
	assert_true(joystick.has_signal("joystick_released"), "Wrapper must have joystick_released signal")

func test_joystick_radius_property_exists() -> void:
	var joystick := await _create_joystick()
	
	assert_true("joystick_radius" in joystick, "joystick_radius property must exist")
	assert_eq(typeof(joystick.joystick_radius), TYPE_FLOAT, "joystick_radius should be float")

func test_deadzone_property_exists() -> void:
	var joystick := await _create_joystick()
	
	assert_true("deadzone" in joystick, "deadzone property must exist")
	assert_eq(typeof(joystick.deadzone), TYPE_FLOAT, "deadzone should be float")

func test_can_reposition_property_exists() -> void:
	var joystick := await _create_joystick()
	
	assert_true("can_reposition" in joystick, "can_reposition property must exist")
	assert_eq(typeof(joystick.can_reposition), TYPE_BOOL, "can_reposition should be bool")

func test_control_name_property_exists() -> void:
	var joystick := await _create_joystick()
	
	assert_true("control_name" in joystick, "control_name property must exist")
	assert_eq(typeof(joystick.control_name), TYPE_STRING_NAME, "control_name should be StringName")

func test_godot_virtual_joystick_node_exists_as_child() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick()
	
	var godot_joystick := joystick.get_node_or_null("GodotVirtualJoystick")
	
	assert_not_null(godot_joystick, "Godot VirtualJoystick node should exist as child")
	assert_true(godot_joystick is Control, "Child should be a Control")

func test_joystick_radius_maps_to_godot_joystick_size() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick(func(instance):
		instance.joystick_radius = 100.0
	)
	
	var godot_joystick := joystick.get_node("GodotVirtualJoystick") as Control
	
	assert_almost_eq(godot_joystick.get("joystick_size"), 200.0, 0.01, "joystick_size should be 2x radius")

func test_deadzone_maps_to_godot_deadzone_ratio() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick(func(instance):
		instance.deadzone = 0.25
	)
	
	var godot_joystick := joystick.get_node("GodotVirtualJoystick") as Control
	
	assert_almost_eq(godot_joystick.get("deadzone_ratio"), 0.25, 0.01, "deadzone_ratio should match")

func test_can_reposition_false_sets_fixed_mode() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick(func(instance):
		instance.can_reposition = false
	)
	
	var godot_joystick := joystick.get_node("GodotVirtualJoystick") as Control
	
	assert_eq(godot_joystick.get("joystick_mode"), 0, "Mode should be FIXED")

func test_can_reposition_true_sets_dynamic_mode() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick(func(instance):
		instance.can_reposition = true
	)
	
	var godot_joystick := joystick.get_node("GodotVirtualJoystick") as Control
	
	assert_eq(godot_joystick.get("joystick_mode"), 1, "Mode should be DYNAMIC")

func _make_touch_event(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event

func _create_joystick(configure: Callable = Callable()) -> UI_VirtualJoystick:
	var joystick := VirtualJoystickScene.instantiate() if ClassDB.class_exists("VirtualJoystick") else UI_VirtualJoystick.new()
	if configure != Callable() and configure.is_valid():
		configure.call(joystick)
	add_child_autofree(joystick)
	await _await_frames(1)
	return joystick

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
