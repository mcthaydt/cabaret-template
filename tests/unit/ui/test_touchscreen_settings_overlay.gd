extends GutTest

const OverlayScene := preload("res://scenes/ui/ui_touchscreen_settings_overlay.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

var _store: TestStateStore
var _profile_manager_mock: ProfileManagerMock

func before_each() -> void:
	U_StateHandoff.clear_all()
	_store = TestStateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await _pump()
	await _pump()

	_profile_manager_mock = ProfileManagerMock.new()
	add_child_autofree(_profile_manager_mock)
	U_ServiceLocator.register(StringName("input_profile_manager"), _profile_manager_mock)

func after_each() -> void:
	U_StateHandoff.clear_all()
	_store = null
	_profile_manager_mock = null
	U_ServiceLocator.clear()

func test_overlay_populates_values_from_store() -> void:
	var settings := {
		"virtual_joystick_size": 1.5,
		"button_size": 1.2,
		"virtual_joystick_opacity": 0.6,
		"button_opacity": 0.9,
		"joystick_deadzone": 0.25,
	}
	_store.dispatch(U_InputActions.update_touchscreen_settings(settings))
	await _pump()

	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var joystick_size_slider: HSlider = overlay.get_node("%JoystickSizeSlider")
	var button_size_slider: HSlider = overlay.get_node("%ButtonSizeSlider")
	var joystick_opacity_slider: HSlider = overlay.get_node("%JoystickOpacitySlider")
	var button_opacity_slider: HSlider = overlay.get_node("%ButtonOpacitySlider")
	var joystick_deadzone_slider: HSlider = overlay.get_node("%JoystickDeadzoneSlider")

	assert_almost_eq(joystick_size_slider.value, 1.5, 0.001)
	assert_almost_eq(button_size_slider.value, 1.2, 0.001)
	assert_almost_eq(joystick_opacity_slider.value, 0.6, 0.001)
	assert_almost_eq(button_opacity_slider.value, 0.9, 0.001)
	assert_almost_eq(joystick_deadzone_slider.value, 0.25, 0.001)

func test_slider_updates_preview_in_real_time() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var joystick_size_slider: HSlider = overlay.get_node("%JoystickSizeSlider")
	var joystick_opacity_slider: HSlider = overlay.get_node("%JoystickOpacitySlider")
	var joystick_deadzone_slider: HSlider = overlay.get_node("%JoystickDeadzoneSlider")
	var button_size_slider: HSlider = overlay.get_node("%ButtonSizeSlider")
	var button_opacity_slider: HSlider = overlay.get_node("%ButtonOpacitySlider")

	var preview_joystick: Control = overlay.get_node("%PreviewContainer/PreviewJoystick")
	var preview_button: Control = overlay.get_node("%PreviewContainer/PreviewButton_jump")

	joystick_size_slider.value = 1.8
	joystick_size_slider.emit_signal("value_changed", joystick_size_slider.value)
	joystick_opacity_slider.value = 0.5
	joystick_opacity_slider.emit_signal("value_changed", joystick_opacity_slider.value)
	joystick_deadzone_slider.value = 0.3
	joystick_deadzone_slider.emit_signal("value_changed", joystick_deadzone_slider.value)
	button_size_slider.value = 1.4
	button_size_slider.emit_signal("value_changed", button_size_slider.value)
	button_opacity_slider.value = 0.4
	button_opacity_slider.emit_signal("value_changed", button_opacity_slider.value)

	await _pump()

	assert_vector_almost_eq(preview_joystick.scale, Vector2.ONE * 1.8, 0.001, "Joystick scale should match slider")
	assert_almost_eq(preview_joystick.modulate.a, 0.5, 0.001, "Joystick opacity should match slider")
	if "deadzone" in preview_joystick:
		assert_almost_eq(preview_joystick.deadzone, 0.3, 0.001, "Joystick deadzone should match slider")

	assert_vector_almost_eq(preview_button.scale, Vector2.ONE * 1.4, 0.001, "Button scale should match slider")
	assert_almost_eq(preview_button.modulate.a, 0.4, 0.001, "Button opacity should match slider")

func test_apply_dispatches_update_to_store_and_closes_overlay() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var joystick_size_slider: HSlider = overlay.get_node("%JoystickSizeSlider")
	var button_size_slider: HSlider = overlay.get_node("%ButtonSizeSlider")
	var joystick_opacity_slider: HSlider = overlay.get_node("%JoystickOpacitySlider")
	var button_opacity_slider: HSlider = overlay.get_node("%ButtonOpacitySlider")
	var joystick_deadzone_slider: HSlider = overlay.get_node("%JoystickDeadzoneSlider")

	joystick_size_slider.value = 1.6
	button_size_slider.value = 1.1
	joystick_opacity_slider.value = 0.55
	button_opacity_slider.value = 0.75
	joystick_deadzone_slider.value = 0.2

	_store.dispatched_actions.clear()
	var close_count_before := _count_navigation_close_or_return_actions()
	overlay.call("_on_apply_pressed")
	await _pump()
	await _pump()

	assert_eq(_store.dispatched_actions.size(), 2, "Apply should dispatch settings update and navigation close")
	var action: Dictionary = _store.dispatched_actions[0]
	assert_eq(action.get("type"), U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS, "Action type should be update_touchscreen_settings")

	var payload: Dictionary = action.get("payload", {})
	var settings: Dictionary = payload.get("settings", {})
	assert_almost_eq(float(settings.get("virtual_joystick_size", 0.0)), 1.6, 0.001)
	assert_almost_eq(float(settings.get("button_size", 0.0)), 1.1, 0.001)
	assert_almost_eq(float(settings.get("virtual_joystick_opacity", 0.0)), 0.55, 0.001)
	assert_almost_eq(float(settings.get("button_opacity", 0.0)), 0.75, 0.001)
	assert_almost_eq(float(settings.get("joystick_deadzone", 0.0)), 0.2, 0.001)

	var close_count_after := _count_navigation_close_or_return_actions()
	assert_eq(close_count_after, close_count_before + 1,
		"Apply should dispatch exactly one navigation close/return action")

func test_reset_restores_default_values_and_calls_profile_manager() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var joystick_size_slider: HSlider = overlay.get_node("%JoystickSizeSlider")
	var button_size_slider: HSlider = overlay.get_node("%ButtonSizeSlider")
	var joystick_opacity_slider: HSlider = overlay.get_node("%JoystickOpacitySlider")
	var button_opacity_slider: HSlider = overlay.get_node("%ButtonOpacitySlider")
	var joystick_deadzone_slider: HSlider = overlay.get_node("%JoystickDeadzoneSlider")

	joystick_size_slider.value = 1.8
	button_size_slider.value = 1.4
	joystick_opacity_slider.value = 0.4
	button_opacity_slider.value = 0.5
	joystick_deadzone_slider.value = 0.3

	overlay.call("_on_reset_pressed")
	await _pump()

	assert_almost_eq(joystick_size_slider.value, 0.8, 0.001, "Joystick size should reset to default")
	assert_almost_eq(button_size_slider.value, 1.1, 0.001, "Button size should reset to default")
	assert_almost_eq(joystick_opacity_slider.value, 0.7, 0.001, "Joystick opacity should reset to default")
	assert_almost_eq(button_opacity_slider.value, 0.8, 0.001, "Button opacity should reset to default")
	assert_almost_eq(joystick_deadzone_slider.value, 0.15, 0.001, "Joystick deadzone should reset to default")

	assert_true(_profile_manager_mock.reset_called, "Profile manager should be called to reset touchscreen positions")

func test_reset_dispatches_default_settings_to_store() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var joystick_size_slider: HSlider = overlay.get_node("%JoystickSizeSlider")
	var button_size_slider: HSlider = overlay.get_node("%ButtonSizeSlider")
	var joystick_opacity_slider: HSlider = overlay.get_node("%JoystickOpacitySlider")
	var button_opacity_slider: HSlider = overlay.get_node("%ButtonOpacitySlider")
	var joystick_deadzone_slider: HSlider = overlay.get_node("%JoystickDeadzoneSlider")

	joystick_size_slider.value = 1.8
	button_size_slider.value = 1.4
	joystick_opacity_slider.value = 0.4
	button_opacity_slider.value = 0.5
	joystick_deadzone_slider.value = 0.3

	_store.dispatched_actions.clear()
	overlay.call("_on_reset_pressed")
	await _pump()

	assert_eq(_store.dispatched_actions.size(), 1, "Reset should dispatch a single touchscreen settings update")
	var action: Dictionary = _store.dispatched_actions[0]
	assert_eq(action.get("type"), U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS)
	var payload: Dictionary = action.get("payload", {})
	var settings: Dictionary = payload.get("settings", {})
	assert_almost_eq(float(settings.get("virtual_joystick_size", -1.0)), 0.8, 0.001)
	assert_almost_eq(float(settings.get("button_size", -1.0)), 1.1, 0.001)
	assert_almost_eq(float(settings.get("virtual_joystick_opacity", -1.0)), 0.7, 0.001)
	assert_almost_eq(float(settings.get("button_opacity", -1.0)), 0.8, 0.001)
	assert_almost_eq(float(settings.get("joystick_deadzone", -1.0)), 0.15, 0.001)

func test_cancel_discards_changes_and_closes_overlay() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var joystick_size_slider: HSlider = overlay.get_node("%JoystickSizeSlider")
	joystick_size_slider.value = 1.9

	_store.dispatched_actions.clear()
	var close_count_before := _count_navigation_close_or_return_actions()
	overlay.call("_on_cancel_pressed")
	await _pump()

	var close_count_after := _count_navigation_close_or_return_actions()
	assert_eq(close_count_after, close_count_before + 1,
		"Cancel should dispatch a single navigation close/return action")
	assert_eq(_store.dispatched_actions.size(), 1, "Cancel should only dispatch navigation action")

func test_cancel_from_main_menu_requests_settings_menu_scene_transition() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	# Simulate main_menu shell with touchscreen_settings as the active base scene
	var nav_slice: Dictionary = _store.get_slice(StringName("navigation"))
	nav_slice["shell"] = StringName("main_menu")
	nav_slice["base_scene_id"] = StringName("touchscreen_settings")
	nav_slice["overlay_stack"] = []
	nav_slice["overlay_return_stack"] = []
	nav_slice["active_menu_panel"] = StringName("menu/main")
	_store._state[StringName("navigation")] = nav_slice.duplicate(true)

	_store.dispatched_actions.clear()
	overlay.call("_on_cancel_pressed")
	await _pump()

	# Check that navigate_to_ui_screen action was dispatched with settings_menu
	var navigate_action: Dictionary = {}
	for action in _store.dispatched_actions:
		if action.get("type") == U_NavigationActions.ACTION_NAVIGATE_TO_UI_SCREEN:
			navigate_action = action
			break

	assert_eq(
		navigate_action.get("scene_id"),
		StringName("settings_menu"),
		"Cancel from main menu touchscreen_settings should dispatch navigate_to_ui_screen(settings_menu)"
	)

func test_horizontal_navigation_skips_hidden_edit_layout_in_main_menu() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var cancel_button: Button = overlay.get_node("%CancelButton")
	var reset_button: Button = overlay.get_node("%ResetButton")
	var apply_button: Button = overlay.get_node("%ApplyButton")
	var edit_layout_button: Button = overlay.get_node("%EditLayoutButton")

	assert_not_null(cancel_button)
	assert_not_null(reset_button)
	assert_not_null(apply_button)
	assert_not_null(edit_layout_button)
	assert_false(
		edit_layout_button.visible,
		"Edit Layout should be hidden when touchscreen settings are opened from main menu"
	)

	# Start with Cancel focused and navigate horizontally to the right.
	cancel_button.grab_focus()
	await _pump()

	overlay.call("_navigate_focus", StringName("ui_right"))
	await _pump()
	var focused: Control = overlay.get_viewport().gui_get_focus_owner()
	assert_eq(focused, reset_button,
		"Right from Cancel should focus Reset when Edit Layout is hidden")

	overlay.call("_navigate_focus", StringName("ui_right"))
	await _pump()
	focused = overlay.get_viewport().gui_get_focus_owner()
	assert_eq(focused, apply_button,
		"Right from Reset should focus Apply when Edit Layout is hidden")

	overlay.call("_navigate_focus", StringName("ui_right"))
	await _pump()
	focused = overlay.get_viewport().gui_get_focus_owner()
	assert_eq(focused, cancel_button,
		"Right from Apply should wrap back to Cancel")

func test_device_changed_does_not_override_local_edits() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var button_size_slider: HSlider = overlay.get_node("%ButtonSizeSlider")
	button_size_slider.value = 1.3
	button_size_slider.emit_signal("value_changed", button_size_slider.value)
	await _pump()

	# Simulate device change action that previously overwrote slider values
	var device_action := U_InputActions.device_changed(0, -1, 0.0)
	overlay.call("_on_state_changed", device_action, _store.get_state())
	await _pump()

	assert_almost_eq(button_size_slider.value, 1.3, 0.001,
		"Local slider edits should persist when non-settings actions arrive")

func test_position_only_update_does_not_override_slider_edits() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)

	var button_opacity_slider: HSlider = overlay.get_node("%ButtonOpacitySlider")
	button_opacity_slider.value = 0.35
	button_opacity_slider.emit_signal("value_changed", button_opacity_slider.value)
	await _pump()

	var position_only_action := U_InputActions.update_touchscreen_settings({
		"custom_button_positions": {
			"jump": Vector2(10, 10)
		}
	})
	_store.dispatch(position_only_action)
	overlay.call("_on_state_changed", position_only_action, _store.get_state())
	await _pump()

	assert_almost_eq(button_opacity_slider.value, 0.35, 0.001,
		"Position-only updates should not override in-progress slider edits")

func _pump() -> void:
	await get_tree().process_frame

func _refresh_overlay_state(overlay: Node) -> void:
	if overlay == null:
		return
	overlay.call("_on_state_changed", {}, _store.get_state())
	await _pump()

func assert_vector_almost_eq(a: Vector2, b: Vector2, tolerance: float, message: String = "") -> void:
	assert_almost_eq(a.x, b.x, tolerance, message + " (x)")
	assert_almost_eq(a.y, b.y, tolerance, message + " (y)")

class SceneManagerStub extends Node:
	var last_scene_id: StringName = StringName("")
	var last_transition_type: String = ""
	var last_priority: int = -1

	func transition_to_scene(scene_id: StringName, transition_type: String, priority: int = 0) -> void:
		last_scene_id = scene_id
		last_transition_type = transition_type
		last_priority = priority

class ProfileManagerMock extends Node:
	var reset_called: bool = false

	func reset_touchscreen_positions() -> void:
		reset_called = true

class TestStateStore extends M_StateStore:
	var dispatched_actions: Array = []

	func dispatch(action: Dictionary) -> void:
		dispatched_actions.append(action.duplicate(true))
		super.dispatch(action)

func _count_navigation_actions(action_type: StringName) -> int:
	if _store == null:
		return 0
	var count := 0
	for action in _store.dispatched_actions:
		if action.get("type") == action_type:
			count += 1
	return count

func _count_navigation_close_or_return_actions() -> int:
	if _store == null:
		return 0
	var count := 0
	for action in _store.dispatched_actions:
		var action_type: StringName = action.get("type", StringName())
		if action_type == U_NavigationActions.ACTION_CLOSE_TOP_OVERLAY \
				or action_type == U_NavigationActions.ACTION_RETURN_TO_MAIN_MENU:
			count += 1
		elif action_type == U_NavigationActions.ACTION_SET_SHELL:
			var shell: StringName = action.get("shell", StringName())
			var base_scene: StringName = action.get("base_scene_id", StringName())
			if shell == StringName("main_menu") and base_scene == StringName("settings_menu"):
				count += 1
		elif action_type == U_NavigationActions.ACTION_NAVIGATE_TO_UI_SCREEN:
			# navigate_to_ui_screen with settings_menu is a "return to settings" action
			var scene_id: StringName = action.get("scene_id", StringName())
			if scene_id == StringName("settings_menu"):
				count += 1
	return count
