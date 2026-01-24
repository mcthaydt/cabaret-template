extends GutTest

const OverlayScene := preload("res://scenes/ui/ui_gamepad_settings_overlay.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")

var _store: TestStateStore

func before_each() -> void:
	U_StateHandoff.clear_all()
	_store = TestStateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	await _pump()
	await _pump()

func after_each() -> void:
	U_StateHandoff.clear_all()
	_store = null

func test_overlay_populates_values_from_store() -> void:
	_store.dispatch(U_InputActions.update_gamepad_deadzone("left", 0.45))
	_store.dispatch(U_InputActions.update_gamepad_deadzone("right", 0.35))
	_store.dispatch(U_InputActions.toggle_vibration(false))
	_store.dispatch(U_InputActions.set_vibration_intensity(0.5))
	await _pump()

	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)
	assert_not_null(overlay.get("_store"), "Overlay should locate M_StateStore")
	assert_eq(overlay.get("_store"), _store, "Overlay should use the active store instance")

	var left_slider: HSlider = overlay.get_node("%LeftDeadzoneSlider")
	var right_slider: HSlider = overlay.get_node("%RightDeadzoneSlider")
	var vibration_checkbox: CheckButton = overlay.get_node("%VibrationCheck")
	var vibration_slider: HSlider = overlay.get_node("%VibrationSlider")

	assert_almost_eq(left_slider.value, 0.45, 0.001)
	assert_almost_eq(right_slider.value, 0.35, 0.001)
	assert_false(vibration_checkbox.button_pressed)
	assert_almost_eq(vibration_slider.value, 0.5, 0.001)

func test_apply_updates_state_settings() -> void:
	var overlay := OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _refresh_overlay_state(overlay)
	assert_not_null(overlay.get("_store"), "Overlay should locate M_StateStore")
	assert_eq(overlay.get("_store"), _store, "Overlay should use the active store instance")

	var left_slider: HSlider = overlay.get_node("%LeftDeadzoneSlider")
	left_slider.value = 0.6
	var right_slider: HSlider = overlay.get_node("%RightDeadzoneSlider")
	right_slider.value = 0.1
	var vibration_checkbox: CheckButton = overlay.get_node("%VibrationCheck")
	vibration_checkbox.button_pressed = false
	var vibration_slider: HSlider = overlay.get_node("%VibrationSlider")
	vibration_slider.value = 0.25

	_store.dispatched_actions.clear()
	var close_before := _count_navigation_close_or_return_actions()
	overlay.call("_on_apply_pressed")
	await _pump()
	await _pump()

	assert_eq(_store.dispatched_actions.size(), 5, "Overlay should dispatch four input actions plus one navigation close action")
	var close_after := _count_navigation_close_or_return_actions()
	assert_eq(close_after, close_before + 1, "Apply should dispatch a single navigation close/navigation return action")

func _pump() -> void:
	await get_tree().process_frame

func _refresh_overlay_state(overlay: Node) -> void:
	if overlay == null:
		return
	overlay.call("_on_state_changed", {}, _store.get_state())
	await _pump()

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
	return count
