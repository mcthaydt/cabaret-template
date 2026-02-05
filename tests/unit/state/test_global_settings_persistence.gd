extends GutTest

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BOOT_INITIAL_STATE := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MENU_INITIAL_STATE := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const RS_SETTINGS_INITIAL_STATE := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_DEBUG_INITIAL_STATE := preload("res://scripts/resources/state/rs_debug_initial_state.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/resources/state/rs_audio_initial_state.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_display_initial_state.gd")

const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
const U_ACTION_REGISTRY := preload("res://scripts/state/utils/u_action_registry.gd")
const U_AUDIO_SELECTORS := preload("res://scripts/state/selectors/u_audio_selectors.gd")
const U_VFX_SELECTORS := preload("res://scripts/state/selectors/u_vfx_selectors.gd")
const U_INPUT_SELECTORS := preload("res://scripts/state/selectors/u_input_selectors.gd")

const U_GLOBAL_SETTINGS_SERIALIZATION := preload("res://scripts/utils/u_global_settings_serialization.gd")
const U_AUDIO_SERIALIZATION := preload("res://scripts/utils/u_audio_serialization.gd")
const U_INPUT_SERIALIZATION := preload("res://scripts/utils/input/u_input_serialization.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

const GLOBAL_SETTINGS_PATH := "user://global_settings.json"
const GLOBAL_SETTINGS_BACKUP := "user://global_settings.json.backup"
const LEGACY_AUDIO_PATH := "user://audio_settings.json"
const LEGACY_AUDIO_BACKUP := "user://audio_settings.json.backup"
const LEGACY_INPUT_PATH := "user://input_settings.json"
const LEGACY_INPUT_BACKUP := "user://input_settings.json.backup"

func before_each() -> void:
	_cleanup_settings_files()

func after_each() -> void:
	_cleanup_settings_files()

func test_global_settings_load_applies_to_store() -> void:
	var settings := {
		"display": {
			"window_mode": "fullscreen",
			"ui_scale": 1.2,
			"quality_preset": "ultra"
		},
		"audio": {
			"master_muted": true,
			"music_volume": 0.4
		},
		"vfx": {
			"screen_shake_enabled": false,
			"screen_shake_intensity": 0.4
		},
		"input_settings": {
			"active_profile_id": "default",
			"mouse_settings": {
				"sensitivity": 1.5
			}
		},
		"gameplay_preferences": {
			"show_landing_indicator": false,
			"particle_settings": {
				"jump_particles_enabled": false
			}
		}
	}

	var saved := U_GLOBAL_SETTINGS_SERIALIZATION.save_settings(settings)
	assert_true(saved, "Global settings save should succeed")

	var store := _create_state_store()
	add_child_autofree(store)
	if not store.is_ready():
		await store.store_ready

	var state := store.get_state()
	assert_eq(U_DISPLAY_SELECTORS.get_window_mode(state), "fullscreen", "Display window mode should load from global settings")
	assert_almost_eq(U_DISPLAY_SELECTORS.get_ui_scale(state), 1.2, 0.001, "UI scale should load from global settings")
	assert_true(U_AUDIO_SELECTORS.is_master_muted(state), "Audio mute should load from global settings")
	assert_almost_eq(U_AUDIO_SELECTORS.get_music_volume(state), 0.4, 0.001, "Audio volume should load from global settings")
	assert_false(U_VFX_SELECTORS.is_screen_shake_enabled(state), "VFX setting should load from global settings")
	assert_almost_eq(U_VFX_SELECTORS.get_screen_shake_intensity(state), 0.4, 0.001, "VFX intensity should load from global settings")

	var active_profile := U_INPUT_SELECTORS.get_active_profile_id(state)
	assert_eq(String(active_profile), "default", "Input profile should load from global settings")

	var gameplay: Dictionary = state.get("gameplay", {})
	assert_false(bool(gameplay.get("show_landing_indicator", true)), "Gameplay preference should load from global settings")
	var particle_settings: Dictionary = gameplay.get("particle_settings", {})
	assert_false(bool(particle_settings.get("jump_particles_enabled", true)), "Gameplay particle settings should load from global settings")

func test_global_settings_saved_on_display_action() -> void:
	var store := _create_state_store()
	add_child_autofree(store)
	if not store.is_ready():
		await store.store_ready

	assert_true(
		U_ACTION_REGISTRY.is_registered(U_DISPLAY_ACTIONS.ACTION_SET_WINDOW_MODE),
		"Display window mode action should be registered before dispatch"
	)
	assert_true(
		U_GLOBAL_SETTINGS_SERIALIZATION.is_global_settings_action(U_DISPLAY_ACTIONS.ACTION_SET_WINDOW_MODE),
		"Global settings should recognize display actions for persistence"
	)

	store.dispatch(U_DISPLAY_ACTIONS.set_window_mode("fullscreen"))
	await get_tree().process_frame
	await get_tree().process_frame

	var state := store.get_state()
	assert_eq(
		U_DISPLAY_SELECTORS.get_window_mode(state),
		"fullscreen",
		"Display slice should update when dispatching window mode action"
	)

	assert_true(FileAccess.file_exists(GLOBAL_SETTINGS_PATH), "Global settings file should be written after display action")
	var loaded := U_GLOBAL_SETTINGS_SERIALIZATION.load_settings()
	var display: Dictionary = loaded.get("display", {})
	assert_eq(String(display.get("window_mode", "")), "fullscreen", "Global settings should store display window mode")

func test_legacy_audio_and_input_settings_migrate() -> void:
	var audio_saved := U_AUDIO_SERIALIZATION.save_settings({"master_muted": true})
	var input_saved := U_INPUT_SERIALIZATION.save_settings({"active_profile_id": "default"})
	assert_true(audio_saved, "Legacy audio settings should save")
	assert_true(input_saved, "Legacy input settings should save")
	assert_true(FileAccess.file_exists(LEGACY_AUDIO_PATH), "Legacy audio file should exist")
	assert_true(FileAccess.file_exists(LEGACY_INPUT_PATH), "Legacy input file should exist")

	var store := _create_state_store()
	add_child_autofree(store)
	if not store.is_ready():
		await store.store_ready

	assert_true(FileAccess.file_exists(GLOBAL_SETTINGS_PATH), "Global settings file should be created after migration")
	var state := store.get_state()
	assert_true(U_AUDIO_SELECTORS.is_master_muted(state), "Migrated audio settings should apply to state")
	var active_profile := U_INPUT_SELECTORS.get_active_profile_id(state)
	assert_eq(String(active_profile), "default", "Migrated input settings should apply to state")

func _create_state_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_global_settings_persistence = true
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.boot_initial_state = RS_BOOT_INITIAL_STATE.new()
	store.menu_initial_state = RS_MENU_INITIAL_STATE.new()
	store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	store.settings_initial_state = RS_SETTINGS_INITIAL_STATE.new()
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.debug_initial_state = RS_DEBUG_INITIAL_STATE.new()
	store.vfx_initial_state = RS_VFX_INITIAL_STATE.new()
	store.audio_initial_state = RS_AUDIO_INITIAL_STATE.new()
	store.display_initial_state = RS_DISPLAY_INITIAL_STATE.new()
	return store

func _cleanup_settings_files() -> void:
	U_STATE_HANDOFF.clear_all()
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("global_settings.json"):
		dir.remove("global_settings.json")
	if dir.file_exists("global_settings.json.backup"):
		dir.remove("global_settings.json.backup")
	if dir.file_exists("audio_settings.json"):
		dir.remove("audio_settings.json")
	if dir.file_exists("audio_settings.json.backup"):
		dir.remove("audio_settings.json.backup")
	if dir.file_exists("input_settings.json"):
		dir.remove("input_settings.json")
	if dir.file_exists("input_settings.json.backup"):
		dir.remove("input_settings.json.backup")
