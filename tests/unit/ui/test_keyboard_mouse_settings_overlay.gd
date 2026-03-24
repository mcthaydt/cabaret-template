extends GutTest

const OverlayScene := preload("res://scenes/ui/overlays/ui_keyboard_mouse_settings_overlay.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")

var _store: TestStateStore

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null
	_store = TestStateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	if _store.settings != null:
		_store.settings.enable_persistence = false
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await _pump()
	await _pump()

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null
	_store = null
	U_ServiceLocator.clear()

func test_overlay_populates_values_from_store() -> void:
	_store.dispatch(U_InputActions.update_mouse_sensitivity(0.55))
	_store.dispatch(U_InputActions.set_keyboard_look_enabled(true))
	_store.dispatch(U_InputActions.set_keyboard_look_speed(3.5))
	await _pump()

	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var mouse_slider: HSlider = overlay.get_node("%MouseSensitivitySlider")
	var enabled_check: CheckButton = overlay.get_node("%KeyboardLookEnabledCheck")
	var speed_slider: HSlider = overlay.get_node("%KeyboardLookSpeedSlider")
	assert_almost_eq(mouse_slider.value, 0.55, 0.001)
	assert_true(enabled_check.button_pressed)
	assert_almost_eq(speed_slider.value, 3.5, 0.001)

func test_apply_dispatches_keyboard_look_actions() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var mouse_slider: HSlider = overlay.get_node("%MouseSensitivitySlider")
	var enabled_check: CheckButton = overlay.get_node("%KeyboardLookEnabledCheck")
	var speed_slider: HSlider = overlay.get_node("%KeyboardLookSpeedSlider")
	mouse_slider.value = 0.4
	enabled_check.button_pressed = true
	speed_slider.value = 4.2

	_store.dispatched_actions.clear()
	overlay.call("_on_apply_pressed")
	await _pump()
	await _pump()

	assert_true(_store.dispatched_actions.size() >= 3)
	assert_eq(_store.dispatched_actions[0].get("type"), U_InputActions.ACTION_UPDATE_MOUSE_SENSITIVITY)
	assert_eq(_store.dispatched_actions[1].get("type"), U_InputActions.ACTION_SET_KEYBOARD_LOOK_ENABLED)
	assert_eq(_store.dispatched_actions[2].get("type"), U_InputActions.ACTION_SET_KEYBOARD_LOOK_SPEED)

	var mouse_payload: Dictionary = _store.dispatched_actions[0].get("payload", {})
	assert_almost_eq(float(mouse_payload.get("sensitivity", 0.0)), 0.4, 0.001)
	var enabled_payload: Dictionary = _store.dispatched_actions[1].get("payload", {})
	assert_true(bool(enabled_payload.get("enabled", false)))
	var speed_payload: Dictionary = _store.dispatched_actions[2].get("payload", {})
	assert_almost_eq(float(speed_payload.get("speed", 0.0)), 4.2, 0.001)

func test_reset_restores_defaults_and_dispatches() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var mouse_slider: HSlider = overlay.get_node("%MouseSensitivitySlider")
	var enabled_check: CheckButton = overlay.get_node("%KeyboardLookEnabledCheck")
	var speed_slider: HSlider = overlay.get_node("%KeyboardLookSpeedSlider")
	mouse_slider.value = 4.5
	enabled_check.button_pressed = false
	speed_slider.value = 8.0

	_store.dispatched_actions.clear()
	overlay.call("_on_reset_pressed")
	await _pump()

	assert_almost_eq(mouse_slider.value, 0.6, 0.001)
	assert_true(enabled_check.button_pressed)
	assert_almost_eq(speed_slider.value, 2.0, 0.001)
	assert_eq(_store.dispatched_actions.size(), 3)
	assert_eq(_store.dispatched_actions[0].get("type"), U_InputActions.ACTION_UPDATE_MOUSE_SENSITIVITY)
	assert_eq(_store.dispatched_actions[1].get("type"), U_InputActions.ACTION_SET_KEYBOARD_LOOK_ENABLED)
	assert_eq(_store.dispatched_actions[2].get("type"), U_InputActions.ACTION_SET_KEYBOARD_LOOK_SPEED)

func _pump() -> void:
	await get_tree().process_frame

class TestStateStore extends M_StateStore:
	var dispatched_actions: Array = []

	func dispatch(action: Dictionary) -> void:
		dispatched_actions.append(action.duplicate(true))
		super.dispatch(action)
