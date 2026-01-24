extends BaseTest

## Integration tests for Audio settings UI (Phase 9.1)
##
## Validates:
## - UI initializes from Redux state
## - UI edits do not dispatch until Apply (Apply/Cancel pattern)
## - Reset applies defaults immediately
## - Settings persist to audio settings file and restore across sessions

const M_AUDIO_MANAGER := preload("res://scripts/managers/m_audio_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/resources/state/rs_audio_initial_state.gd")

const U_AUDIO_ACTIONS := preload("res://scripts/state/actions/u_audio_actions.gd")
const U_AUDIO_SELECTORS := preload("res://scripts/state/selectors/u_audio_selectors.gd")
const U_AUDIO_SERIALIZATION := preload("res://scripts/utils/u_audio_serialization.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")

const AUDIO_SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/ui_audio_settings_overlay.tscn")

const AUDIO_SETTINGS_PATH := U_AUDIO_SERIALIZATION.SAVE_PATH
const AUDIO_SETTINGS_BACKUP_PATH := U_AUDIO_SERIALIZATION.BACKUP_PATH

var _store: M_StateStore
var _audio_manager: M_AudioManager


func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	await get_tree().process_frame

	_store = _create_state_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_audio_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_audio_manager)

	await get_tree().process_frame
	_remove_test_settings_files()


func after_each() -> void:
	_remove_test_settings_files()
	U_STATE_HANDOFF.clear_all()
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	super.after_each()


func _create_state_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.audio_initial_state = RS_AUDIO_INITIAL_STATE.new()
	return store


func _instantiate_overlay() -> UI_AudioSettingsOverlay:
	var overlay := AUDIO_SETTINGS_OVERLAY_SCENE.instantiate() as UI_AudioSettingsOverlay
	add_child_autofree(overlay)
	await _await_overlay_store_ready(overlay)
	return overlay


func _await_overlay_store_ready(overlay: UI_AudioSettingsOverlay, max_frames: int = 30) -> void:
	for _i in range(max_frames):
		await get_tree().process_frame
		if overlay != null and overlay.get_store() != null:
			return


func _get_tab(overlay: Node) -> UI_AudioSettingsTab:
	return overlay.get_node_or_null("CenterContainer/Panel/VBox/AudioSettingsTab") as UI_AudioSettingsTab


func _remove_test_settings_files() -> void:
	U_AUDIO_TEST_HELPERS.remove_test_file(AUDIO_SETTINGS_PATH)
	U_AUDIO_TEST_HELPERS.remove_test_file(AUDIO_SETTINGS_BACKUP_PATH)

func _collect_audio_action_types(actions: Array[Dictionary]) -> Array[StringName]:
	var types: Array[StringName] = []
	for action in actions:
		var action_type: Variant = action.get("type", StringName(""))
		if action_type is StringName and String(action_type).begins_with("audio/"):
			types.append(action_type)
	return types


func test_controls_initialize_from_redux_state() -> void:
	_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(0.7))
	_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(0.6))
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_volume(0.5))
	_store.dispatch(U_AUDIO_ACTIONS.set_ambient_volume(0.4))
	_store.dispatch(U_AUDIO_ACTIONS.set_master_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_muted(false))
	_store.dispatch(U_AUDIO_ACTIONS.set_ambient_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_spatial_audio_enabled(false))

	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "AudioSettingsTab should exist")

	assert_almost_eq(tab._master_volume_slider.value, 0.7, 0.001, "Master slider should init from state")
	assert_almost_eq(tab._music_volume_slider.value, 0.6, 0.001, "Music slider should init from state")
	assert_almost_eq(tab._sfx_volume_slider.value, 0.5, 0.001, "SFX slider should init from state")
	assert_almost_eq(tab._ambient_volume_slider.value, 0.4, 0.001, "Ambient slider should init from state")

	assert_true(tab._master_mute_toggle.button_pressed, "Master mute should init from state")
	assert_true(tab._music_mute_toggle.button_pressed, "Music mute should init from state")
	assert_false(tab._sfx_mute_toggle.button_pressed, "SFX mute should init from state")
	assert_true(tab._ambient_mute_toggle.button_pressed, "Ambient mute should init from state")

	assert_false(tab._spatial_audio_toggle.button_pressed, "Spatial audio should init from state")

func test_changes_do_not_dispatch_until_apply() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._spatial_audio_toggle.button_pressed = false
	tab._ambient_mute_toggle.button_pressed = true
	tab._music_volume_slider.value = 0.2
	await get_tree().process_frame

	assert_eq(_collect_audio_action_types(dispatched).size(), 0,
		"Changing controls should not dispatch audio actions until Apply")


func test_apply_dispatches_actions_and_updates_state() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._master_volume_slider.value = 0.7
	tab._music_volume_slider.value = 0.6
	tab._sfx_volume_slider.value = 0.5
	tab._ambient_volume_slider.value = 0.4
	tab._master_mute_toggle.button_pressed = true
	tab._music_mute_toggle.button_pressed = true
	tab._sfx_mute_toggle.button_pressed = false
	tab._ambient_mute_toggle.button_pressed = true
	tab._spatial_audio_toggle.button_pressed = false
	await get_tree().process_frame

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_eq(_collect_audio_action_types(dispatched).size(), 9, "Apply should dispatch all audio settings actions")

	var state: Dictionary = _store.get_state()
	assert_almost_eq(U_AUDIO_SELECTORS.get_master_volume(state), 0.7, 0.001)
	assert_almost_eq(U_AUDIO_SELECTORS.get_music_volume(state), 0.6, 0.001)
	assert_almost_eq(U_AUDIO_SELECTORS.get_sfx_volume(state), 0.5, 0.001)
	assert_almost_eq(U_AUDIO_SELECTORS.get_ambient_volume(state), 0.4, 0.001)
	assert_true(U_AUDIO_SELECTORS.is_master_muted(state))
	assert_true(U_AUDIO_SELECTORS.is_music_muted(state))
	assert_false(U_AUDIO_SELECTORS.is_sfx_muted(state))
	assert_true(U_AUDIO_SELECTORS.is_ambient_muted(state))
	assert_false(U_AUDIO_SELECTORS.is_spatial_audio_enabled(state))


func test_cancel_discards_changes() -> void:
	_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(0.9))

	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	tab._music_volume_slider.value = 0.2
	await get_tree().process_frame

	tab._cancel_button.emit_signal("pressed")
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_almost_eq(U_AUDIO_SELECTORS.get_music_volume(state), 0.9, 0.001, "Cancel should not persist edits")


func test_reset_restores_defaults_and_persists_immediately() -> void:
	_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(0.2))
	_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(0.3))
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_volume(0.4))
	_store.dispatch(U_AUDIO_ACTIONS.set_ambient_volume(0.5))
	_store.dispatch(U_AUDIO_ACTIONS.set_master_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_ambient_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_spatial_audio_enabled(false))

	var defaults := RS_AUDIO_INITIAL_STATE.new()

	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._reset_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_eq(_collect_audio_action_types(dispatched).size(), 9, "Reset should dispatch all audio settings actions")

	assert_almost_eq(tab._master_volume_slider.value, defaults.master_volume, 0.001)
	assert_almost_eq(tab._music_volume_slider.value, defaults.music_volume, 0.001)
	assert_almost_eq(tab._sfx_volume_slider.value, defaults.sfx_volume, 0.001)
	assert_almost_eq(tab._ambient_volume_slider.value, defaults.ambient_volume, 0.001)
	assert_eq(tab._master_mute_toggle.button_pressed, defaults.master_muted)
	assert_eq(tab._music_mute_toggle.button_pressed, defaults.music_muted)
	assert_eq(tab._sfx_mute_toggle.button_pressed, defaults.sfx_muted)
	assert_eq(tab._ambient_mute_toggle.button_pressed, defaults.ambient_muted)
	assert_eq(tab._spatial_audio_toggle.button_pressed, defaults.spatial_audio_enabled)

	var state: Dictionary = _store.get_state()
	assert_almost_eq(U_AUDIO_SELECTORS.get_master_volume(state), defaults.master_volume, 0.001)
	assert_almost_eq(U_AUDIO_SELECTORS.get_music_volume(state), defaults.music_volume, 0.001)
	assert_almost_eq(U_AUDIO_SELECTORS.get_sfx_volume(state), defaults.sfx_volume, 0.001)
	assert_almost_eq(U_AUDIO_SELECTORS.get_ambient_volume(state), defaults.ambient_volume, 0.001)
	assert_eq(U_AUDIO_SELECTORS.is_master_muted(state), defaults.master_muted)
	assert_eq(U_AUDIO_SELECTORS.is_music_muted(state), defaults.music_muted)
	assert_eq(U_AUDIO_SELECTORS.is_sfx_muted(state), defaults.sfx_muted)
	assert_eq(U_AUDIO_SELECTORS.is_ambient_muted(state), defaults.ambient_muted)
	assert_eq(U_AUDIO_SELECTORS.is_spatial_audio_enabled(state), defaults.spatial_audio_enabled)


func test_state_changes_refresh_ui_when_not_editing() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(0.65))
	await get_tree().process_frame
	assert_almost_eq(tab._music_volume_slider.value, 0.65, 0.001)


func test_state_changes_do_not_override_local_edits() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	tab._master_volume_slider.value = 0.25
	await get_tree().process_frame

	_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(0.9))
	await get_tree().process_frame

	assert_almost_eq(tab._master_volume_slider.value, 0.25, 0.001,
		"Overlay should not override local edits when state changes while editing")


func test_master_slider_applies_on_apply() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	tab._master_volume_slider.value = 0.33
	await get_tree().process_frame
	var expected := tab._master_volume_slider.value
	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_almost_eq(U_AUDIO_SELECTORS.get_master_volume(state), expected, 0.001)


func test_spatial_audio_toggle_applies_on_apply() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	tab._spatial_audio_toggle.button_pressed = false
	await get_tree().process_frame
	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_false(U_AUDIO_SELECTORS.is_spatial_audio_enabled(state))


func test_settings_persist_and_restore_from_settings_file() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)

	tab._spatial_audio_toggle.button_pressed = false
	tab._ambient_mute_toggle.button_pressed = true
	tab._music_volume_slider.value = 0.2
	await get_tree().process_frame

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	var state_before_save: Dictionary = _store.get_state()
	assert_false(U_AUDIO_SELECTORS.is_spatial_audio_enabled(state_before_save), "State should update spatial audio")
	assert_true(U_AUDIO_SELECTORS.is_ambient_muted(state_before_save), "State should update ambient muted")
	assert_almost_eq(U_AUDIO_SELECTORS.get_music_volume(state_before_save), 0.2, 0.001, "State should update music volume")

	assert_true(FileAccess.file_exists(AUDIO_SETTINGS_PATH), "audio settings file should be created")

	# Load into a new store instance and ensure UI initializes from loaded state.
	var store_2 := _create_state_store()
	add_child_autofree(store_2)
	await get_tree().process_frame

	U_SERVICE_LOCATOR.clear()
	U_SERVICE_LOCATOR.register(StringName("state_store"), store_2)

	var audio_manager_2 := M_AUDIO_MANAGER.new()
	add_child_autofree(audio_manager_2)
	await get_tree().process_frame
	await get_tree().process_frame

	var loaded_state: Dictionary = store_2.get_state()
	assert_false(U_AUDIO_SELECTORS.is_spatial_audio_enabled(loaded_state), "Loaded state should restore spatial audio")
	assert_true(U_AUDIO_SELECTORS.is_ambient_muted(loaded_state), "Loaded state should restore ambient muted")
	assert_almost_eq(U_AUDIO_SELECTORS.get_music_volume(loaded_state), 0.2, 0.001, "Loaded state should restore music volume")

	var overlay_2 := AUDIO_SETTINGS_OVERLAY_SCENE.instantiate() as UI_AudioSettingsOverlay
	add_child_autofree(overlay_2)
	await _await_overlay_store_ready(overlay_2)

	var tab_2 := _get_tab(overlay_2)
	assert_not_null(tab_2, "AudioSettingsTab should exist after load")
	assert_false(tab_2._spatial_audio_toggle.button_pressed, "UI should init spatial audio from loaded state")
	assert_true(tab_2._ambient_mute_toggle.button_pressed, "UI should init ambient mute from loaded state")
	assert_almost_eq(tab_2._music_volume_slider.value, 0.2, 0.001, "UI should init music volume from loaded state")
