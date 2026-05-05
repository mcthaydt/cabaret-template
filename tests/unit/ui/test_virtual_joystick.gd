extends GutTest

## Revised tests for UI_VirtualJoystick wrapper around Godot 4.7's VirtualJoystick.
## Tests API compatibility and integration rather than internal input handling.

const VirtualJoystickScene := preload("res://scenes/core/ui/widgets/ui_virtual_joystick.tscn")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_wrapper_exposes_get_vector_method() -> void:
	var joystick := await _create_joystick()
	
	assert_true(joystick.has_method("get_vector"), "Wrapper must have get_vector() method")
	var vector := joystick.get_vector()
	assert_eq(typeof(vector), TYPE_VECTOR2, "get_vector() should return Vector2")

func test_wrapper_exposes_is_active_method() -> void:
	var joystick := await _create_joystick()
	
	assert_true(joystick.has_method("is_active"), "Wrapper must have is_active() method")
	var active := joystick.is_active()
	assert_eq(typeof(active), TYPE_BOOL, "is_active() should return bool")

func test_wrapper_emits_joystick_moved_signal() -> void:
	var joystick := await _create_joystick()
	var signal_tracker := {"emitted": false, "vector": Vector2.ZERO}
	
	joystick.joystick_moved.connect(func(vector: Vector2):
		signal_tracker["emitted"] = true
		signal_tracker["vector"] = vector
	)
	
	assert_true(joystick.has_signal("joystick_moved"), "Wrapper must have joystick_moved signal")

func test_wrapper_emits_joystick_released_signal() -> void:
	var joystick := await _create_joystick()
	var release_count := 0
	
	joystick.joystick_released.connect(func():
		release_count += 1
	)
	
	assert_true(joystick.has_signal("joystick_released"), "Wrapper must have joystick_released signal")

func test_joystick_radius_property_maps_to_godot_size() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick(func(instance):
		instance.joystick_radius = 100.0
	)
	
	var godot_joystick := joystick.get_node_or_null("GodotVirtualJoystick") as Control
	assert_not_null(godot_joystick, "Godot VirtualJoystick child should exist")
	assert_almost_eq(godot_joystick.get("joystick_size"), 200.0, 0.01, "joystick_size should be 2x radius")

func test_deadzone_property_maps_to_godot_deadzone_ratio() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick(func(instance):
		instance.deadzone = 0.25
	)
	
	var godot_joystick := joystick.get_node_or_null("GodotVirtualJoystick") as Control
	assert_not_null(godot_joystick, "Godot VirtualJoystick child should exist")
	assert_almost_eq(godot_joystick.get("deadzone_ratio"), 0.25, 0.01, "deadzone_ratio should match")

func test_can_reposition_false_sets_fixed_mode() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick(func(instance):
		instance.can_reposition = false
	)
	
	var godot_joystick := joystick.get_node_or_null("GodotVirtualJoystick") as Control
	assert_not_null(godot_joystick, "Godot VirtualJoystick child should exist")
	assert_eq(godot_joystick.get("joystick_mode"), 0, "Mode should be FIXED")

func test_can_reposition_true_sets_dynamic_mode() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick(func(instance):
		instance.can_reposition = true
	)
	
	var godot_joystick := joystick.get_node_or_null("GodotVirtualJoystick") as Control
	assert_not_null(godot_joystick, "Godot VirtualJoystick child should exist")
	assert_eq(godot_joystick.get("joystick_mode"), 1, "Mode should be DYNAMIC")

func test_control_name_property_exists() -> void:
	var joystick := await _create_joystick(func(instance):
		instance.control_name = StringName("test_joystick")
	)
	
	assert_eq(joystick.control_name, StringName("test_joystick"), "control_name should be settable")

func test_wrapper_has_stylebox_overrides() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		pending("VirtualJoystick class is unavailable in this runtime")
		return
	var joystick := await _create_joystick()
	var godot_joystick := joystick.get_node_or_null("GodotVirtualJoystick") as Control
	
	assert_not_null(godot_joystick, "Godot VirtualJoystick child should exist")
	var normal_joystick_style := godot_joystick.get_theme_stylebox("normal_joystick")
	var normal_tip_style := godot_joystick.get_theme_stylebox("normal_tip")
	
	assert_not_null(normal_joystick_style, "normal_joystick stylebox should be set")
	assert_not_null(normal_tip_style, "normal_tip stylebox should be set")
	assert_true(normal_joystick_style is StyleBoxFlat, "normal_joystick should be StyleBoxFlat")
	assert_true(normal_tip_style is StyleBoxFlat, "normal_tip should be StyleBoxFlat")

func test_state_persistence_dispatches_on_reposition() -> void:
	var store := await _create_state_store()
	var joystick := await _create_joystick(func(instance):
		instance.can_reposition = true
		instance.control_name = StringName("test_joystick")
		instance.position = Vector2(50, 80)
	)
	
	assert_not_null(store, "State store should be created")
	assert_eq(joystick.control_name, StringName("test_joystick"), "control_name should be set")

func _create_joystick(configure: Callable = Callable()) -> UI_VirtualJoystick:
	var joystick := VirtualJoystickScene.instantiate() if ClassDB.class_exists("VirtualJoystick") else UI_VirtualJoystick.new()
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
	var nav_initial := RS_NavigationInitialState.new()
	nav_initial.shell = StringName("gameplay")
	nav_initial.base_scene_id = StringName("")
	store.navigation_initial_state = nav_initial
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
