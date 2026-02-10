extends BaseTest

const MobileControlsScene := preload("res://scenes/ui/hud/ui_mobile_controls.tscn")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_updates_component_from_virtual_controls() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_frames(1)

	var joystick: UI_VirtualJoystick = context["joystick"]
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))

	var jump_button: UI_VirtualButton = context["jump_button"]
	_press_button(jump_button)

	var manager: M_ECSManager = context["manager"]
	manager._physics_process(0.016)

	var component: C_InputComponent = context["component"]
	assert_almost_eq(component.move_vector.x, 1.0, 0.01, "Joystick drag should set move_vector")
	assert_true(component.jump_pressed, "Jump button press should set jump_pressed")

	var gameplay_slice := store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var move_input: Vector2 = input_slice.get("move_input", Vector2.ZERO)
	assert_almost_eq(move_input.x, 1.0, 0.01, "Store should receive move input from touchscreen system")
	assert_true(input_slice.get("jump_pressed", false), "Store should receive jump state from touchscreen system")

func test_skips_processing_when_device_not_touchscreen() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.GAMEPAD, 1))
	await _await_frames(1)

	var joystick: UI_VirtualJoystick = context["joystick"]
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))

	var manager: M_ECSManager = context["manager"]
	manager._physics_process(0.016)

	var component: C_InputComponent = context["component"]
	assert_true(component.move_vector.is_zero_approx(), "Non-touch device should skip touchscreen processing")

	var gameplay_slice := store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var move_input: Vector2 = input_slice.get("move_input", Vector2(5, 5))
	assert_true(move_input.is_zero_approx(), "Store move_input should remain unchanged when inactive device")

func test_emergency_disable_flag_blocks_processing() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	store.dispatch(U_DebugActions.set_disable_touchscreen(true))
	await _await_frames(1)

	var joystick: UI_VirtualJoystick = context["joystick"]
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))

	var manager: M_ECSManager = context["manager"]
	manager._physics_process(0.016)

	var component: C_InputComponent = context["component"]
	assert_true(component.move_vector.is_zero_approx(), "Emergency flag should prevent touchscreen updates")

	var debug_state := U_DebugSelectors.get_debug_settings(store.get_state())
	assert_true(debug_state.get("disable_touchscreen", false), "Debug flag should be readable from selectors")

func _setup_touchscreen_scene() -> Dictionary:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.scene_initial_state.current_scene_id = StringName("gameplay_base")
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.debug_initial_state = RS_DebugInitialState.new()
	add_child_autofree(store)
	await _await_frames(2)

	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await _await_frames(2)

	var entity := Node3D.new()
	entity.name = "E_TouchscreenPlayer"
	manager.add_child(entity)
	autofree(entity)
	await _await_frames(1)

	var component := C_InputComponent.new()
	entity.add_child(component)
	await _await_frames(1)

	var system := S_TouchscreenSystem.new()
	system.force_enable = true
	manager.add_child(system)
	await _await_frames(2)

	var controls := MobileControlsScene.instantiate()
	controls.force_enable = true
	add_child_autofree(controls)
	await _await_frames(2)

	var joystick := controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
	var buttons: Array = controls.get_buttons()
	var jump_button := _find_button(buttons, StringName("jump"))

	return {
		"store": store,
		"manager": manager,
		"component": component,
		"system": system,
		"controls": controls,
		"joystick": joystick,
		"jump_button": jump_button,
	}

func _find_button(buttons: Array, action: StringName) -> UI_VirtualButton:
	for button in buttons:
		if button is UI_VirtualButton and (button as UI_VirtualButton).action == action:
			return button as UI_VirtualButton
	return null

func _press_joystick(joystick: UI_VirtualJoystick, start: Vector2, end: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = start
	joystick._input(touch)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = end
	joystick._input(drag)

func _press_button(button: UI_VirtualButton) -> void:
	if button == null:
		return
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = button.get_global_rect().position + (button.get_global_rect().size * 0.5)
	button._input(touch)

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
