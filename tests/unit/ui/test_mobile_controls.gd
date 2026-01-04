extends GutTest

const MobileControlsScene := preload("res://scenes/ui/ui_mobile_controls.tscn")
const UI_VirtualButton := preload("res://scripts/ui/ui_virtual_button.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/state/resources/rs_navigation_initial_state.gd")
const RS_InputProfile := preload("res://scripts/input/resources/rs_input_profile.gd")
const DefaultTouchscreenProfile := preload("res://resources/input/profiles/default_touchscreen.tres")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_SceneActions := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_despawns_on_non_mobile_without_emulation() -> void:
	var controls := await _create_controls()
	await _await_frames(1)
	assert_false(is_instance_valid(controls), "Controls should queue_free on non-mobile without emulation")

func test_builds_joystick_and_buttons_from_profile() -> void:
	await _create_state_store()
	var controls := await _create_controls(func(instance):
		instance.force_enable = true
	)
	assert_true(is_instance_valid(controls), "Controls should stay alive when forced for tests")
	var joystick := controls.get_node_or_null("Controls/VirtualJoystick")
	assert_not_null(joystick, "VirtualJoystick should be instantiated")

	var buttons: Array = controls.get_buttons()
	assert_eq(buttons.size(), DefaultTouchscreenProfile.virtual_buttons.size(),
		"MobileControls should create one button per profile entry")

	var viewport_size: Vector2 = controls.get_viewport().get_visible_rect().size
	for button_data in DefaultTouchscreenProfile.virtual_buttons:
		var action: StringName = button_data.get("action", StringName())
		var found := _find_button(buttons, action)
		assert_not_null(found, "Button for action %s should exist" % action)
		var expected_pos: Vector2 = button_data.get("position", Vector2.ZERO)
		var clamped := _expected_clamped_position(expected_pos, found, viewport_size)
		assert_vector_almost_eq(found.position, clamped, 0.001, "Button %s should use profile position (clamped to viewport)" % action)

func test_applies_custom_positions_from_state() -> void:
	var store := await _create_state_store()
	var custom_joystick := Vector2(320, 360)
	var custom_jump := Vector2(640, 420)
	store.dispatch(U_InputActions.save_virtual_control_position("virtual_joystick", custom_joystick))
	store.dispatch(U_InputActions.save_virtual_control_position("jump", custom_jump))

	var controls := await _create_controls(func(instance):
		instance.force_enable = true
	)
	await _await_frames(1)
	assert_true(is_instance_valid(controls))

	var joystick := controls.get_node_or_null("Controls/VirtualJoystick")
	assert_not_null(joystick)
	var viewport_size: Vector2 = controls.get_viewport().get_visible_rect().size
	var clamped_joystick := _expected_clamped_position(custom_joystick, joystick, viewport_size)
	assert_vector_almost_eq(joystick.position, clamped_joystick, 0.001,
		"Joystick should use custom position from state (clamped to viewport)")

	var buttons: Array = controls.get_buttons()
	var jump_button := _find_button(buttons, StringName("jump"))
	assert_not_null(jump_button, "Jump button should exist")
	var clamped_jump := _expected_clamped_position(custom_jump, jump_button, viewport_size)
	assert_vector_almost_eq(jump_button.position, clamped_jump, 0.001,
		"Jump button should use custom saved position (clamped to viewport)")

func test_visibility_follows_device_pause_and_transition_state() -> void:
	var store := await _create_state_store()
	store.dispatch(U_NavigationActions.start_game(StringName("exterior")))
	var controls := await _create_controls(func(instance):
		instance.force_enable = true
	)
	await _await_frames(1)
	assert_true(controls.visible, "Controls default to visible when enabled")

	store.dispatch(U_NavigationActions.return_to_main_menu())
	await wait_process_frames(2)
	assert_false(controls.visible, "Controls hide on non-gameplay scenes (main_menu)")

	store.dispatch(U_NavigationActions.start_game(StringName("exterior")))
	await wait_process_frames(2)
	assert_true(controls.visible, "Controls show when active scene is gameplay (exterior)")

	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.GAMEPAD, -1, 0.0))
	await wait_process_frames(2)
	assert_false(controls.visible, "Controls hide when gamepad is active")

	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1, 0.0))
	await wait_process_frames(2)
	assert_true(controls.visible, "Controls show when touchscreen is active")

	store.dispatch(U_NavigationActions.open_pause())
	await wait_process_frames(2)
	assert_false(controls.visible, "Controls hide when pause overlay is active")

	store.dispatch(U_NavigationActions.close_top_overlay())
	await wait_process_frames(2)
	assert_true(controls.visible, "Controls show again after pause overlay closes")

	store.dispatch(U_SceneActions.transition_started(StringName("gameplay_base"), "fade"))
	await wait_process_frames(1)
	assert_false(controls.visible, "Controls hide during scene transitions")

	store.dispatch(U_SceneActions.transition_completed(StringName("gameplay_base")))
	await wait_process_frames(1)
	assert_true(controls.visible, "Controls show after transition completes")

func test_opacity_tween_fades_after_idle_delay() -> void:
	await _create_state_store()
	var controls := await _create_controls(func(instance):
		instance.force_enable = true
		instance.fade_delay = 0.05
		instance.fade_duration = 0.05
		instance.idle_opacity = 0.4
		instance.active_opacity = 1.0
	)
	await _await_frames(1)
	var root := controls.get_node_or_null("Controls") as Control
	assert_not_null(root)
	controls._on_input_activity()
	assert_almost_eq(root.modulate.a, controls.active_opacity, 0.001,
		"Input activity should set opacity to active level immediately")

	await wait_process_frames(6)
	assert_almost_eq(root.modulate.a, controls.idle_opacity, 0.05,
		"Opacity should fade to idle level after delay + tween")

func test_controls_clamped_within_viewport_bounds() -> void:
	await _create_state_store()
	var controls := await _create_controls(func(instance):
		instance.force_enable = true
	)
	await _await_frames(1)
	var viewport_size: Vector2 = controls.get_viewport().get_visible_rect().size

	var joystick := controls.get_node_or_null("Controls/VirtualJoystick") as Control
	_assert_control_inside_viewport(joystick, viewport_size, "Joystick should be clamped inside viewport")

	for button in controls.get_buttons():
		_assert_control_inside_viewport(button as Control, viewport_size, "Buttons should be clamped inside viewport")

func test_input_activity_ignored_when_overlay_active() -> void:
	var store := await _create_state_store()
	store.dispatch(U_NavigationActions.start_game(StringName("exterior")))
	var controls := await _create_controls(func(instance):
		instance.force_enable = true
	)
	await _await_frames(1)
	controls._fade_elapsed = 0.5
	controls._is_fading = false

	store.dispatch(U_NavigationActions.open_pause())
	await wait_process_frames(2)

	controls._on_input_activity()

	assert_false(controls._is_fading, "Controls should ignore input activity while overlay is active")
	assert_almost_eq(controls._fade_elapsed, 0.5, 0.001,
		"Fade timer should not reset when overlay is active")

func test_gamepad_used_in_menu_keeps_controls_hidden_after_close() -> void:
	var store := await _create_state_store()
	store.dispatch(U_NavigationActions.start_game(StringName("exterior")))
	var controls := await _create_controls(func(instance):
		instance.force_enable = true
	)
	await wait_process_frames(2)
	assert_true(controls.visible, "Controls should be visible in gameplay with touchscreen")

	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.GAMEPAD, 0, 0.0))
	await wait_process_frames(2)
	assert_false(controls.visible, "Controls should hide when gamepad becomes active")

	store.dispatch(U_NavigationActions.open_pause())
	await wait_process_frames(2)
	assert_false(controls.visible, "Controls should stay hidden when pause opens with gamepad")

	store.dispatch(U_NavigationActions.close_pause())
	await wait_process_frames(2)
	assert_false(controls.visible, "BUG FIX: Controls should stay hidden after closing pause with gamepad (not reappear)")

func _create_controls(configure: Callable = Callable()) -> Node:
	var controls := MobileControlsScene.instantiate()
	if configure != Callable() and configure.is_valid():
		configure.call(controls)
	add_child_autofree(controls)
	await _await_frames(2)
	return controls

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.scene_initial_state.current_scene_id = StringName("gameplay_base")
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	add_child_autofree(store)
	await _await_frames(2)
	return store

func _find_button(buttons: Array, action: StringName) -> UI_VirtualButton:
	for button in buttons:
		if button is UI_VirtualButton and (button as UI_VirtualButton).action == action:
			return button as UI_VirtualButton
	return null

func assert_vector_almost_eq(a: Vector2, b: Vector2, tolerance: float, message: String = "") -> void:
	assert_almost_eq(a.x, b.x, tolerance, message + " (x)")
	assert_almost_eq(a.y, b.y, tolerance, message + " (y)")

func _assert_control_inside_viewport(control: Control, viewport_size: Vector2, message: String) -> void:
	assert_not_null(control, message)
	var rect: Rect2 = control.get_global_rect()
	assert_true(rect.position.x >= -0.001, message + " (left)")
	assert_true(rect.position.y >= -0.001, message + " (top)")
	assert_true(rect.position.x + rect.size.x <= viewport_size.x + 0.001, message + " (right)")
	assert_true(rect.position.y + rect.size.y <= viewport_size.y + 0.001, message + " (bottom)")

func _expected_clamped_position(target: Vector2, control: Control, viewport_size: Vector2) -> Vector2:
	var size: Vector2 = control.size
	var scaled_size: Vector2 = size * control.scale
	return Vector2(
		clampf(target.x, 0.0, max(viewport_size.x - scaled_size.x, 0.0)),
		clampf(target.y, 0.0, max(viewport_size.y - scaled_size.y, 0.0))
	)

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
