extends BaseTest

## Integration tests for VFX settings UI (Phase 6)
##
## Validates:
## - UI initializes from Redux state
## - UI edits do not dispatch until Apply
## - Apply dispatches VFX actions and updates state
## - Cancel discards edits
## - Reset updates UI to defaults (persists immediately)
## - State updates refresh UI when not editing
## - State updates do not override local edits
## - VFX settings persist to save file and restore from save file

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_VFX_ACTIONS := preload("res://scripts/state/actions/u_vfx_actions.gd")
const U_VFX_SELECTORS := preload("res://scripts/state/selectors/u_vfx_selectors.gd")

const VFX_SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/ui_vfx_settings_overlay.tscn")

const TEST_SAVE_PATH := "user://test_vfx_settings_ui.json"

var _store: M_StateStore


func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = _create_state_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)
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
	store.vfx_initial_state = RS_VFX_INITIAL_STATE.new()
	return store


func _instantiate_overlay() -> UI_VFXSettingsOverlay:
	var overlay := VFX_SETTINGS_OVERLAY_SCENE.instantiate() as UI_VFXSettingsOverlay
	add_child_autofree(overlay)
	await _await_overlay_store_ready(overlay)
	return overlay


func _await_overlay_store_ready(overlay: UI_VFXSettingsOverlay, max_frames: int = 30) -> void:
	for _i in range(max_frames):
		await get_tree().process_frame
		if overlay != null and overlay.get_store() != null:
			return


func _remove_test_save_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _collect_vfx_action_types(actions: Array[Dictionary]) -> Array[StringName]:
	var types: Array[StringName] = []
	for action in actions:
		var action_type: Variant = action.get("type", StringName(""))
		if action_type is StringName and String(action_type).begins_with("vfx/"):
			types.append(action_type)
	return types


func test_controls_initialize_from_redux_state() -> void:
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_enabled(false))
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(1.5))
	_store.dispatch(U_VFX_ACTIONS.set_damage_flash_enabled(false))
	_store.dispatch(U_VFX_ACTIONS.set_particles_enabled(false))

	var overlay := await _instantiate_overlay()

	assert_false(overlay._shake_enabled_toggle.button_pressed, "Shake toggle should init from state")
	assert_almost_eq(overlay._intensity_slider.value, 1.5, 0.001, "Intensity slider should init from state")
	assert_eq(overlay._intensity_percentage.text, "150%", "Intensity label should reflect slider value")
	assert_false(overlay._flash_enabled_toggle.button_pressed, "Flash toggle should init from state")
	assert_false(overlay._particles_enabled_toggle.button_pressed, "Particles toggle should init from state")


func test_changes_do_not_dispatch_until_apply() -> void:
	var overlay := await _instantiate_overlay()

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	overlay._shake_enabled_toggle.button_pressed = false
	overlay._intensity_slider.value = 0.5
	overlay._flash_enabled_toggle.button_pressed = false
	overlay._particles_enabled_toggle.button_pressed = false
	await get_tree().process_frame

	assert_eq(_collect_vfx_action_types(dispatched).size(), 0,
		"Changing controls should not dispatch VFX actions until Apply")


func test_apply_dispatches_actions_and_updates_state() -> void:
	var overlay := await _instantiate_overlay()

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	overlay._shake_enabled_toggle.button_pressed = false
	overlay._intensity_slider.value = 0.5
	overlay._flash_enabled_toggle.button_pressed = false
	overlay._particles_enabled_toggle.button_pressed = false

	overlay._apply_button.emit_signal("pressed")
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_false(U_VFX_SELECTORS.is_screen_shake_enabled(state), "Apply should persist shake enabled=false")
	assert_almost_eq(U_VFX_SELECTORS.get_screen_shake_intensity(state), 0.5, 0.001,
		"Apply should persist shake intensity")
	assert_false(U_VFX_SELECTORS.is_damage_flash_enabled(state), "Apply should persist flash enabled=false")
	assert_false(U_VFX_SELECTORS.is_particles_enabled(state), "Apply should persist particles enabled=false")

	var vfx_actions := _collect_vfx_action_types(dispatched)
	assert_true(vfx_actions.has(U_VFX_ACTIONS.ACTION_SET_SCREEN_SHAKE_ENABLED), "Apply should dispatch set_screen_shake_enabled")
	assert_true(vfx_actions.has(U_VFX_ACTIONS.ACTION_SET_SCREEN_SHAKE_INTENSITY), "Apply should dispatch set_screen_shake_intensity")
	assert_true(vfx_actions.has(U_VFX_ACTIONS.ACTION_SET_DAMAGE_FLASH_ENABLED), "Apply should dispatch set_damage_flash_enabled")
	assert_true(vfx_actions.has(U_VFX_ACTIONS.ACTION_SET_PARTICLES_ENABLED), "Apply should dispatch set_particles_enabled")


func test_cancel_discards_changes() -> void:
	var overlay := await _instantiate_overlay()

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	overlay._shake_enabled_toggle.button_pressed = false
	overlay._intensity_slider.value = 0.5
	overlay._flash_enabled_toggle.button_pressed = false
	overlay._particles_enabled_toggle.button_pressed = false

	overlay._cancel_button.emit_signal("pressed")
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_true(U_VFX_SELECTORS.is_screen_shake_enabled(state), "Cancel should not persist shake enabled edits")
	assert_almost_eq(U_VFX_SELECTORS.get_screen_shake_intensity(state), 1.0, 0.001,
		"Cancel should not persist intensity edits")
	assert_true(U_VFX_SELECTORS.is_damage_flash_enabled(state), "Cancel should not persist flash enabled edits")
	assert_true(U_VFX_SELECTORS.is_particles_enabled(state), "Cancel should not persist particles enabled edits")

	assert_eq(_collect_vfx_action_types(dispatched).size(), 0, "Cancel should not dispatch VFX actions")


func test_reset_restores_defaults_and_persists_immediately() -> void:
	# Start from non-default state
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_enabled(false))
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(0.5))
	_store.dispatch(U_VFX_ACTIONS.set_damage_flash_enabled(false))
	_store.dispatch(U_VFX_ACTIONS.set_particles_enabled(false))

	var overlay := await _instantiate_overlay()

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	overlay._reset_button.emit_signal("pressed")
	await get_tree().process_frame

	# Reset updates UI immediately and persists to state (matches overlay behavior).
	assert_true(overlay._shake_enabled_toggle.button_pressed, "Reset should set shake enabled to default (true)")
	assert_almost_eq(overlay._intensity_slider.value, 1.0, 0.001, "Reset should set intensity to default (1.0)")
	assert_true(overlay._flash_enabled_toggle.button_pressed, "Reset should set flash enabled to default (true)")
	assert_true(overlay._particles_enabled_toggle.button_pressed, "Reset should set particles enabled to default (true)")
	assert_eq(_collect_vfx_action_types(dispatched).size(), 4, "Reset should dispatch VFX actions immediately")

	var state_after_reset: Dictionary = _store.get_state()
	assert_true(U_VFX_SELECTORS.is_screen_shake_enabled(state_after_reset), "Reset should persist shake enabled")
	assert_almost_eq(U_VFX_SELECTORS.get_screen_shake_intensity(state_after_reset), 1.0, 0.001,
		"Reset should persist intensity")
	assert_true(U_VFX_SELECTORS.is_damage_flash_enabled(state_after_reset), "Reset should persist flash enabled")
	assert_true(U_VFX_SELECTORS.is_particles_enabled(state_after_reset), "Reset should persist particles enabled")


func test_state_changes_refresh_ui_when_not_editing() -> void:
	var overlay := await _instantiate_overlay()

	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(1.7))
	await get_tree().process_frame

	assert_almost_eq(overlay._intensity_slider.value, 1.7, 0.001,
		"Overlay should update intensity slider from store when not editing")
	assert_eq(overlay._intensity_percentage.text, "170%", "Overlay should update percentage label from store")


func test_state_changes_do_not_override_local_edits() -> void:
	var overlay := await _instantiate_overlay()

	overlay._intensity_slider.value = 0.5
	await get_tree().process_frame

	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(1.8))
	await get_tree().process_frame

	assert_almost_eq(overlay._intensity_slider.value, 0.5, 0.001,
		"Overlay should not override local edits when state changes while editing")


func test_settings_persist_and_restore_from_save_file() -> void:
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_enabled(false))
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(0.6))
	_store.dispatch(U_VFX_ACTIONS.set_damage_flash_enabled(false))
	_store.dispatch(U_VFX_ACTIONS.set_particles_enabled(false))

	var save_err := _store.save_state(TEST_SAVE_PATH)
	assert_eq(save_err, OK, "save_state should succeed")
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "save_state should create a file")

	# Create a new store instance and load from file.
	var store_2 := _create_state_store()
	add_child_autofree(store_2)
	await get_tree().process_frame

	U_SERVICE_LOCATOR.clear()
	U_SERVICE_LOCATOR.register(StringName("state_store"), store_2)

	var load_err := store_2.load_state(TEST_SAVE_PATH)
	assert_eq(load_err, OK, "load_state should succeed")

	var loaded_state: Dictionary = store_2.get_state()
	assert_false(U_VFX_SELECTORS.is_screen_shake_enabled(loaded_state), "Loaded state should restore shake enabled")
	assert_almost_eq(U_VFX_SELECTORS.get_screen_shake_intensity(loaded_state), 0.6, 0.001,
		"Loaded state should restore shake intensity")
	assert_false(U_VFX_SELECTORS.is_damage_flash_enabled(loaded_state), "Loaded state should restore flash enabled")
	assert_false(U_VFX_SELECTORS.is_particles_enabled(loaded_state), "Loaded state should restore particles enabled")

	var overlay := VFX_SETTINGS_OVERLAY_SCENE.instantiate() as UI_VFXSettingsOverlay
	add_child_autofree(overlay)
	await _await_overlay_store_ready(overlay)

	assert_false(overlay._shake_enabled_toggle.button_pressed, "Overlay should initialize from loaded shake enabled")
	assert_almost_eq(overlay._intensity_slider.value, 0.6, 0.001, "Overlay should initialize from loaded intensity")
	assert_false(overlay._flash_enabled_toggle.button_pressed, "Overlay should initialize from loaded flash enabled")
	assert_false(overlay._particles_enabled_toggle.button_pressed, "Overlay should initialize from loaded particles enabled")
