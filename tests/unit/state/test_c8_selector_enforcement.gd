extends GutTest

## C8: Selector Enforcement Tests
##
## Tests for new and modified selectors added during C8.
## Covers: U_GameplaySelectors (full-state variants), U_SceneSelectors (full-state variants),
## U_SettingsSelectors (new), U_AudioSelectors (slice accessor), U_DisplaySelectors (slice accessor),
## U_LocalizationSelectors (slice accessor), and any other selectors needed for manager migration.

const U_SETTINGS_SELECTORS := preload("res://scripts/state/selectors/u_settings_selectors.gd")
const U_AUDIO_SELECTORS := preload("res://scripts/state/selectors/u_audio_selectors.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")


# ── U_GameplaySelectors: full-state variants ───────────────────────────────

func test_gameplay_get_playtime_seconds_returns_value() -> void:
	var state := {"gameplay": {"paused": false, "playtime_seconds": 42, "entities": {}}}
	assert_eq(U_GameplaySelectors.get_playtime_seconds(state), 42, "Should return playtime_seconds from full state")

func test_gameplay_get_playtime_seconds_defaults_to_zero() -> void:
	var state := {"gameplay": {"paused": false, "entities": {}}}
	assert_eq(U_GameplaySelectors.get_playtime_seconds(state), 0, "Should default to 0 when missing")

func test_gameplay_get_playtime_seconds_handles_missing_slice() -> void:
	var state := {}
	assert_eq(U_GameplaySelectors.get_playtime_seconds(state), 0, "Should default to 0 when gameplay slice missing")

func test_gameplay_get_target_spawn_point_returns_value() -> void:
	var state := {"gameplay": {"target_spawn_point": StringName("spawn_01"), "entities": {}}}
	assert_eq(U_GameplaySelectors.get_target_spawn_point(state), StringName("spawn_01"), "Should return target_spawn_point from full state")

func test_gameplay_get_target_spawn_point_defaults_empty() -> void:
	var state := {"gameplay": {"entities": {}}}
	assert_eq(U_GameplaySelectors.get_target_spawn_point(state), StringName(""), "Should default to empty StringName when missing")

func test_gameplay_get_target_spawn_point_handles_missing_slice() -> void:
	var state := {}
	assert_eq(U_GameplaySelectors.get_target_spawn_point(state), StringName(""), "Should default to empty StringName when slice missing")

func test_gameplay_get_last_checkpoint_full_state() -> void:
	var state := {"gameplay": {"last_checkpoint": StringName("cp_arena"), "entities": {}}}
	assert_eq(U_GameplaySelectors.get_last_checkpoint(state), StringName("cp_arena"), "Should return last_checkpoint from full state")

func test_gameplay_get_last_checkpoint_defaults_empty() -> void:
	var state := {"gameplay": {"entities": {}}}
	assert_eq(U_GameplaySelectors.get_last_checkpoint(state), StringName(""), "Should default to empty StringName when missing")

func test_gameplay_get_last_checkpoint_handles_missing_slice() -> void:
	var state := {}
	assert_eq(U_GameplaySelectors.get_last_checkpoint(state), StringName(""), "Should default to empty StringName when slice missing")

func test_gameplay_get_is_paused_full_state() -> void:
	var state := {"gameplay": {"paused": true, "entities": {}}}
	assert_true(U_GameplaySelectors.get_is_paused(state), "Should return true when paused (full state)")

func test_gameplay_get_is_paused_defaults_false() -> void:
	var state := {"gameplay": {"entities": {}}}
	assert_false(U_GameplaySelectors.get_is_paused(state), "Should default to false when paused field missing")

func test_gameplay_is_death_in_progress_returns_true() -> void:
	var state := {"gameplay": {"death_in_progress": true, "entities": {}}}
	assert_true(U_GameplaySelectors.is_death_in_progress(state), "Should return true when death_in_progress")

func test_gameplay_is_death_in_progress_defaults_false() -> void:
	var state := {"gameplay": {"entities": {}}}
	assert_false(U_GameplaySelectors.is_death_in_progress(state), "Should default to false when missing")

func test_gameplay_is_death_in_progress_handles_missing_slice() -> void:
	var state := {}
	assert_false(U_GameplaySelectors.is_death_in_progress(state), "Should default to false when slice missing")

func test_gameplay_is_touch_look_active_full_state() -> void:
	var state := {"gameplay": {"touch_look_active": true, "entities": {}}}
	assert_true(U_GameplaySelectors.is_touch_look_active(state), "Should return true when touch_look_active (full state)")

func test_gameplay_is_touch_look_active_defaults_false() -> void:
	var state := {"gameplay": {"entities": {}}}
	assert_false(U_GameplaySelectors.is_touch_look_active(state), "Should default to false when missing")

func test_gameplay_get_ai_demo_flags_returns_value() -> void:
	var flags: Dictionary = {"flag_a": true}
	var state := {"gameplay": {"ai_demo_flags": flags, "entities": {}}}
	var result: Dictionary = U_GameplaySelectors.get_ai_demo_flags(state)
	assert_eq(result, flags, "Should return ai_demo_flags dict")

func test_gameplay_get_ai_demo_flags_defaults_empty() -> void:
	var state := {"gameplay": {"entities": {}}}
	var result: Dictionary = U_GameplaySelectors.get_ai_demo_flags(state)
	assert_eq(result, {}, "Should default to empty dict when missing")


# ── U_SceneSelectors: full-state variants ──────────────────────────────────

func test_scene_get_current_scene_id_returns_value() -> void:
	var state := {"scene": {"current_scene_id": StringName("level_01"), "is_transitioning": false, "scene_stack": []}}
	assert_eq(U_SceneSelectors.get_current_scene_id(state), StringName("level_01"), "Should return current_scene_id from full state")

func test_scene_get_current_scene_id_defaults_empty() -> void:
	var state := {"scene": {"is_transitioning": false, "scene_stack": []}}
	assert_eq(U_SceneSelectors.get_current_scene_id(state), StringName(""), "Should default to empty StringName when missing")

func test_scene_get_current_scene_id_handles_missing_slice() -> void:
	var state := {}
	assert_eq(U_SceneSelectors.get_current_scene_id(state), StringName(""), "Should default to empty StringName when slice missing")

func test_scene_get_previous_scene_id_returns_value() -> void:
	var state := {"scene": {"current_scene_id": StringName("level_02"), "previous_scene_id": StringName("level_01"), "is_transitioning": false, "scene_stack": []}}
	assert_eq(U_SceneSelectors.get_previous_scene_id(state), StringName("level_01"), "Should return previous_scene_id from full state")

func test_scene_get_previous_scene_id_defaults_empty() -> void:
	var state := {"scene": {"current_scene_id": StringName("level_01"), "is_transitioning": false, "scene_stack": []}}
	assert_eq(U_SceneSelectors.get_previous_scene_id(state), StringName(""), "Should default to empty StringName when missing")

func test_scene_is_transitioning_full_state() -> void:
	var state := {"scene": {"is_transitioning": true, "scene_stack": []}}
	assert_true(U_SceneSelectors.is_transitioning(state), "Should return true when transitioning (full state)")

func test_scene_is_transitioning_defaults_false() -> void:
	var state := {"scene": {"scene_stack": []}}
	assert_false(U_SceneSelectors.is_transitioning(state), "Should default to false when missing")

func test_scene_get_scene_stack_full_state() -> void:
	var stack: Array = [StringName("overlay_1")]
	var state := {"scene": {"is_transitioning": false, "scene_stack": stack}}
	var result: Array = U_SceneSelectors.get_scene_stack(state)
	assert_eq(result.size(), 1, "Should return scene_stack from full state")

func test_scene_get_scene_stack_defaults_empty() -> void:
	var state := {"scene": {"is_transitioning": false}}
	var result: Array = U_SceneSelectors.get_scene_stack(state)
	assert_eq(result.size(), 0, "Should default to empty array when missing")

func test_scene_get_scene_stack_handles_missing_slice() -> void:
	var state := {}
	var result: Array = U_SceneSelectors.get_scene_stack(state)
	assert_eq(result.size(), 0, "Should default to empty array when slice missing")


# ── U_SettingsSelectors ────────────────────────────────────────────────────

func test_settings_get_active_profile_id_returns_value() -> void:
	var state := {"settings": {"input_settings": {"active_profile_id": "custom_1"}}}
	assert_eq(U_SETTINGS_SELECTORS.get_active_profile_id(state), "custom_1", "Should return active_profile_id")

func test_settings_get_active_profile_id_defaults() -> void:
	var state := {"settings": {"input_settings": {}}}
	assert_eq(U_SETTINGS_SELECTORS.get_active_profile_id(state), "default", "Should default to 'default'")

func test_settings_get_active_profile_id_handles_missing_slice() -> void:
	var state := {}
	assert_eq(U_SETTINGS_SELECTORS.get_active_profile_id(state), "default", "Should default to 'default' when slice missing")

func test_settings_get_input_settings_returns_dict() -> void:
	var input_settings: Dictionary = {"active_profile_id": "profile_a", "gamepad_settings": {}}
	var state := {"settings": {"input_settings": input_settings}}
	var result: Dictionary = U_SETTINGS_SELECTORS.get_input_settings(state)
	assert_eq(result.get("active_profile_id", ""), "profile_a", "Should return input_settings dict")

func test_settings_get_input_settings_defaults_empty() -> void:
	var state := {"settings": {}}
	var result: Dictionary = U_SETTINGS_SELECTORS.get_input_settings(state)
	assert_eq(result, {}, "Should default to empty dict when input_settings missing")

func test_settings_get_input_settings_handles_missing_settings() -> void:
	var state := {}
	var result: Dictionary = U_SETTINGS_SELECTORS.get_input_settings(state)
	assert_eq(result, {}, "Should default to empty dict when settings missing")

func test_settings_get_gamepad_settings_returns_value() -> void:
	var gamepad: Dictionary = {"sensitivity": 0.5}
	var state := {"settings": {"input_settings": {"gamepad_settings": gamepad}}}
	var result: Dictionary = U_SETTINGS_SELECTORS.get_gamepad_settings(state)
	assert_eq(result.get("sensitivity", 0.0), 0.5, "Should return gamepad_settings dict")

func test_settings_get_gamepad_settings_defaults_empty() -> void:
	var state := {"settings": {"input_settings": {}}}
	var result: Dictionary = U_SETTINGS_SELECTORS.get_gamepad_settings(state)
	assert_eq(result, {}, "Should default to empty dict when missing")

func test_settings_get_mouse_settings_returns_value() -> void:
	var mouse: Dictionary = {"sensitivity": 1.2}
	var state := {"settings": {"input_settings": {"mouse_settings": mouse}}}
	var result: Dictionary = U_SETTINGS_SELECTORS.get_mouse_settings(state)
	assert_eq(result.get("sensitivity", 0.0), 1.2, "Should return mouse_settings dict")

func test_settings_get_mouse_settings_defaults_empty() -> void:
	var state := {"settings": {"input_settings": {}}}
	var result: Dictionary = U_SETTINGS_SELECTORS.get_mouse_settings(state)
	assert_eq(result, {}, "Should default to empty dict when missing")


# ── U_AudioSelectors: get_audio_settings ────────────────────────────────────

func test_audio_get_audio_settings_returns_slice() -> void:
	var audio_slice: Dictionary = {"master_volume": 0.8, "music_muted": true}
	var state := {"audio": audio_slice}
	var result: Dictionary = U_AUDIO_SELECTORS.get_audio_settings(state)
	assert_eq(result.get("master_volume", 0.0), 0.8, "Should return audio slice with values")
	assert_eq(result.get("music_muted", false), true, "Should return audio slice with muted flag")

func test_audio_get_audio_settings_defaults_empty() -> void:
	var state := {}
	var result: Dictionary = U_AUDIO_SELECTORS.get_audio_settings(state)
	assert_eq(result, {}, "Should default to empty dict when audio slice missing")

func test_audio_get_audio_settings_handles_null() -> void:
	var result: Dictionary = U_AUDIO_SELECTORS.get_audio_settings({})
	assert_eq(result, {}, "Should return empty dict for empty state")


# ── U_DisplaySelectors: get_display_settings ────────────────────────────────

func test_display_get_display_settings_returns_slice() -> void:
	var display_slice: Dictionary = {"window_mode": "fullscreen", "vsync_enabled": false}
	var state := {"display": display_slice}
	var result: Dictionary = U_DISPLAY_SELECTORS.get_display_settings(state)
	assert_eq(result.get("window_mode", ""), "fullscreen", "Should return display slice with values")
	assert_eq(result.get("vsync_enabled", true), false, "Should return display slice with vsync flag")

func test_display_get_display_settings_defaults_empty() -> void:
	var state := {}
	var result: Dictionary = U_DISPLAY_SELECTORS.get_display_settings(state)
	assert_eq(result, {}, "Should default to empty dict when display slice missing")

func test_display_get_display_settings_handles_null() -> void:
	var result: Dictionary = U_DISPLAY_SELECTORS.get_display_settings({})
	assert_eq(result, {}, "Should return empty dict for empty state")


# ── U_LocalizationSelectors: get_localization_settings ──────────────────────

func test_localization_get_localization_settings_returns_slice() -> void:
	var loc_slice: Dictionary = {"current_locale": StringName("fr"), "dyslexia_font_enabled": true}
	var state := {"localization": loc_slice}
	var result: Dictionary = U_LOCALIZATION_SELECTORS.get_localization_settings(state)
	assert_eq(result.get("current_locale", ""), StringName("fr"), "Should return localization slice with locale")
	assert_eq(result.get("dyslexia_font_enabled", false), true, "Should return localization slice with dyslexia flag")

func test_localization_get_localization_settings_defaults_empty() -> void:
	var state := {}
	var result: Dictionary = U_LOCALIZATION_SELECTORS.get_localization_settings(state)
	assert_eq(result, {}, "Should default to empty dict when localization slice missing")

func test_localization_get_localization_settings_handles_null() -> void:
	var result: Dictionary = U_LOCALIZATION_SELECTORS.get_localization_settings({})
	assert_eq(result, {}, "Should return empty dict for empty state")
