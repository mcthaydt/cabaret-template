extends BaseTest

## Integration tests for Display settings UI (Phase 7)
##
## Validates:
## - UI initializes from Redux state
## - UI edits do not dispatch until Apply (Apply/Cancel pattern)
## - Preview updates display manager without dispatch
## - Apply/Reset dispatch display actions and update state
## - Cancel discards edits and clears preview
## - Window/quality settings apply through DisplayManager
## - Display settings persist across handoff and save/load

const M_DISPLAY_MANAGER := preload("res://scripts/managers/m_display_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_display_initial_state.gd")
const MOCK_WINDOW_OPS := preload("res://tests/mocks/mock_window_ops.gd")

const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

const DISPLAY_SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/settings/ui_display_settings_overlay.tscn")
const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")
const DEFAULT_DISPLAY_INITIAL_STATE: Resource = preload("res://resources/base_settings/state/cfg_display_initial_state.tres")

const TEST_SAVE_PATH := "user://test_display_settings_ui.json"

var _store: M_StateStore
var _display_manager: M_DisplayManager
var _post_process_overlay: Node
var _window_ops: MockWindowOps

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = _create_state_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_post_process_overlay = POST_PROCESS_OVERLAY_SCENE.instantiate()
	_post_process_overlay.name = "PostProcessOverlay"
	add_child_autofree(_post_process_overlay)

	_display_manager = M_DISPLAY_MANAGER.new()
	_window_ops = MOCK_WINDOW_OPS.new()
	_window_ops.os_name = "macOS"
	_display_manager.window_ops = _window_ops
	add_child_autofree(_display_manager)

	await get_tree().process_frame
	_remove_test_save_file()

func after_each() -> void:
	_remove_test_save_file()
	U_STATE_HANDOFF.clear_all()
	super.after_each()

func _create_state_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.display_initial_state = RS_DISPLAY_INITIAL_STATE.new()
	return store

func _instantiate_overlay() -> UI_DisplaySettingsOverlay:
	var overlay := DISPLAY_SETTINGS_OVERLAY_SCENE.instantiate() as UI_DisplaySettingsOverlay
	add_child_autofree(overlay)
	await _await_overlay_store_ready(overlay)
	return overlay

func _await_overlay_store_ready(overlay: UI_DisplaySettingsOverlay, max_frames: int = 30) -> void:
	for _i in range(max_frames):
		await get_tree().process_frame
		if overlay != null and overlay.get_store() != null:
			return

func _get_tab(overlay: Node) -> UI_DisplaySettingsTab:
	return overlay.get_node_or_null("CenterContainer/Panel/VBox/DisplaySettingsTab") as UI_DisplaySettingsTab

func _remove_test_save_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

func _collect_display_action_types(actions: Array[Dictionary]) -> Array[StringName]:
	var types: Array[StringName] = []
	for action in actions:
		var action_type: Variant = action.get("type", StringName(""))
		if action_type is StringName and String(action_type).begins_with("display/"):
			types.append(action_type)
	return types

func _await_deferred(frames: int = 2) -> void:
	for _i in range(frames):
		await get_tree().process_frame

func _skip_rendering_tests() -> bool:
	if OS.has_feature("headless") or OS.has_feature("server"):
		pending("Skipped: RenderingServer unavailable in headless mode")
		return true
	return false


func test_controls_initialize_from_redux_state() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_window_mode("borderless"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_vsync_enabled(false))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_intensity(0.35))
	_store.dispatch(U_DISPLAY_ACTIONS.set_dither_pattern("noise"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(1.2))
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode("tritanopia"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_high_contrast_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_shader_enabled(true))

	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "DisplaySettingsTab should exist")

	assert_eq(
		tab._window_mode_option.selected,
		tab._window_mode_values.find("borderless"),
		"Window mode should init from state"
	)
	assert_false(tab._vsync_toggle.button_pressed, "VSync toggle should init from state")
	assert_true(tab._film_grain_toggle.button_pressed, "Film grain toggle should init from state")
	assert_almost_eq(tab._film_grain_intensity_slider.value, 0.35, 0.001, "Film grain intensity should init from state")
	assert_eq(
		tab._dither_pattern_option.selected,
		tab._dither_pattern_values.find("noise"),
		"Dither pattern should init from state"
	)
	assert_almost_eq(tab._ui_scale_slider.value, 1.2, 0.001, "UI scale should init from state")
	assert_eq(
		tab._color_blind_mode_option.selected,
		tab._color_blind_mode_values.find("tritanopia"),
		"Color blind mode should init from state"
	)
	assert_true(tab._high_contrast_toggle.button_pressed, "High contrast toggle should init from state")
	assert_true(tab._color_blind_shader_toggle.button_pressed, "Color blind shader toggle should init from state")

func test_changes_do_not_dispatch_until_apply() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._vsync_toggle.button_pressed = false
	tab._film_grain_intensity_slider.value = 0.5
	var mode_idx := tab._window_mode_values.find("fullscreen")
	tab._window_mode_option.select(mode_idx)
	await get_tree().process_frame

	assert_eq(
		_collect_display_action_types(dispatched).size(),
		0,
		"Changing controls should not dispatch display actions until Apply"
	)

func test_preview_updates_display_manager_on_edit() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	tab._ui_scale_slider.value = 1.2
	await get_tree().process_frame

	assert_true(bool(_display_manager.get("_display_settings_preview_active")), "Preview should be active after edits")
	var preview: Dictionary = _display_manager.get("_preview_settings")
	assert_almost_eq(float(preview.get("ui_scale", 0.0)), 1.2, 0.001, "Preview settings should include ui_scale")

func test_apply_dispatches_actions_and_updates_state() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	var mode_idx := tab._window_mode_values.find("fullscreen")
	tab._window_mode_option.select(mode_idx)
	tab._vsync_toggle.button_pressed = false
	tab._film_grain_toggle.button_pressed = true
	tab._film_grain_intensity_slider.value = 0.4
	tab._ui_scale_slider.value = 1.2
	var cb_idx := tab._color_blind_mode_values.find("protanopia")
	tab._color_blind_mode_option.select(cb_idx)
	tab._high_contrast_toggle.button_pressed = true
	tab._color_blind_shader_toggle.button_pressed = true
	await get_tree().process_frame

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame
	if tab._window_confirm_dialog != null and tab._window_confirm_dialog.visible:
		tab._window_confirm_dialog.emit_signal("confirmed")
		await get_tree().process_frame

	var display_actions := _collect_display_action_types(dispatched)
	assert_eq(display_actions.size(), 18, "Apply should dispatch all display actions")

	var state: Dictionary = _store.get_state()
	assert_eq(U_DISPLAY_SELECTORS.get_window_mode(state), "fullscreen", "Apply should persist window mode")
	assert_false(U_DISPLAY_SELECTORS.is_vsync_enabled(state), "Apply should persist vsync")
	assert_true(U_DISPLAY_SELECTORS.is_film_grain_enabled(state), "Apply should persist film grain enabled")
	assert_almost_eq(U_DISPLAY_SELECTORS.get_film_grain_intensity(state), 0.4, 0.001, "Apply should persist film grain intensity")
	assert_almost_eq(U_DISPLAY_SELECTORS.get_ui_scale(state), 1.2, 0.001, "Apply should persist UI scale")
	assert_eq(U_DISPLAY_SELECTORS.get_color_blind_mode(state), "protanopia", "Apply should persist color blind mode")
	assert_true(U_DISPLAY_SELECTORS.is_high_contrast_enabled(state), "Apply should persist high contrast")
	assert_true(U_DISPLAY_SELECTORS.is_color_blind_shader_enabled(state), "Apply should persist color blind shader")
	assert_false(bool(_display_manager.get("_display_settings_preview_active")), "Apply should clear preview mode")

func test_apply_clears_preview_flag() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	tab._ui_scale_slider.value = 1.2
	await get_tree().process_frame
	assert_true(bool(_display_manager.get("_display_settings_preview_active")), "Preview should activate on edit")

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_false(bool(_display_manager.get("_display_settings_preview_active")), "Apply should clear preview mode")

func test_apply_with_window_change_requires_confirm() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	var mode_idx := tab._window_mode_values.find("fullscreen")
	tab._window_mode_option.select(mode_idx)
	await get_tree().process_frame

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame

	var display_actions := _collect_display_action_types(dispatched)
	assert_false(
		display_actions.has(U_DISPLAY_ACTIONS.ACTION_SET_WINDOW_MODE),
		"Window mode should not dispatch until confirmed"
	)
	assert_false(
		display_actions.has(U_DISPLAY_ACTIONS.ACTION_SET_WINDOW_SIZE_PRESET),
		"Window size should not dispatch until confirmed"
	)
	assert_true(tab._window_confirm_dialog.visible, "Confirm dialog should appear on window changes")

	if tab._window_confirm_dialog != null and tab._window_confirm_dialog.visible:
		tab._window_confirm_dialog.emit_signal("canceled")
		await get_tree().process_frame

func test_window_confirm_revert_restores_window_ops() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_window_mode("windowed"))
	await _await_deferred()

	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var mode_idx := tab._window_mode_values.find("fullscreen")
	tab._window_mode_option.select(mode_idx)
	tab._window_mode_option.emit_signal("item_selected", mode_idx)
	await _await_deferred()

	tab._apply_button.emit_signal("pressed")
	await _await_deferred()

	assert_eq(_window_ops.window_mode, DisplayServer.WINDOW_MODE_FULLSCREEN, "Preview should apply fullscreen mode")

	if tab._window_confirm_dialog != null:
		tab._window_confirm_dialog.emit_signal("canceled")
		await _await_deferred()

	assert_eq(_window_ops.window_mode, DisplayServer.WINDOW_MODE_WINDOWED, "Revert should restore prior window mode")

func test_cancel_discards_changes_and_clears_preview() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(1.1))

	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._ui_scale_slider.value = 1.3
	await get_tree().process_frame

	tab._cancel_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_eq(_collect_display_action_types(dispatched).size(), 0, "Cancel should not dispatch display actions")

	var state: Dictionary = _store.get_state()
	assert_almost_eq(U_DISPLAY_SELECTORS.get_ui_scale(state), 1.1, 0.001, "Cancel should preserve UI scale")
	assert_false(bool(_display_manager.get("_display_settings_preview_active")), "Cancel should clear preview mode")

func test_reset_restores_defaults_and_persists_immediately() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_window_mode("fullscreen"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(1.2))

	var defaults_dict: Dictionary = DEFAULT_DISPLAY_INITIAL_STATE.to_dictionary()
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._reset_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_eq(_collect_display_action_types(dispatched).size(), 18, "Reset should dispatch all display actions")

	var state: Dictionary = _store.get_state()
	assert_eq(U_DISPLAY_SELECTORS.get_window_mode(state), defaults_dict.get("window_mode"), "Reset should restore window mode")
	assert_eq(U_DISPLAY_SELECTORS.get_quality_preset(state), defaults_dict.get("quality_preset"), "Reset should restore quality preset")
	assert_almost_eq(U_DISPLAY_SELECTORS.get_ui_scale(state), defaults_dict.get("ui_scale"), 0.001, "Reset should restore UI scale")
	assert_eq(
		U_DISPLAY_SELECTORS.is_film_grain_enabled(state),
		defaults_dict.get("film_grain_enabled"),
		"Reset should restore film grain enabled"
	)

func test_state_changes_refresh_ui_when_not_editing() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_intensity(0.55))
	await get_tree().process_frame

	assert_almost_eq(tab._film_grain_intensity_slider.value, 0.55, 0.001, "UI should update slider from state")
	assert_eq(tab._film_grain_intensity_value.text, "55%", "UI should update percentage label from state")

func test_state_changes_do_not_override_local_edits() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	tab._film_grain_intensity_slider.value = 0.35
	await get_tree().process_frame

	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_intensity(0.8))
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_almost_eq(tab._film_grain_intensity_slider.value, 0.35, 0.001, "Local edits should not be overridden")

func test_window_mode_change_applies_to_display_server() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_window_mode("fullscreen"))
	await _await_deferred()

	assert_eq(_window_ops.window_mode, DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen mode should apply to window ops")

func test_window_size_preset_applies_to_display_server() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_window_size_preset("1280x720"))
	await _await_deferred()

	assert_eq(_window_ops.window_size, Vector2i(1280, 720), "Window size preset should apply to window ops")

func test_vsync_toggle_applies_to_display_server() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_vsync_enabled(true))
	await _await_deferred()
	assert_eq(_window_ops.vsync_mode, DisplayServer.VSYNC_ENABLED, "VSync enabled should apply to window ops")

	_store.dispatch(U_DISPLAY_ACTIONS.set_vsync_enabled(false))
	await _await_deferred()
	assert_eq(_window_ops.vsync_mode, DisplayServer.VSYNC_DISABLED, "VSync disabled should apply to window ops")

func test_quality_preset_updates_viewport_aa() -> void:
	if _skip_rendering_tests():
		return

	var viewport := _display_manager.get_viewport()
	_store.dispatch(U_DISPLAY_ACTIONS.set_quality_preset("low"))
	await get_tree().process_frame
	assert_eq(viewport.msaa_3d, Viewport.MSAA_DISABLED, "Low preset should disable MSAA")
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED, "Low preset should disable screen-space AA")

	_store.dispatch(U_DISPLAY_ACTIONS.set_quality_preset("high"))
	await get_tree().process_frame
	assert_eq(viewport.msaa_3d, Viewport.MSAA_4X, "High preset should set MSAA 4x")
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED, "High preset should disable screen-space AA")

func test_settings_persist_across_state_handoff() -> void:
	U_STATE_HANDOFF.clear_all()
	U_SERVICE_LOCATOR.clear()

	var store := _create_state_store()
	add_child_autofree(store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), store)
	await get_tree().process_frame

	store.dispatch(U_DISPLAY_ACTIONS.set_window_mode("borderless"))
	store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(1.2))
	await get_tree().process_frame

	store.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	U_SERVICE_LOCATOR.clear()
	var restored_store := _create_state_store()
	add_child_autofree(restored_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), restored_store)
	await get_tree().process_frame

	var restored_state: Dictionary = restored_store.get_state()
	assert_eq(U_DISPLAY_SELECTORS.get_window_mode(restored_state), "borderless", "Window mode should persist via handoff")
	assert_almost_eq(U_DISPLAY_SELECTORS.get_ui_scale(restored_state), 1.2, 0.001, "UI scale should persist via handoff")

func test_settings_persist_in_save_file() -> void:
	_store.dispatch(U_DISPLAY_ACTIONS.set_window_mode("fullscreen"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(true))
	_store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(1.2))

	var save_err := _store.save_state(TEST_SAVE_PATH)
	assert_eq(save_err, OK, "save_state should succeed")
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "Save file should exist")

	_store.dispatch(U_DISPLAY_ACTIONS.set_window_mode("windowed"))
	_store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(false))
	_store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(1.0))

	var load_err := _store.load_state(TEST_SAVE_PATH)
	assert_eq(load_err, OK, "load_state should succeed")

	var state: Dictionary = _store.get_state()
	assert_eq(U_DISPLAY_SELECTORS.get_window_mode(state), "fullscreen", "Window mode should restore from save")
	assert_true(U_DISPLAY_SELECTORS.is_film_grain_enabled(state), "Film grain enabled should restore from save")
	assert_almost_eq(U_DISPLAY_SELECTORS.get_ui_scale(state), 1.2, 0.001, "UI scale should restore from save")
