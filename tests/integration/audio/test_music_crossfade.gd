extends BaseTest

## Music crossfade integration tests (Phase 9.3)
##
## Focuses on M_AudioManager's dual-player crossfade behavior and
## music switching triggers from Redux actions.

const M_AUDIO_MANAGER := preload("res://scripts/managers/m_audio_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/state/resources/rs_audio_initial_state.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")

const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_TRANSITION_TEST_HELPERS := preload("res://tests/helpers/u_transition_test_helpers.gd")
const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")

const STREAM_MAIN_MENU := preload("res://resources/audio/music/main_menu.mp3")
const STREAM_EXTERIOR := preload("res://resources/audio/music/exterior.mp3")
const STREAM_INTERIOR := preload("res://resources/audio/music/interior.mp3")
const STREAM_PAUSE := preload("res://resources/audio/music/pause.mp3")

var _store: M_StateStore
var _audio_manager: M_AudioManager


func before_each() -> void:
	get_tree().paused = false
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


func after_each() -> void:
	get_tree().paused = false
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


func _player_a() -> AudioStreamPlayer:
	return _audio_manager.get_node_or_null("MusicPlayerA") as AudioStreamPlayer


func _player_b() -> AudioStreamPlayer:
	return _audio_manager.get_node_or_null("MusicPlayerB") as AudioStreamPlayer


func _is_playing_stream(stream: AudioStream) -> bool:
	var a := _player_a()
	var b := _player_b()
	if a != null and a.playing and a.stream == stream:
		return true
	if b != null and b.playing and b.stream == stream:
		return true
	return false


func _await_music_tween(timeout_sec: float = 1.0) -> bool:
	var tween := _audio_manager._music_tween
	return await U_TRANSITION_TEST_HELPERS.await_tween_or_timeout(tween, get_tree(), timeout_sec)


func test_music_players_exist_and_use_music_bus() -> void:
	assert_not_null(_player_a())
	assert_not_null(_player_b())
	assert_eq(_player_a().bus, "Music")
	assert_eq(_player_b().bus, "Music")


func test_active_music_player_initially_player_a() -> void:
	assert_eq(_audio_manager._active_music_player, _player_a())
	assert_eq(_audio_manager._inactive_music_player, _player_b())


func test_play_music_swaps_active_to_player_b() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await get_tree().process_frame
	assert_eq(_audio_manager._active_music_player, _player_b())


func test_second_play_music_swaps_active_back_to_player_a() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)
	_audio_manager.play_music(StringName("exterior"), 0.01)
	await get_tree().process_frame
	assert_eq(_audio_manager._active_music_player, _player_a())


func test_play_music_sets_current_music_id() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await get_tree().process_frame
	assert_eq(_audio_manager._current_music_id, StringName("main_menu"))


func test_play_music_same_track_is_noop() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)

	var tween_before := _audio_manager._music_tween
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await get_tree().process_frame

	assert_eq(_audio_manager._music_tween, tween_before, "Replaying same track should not restart tween")


func test_play_music_unknown_track_warns_and_does_not_change_current_id() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)

	var current_before := _audio_manager._current_music_id
	_audio_manager.play_music(StringName("unknown_track"), 0.01)
	assert_engine_error("Unknown music track")
	assert_eq(_audio_manager._current_music_id, current_before)


func test_new_player_starts_at_minus_80_db() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.2)
	assert_almost_eq(_audio_manager._active_music_player.volume_db, -80.0, 0.001)


func test_new_player_fades_in_to_zero_db() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	var completed := await _await_music_tween(0.5)
	assert_true(completed, "Tween should complete quickly")
	assert_almost_eq(_audio_manager._active_music_player.volume_db, 0.0, 0.1)


func test_old_player_stops_after_crossfade() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)
	var old_player := _audio_manager._active_music_player

	_audio_manager.play_music(StringName("exterior"), 0.05)
	await get_tree().process_frame
	assert_true(old_player.playing, "Old player should still be playing during fade")

	var completed := await _await_music_tween(1.0)
	assert_true(completed, "Crossfade tween should complete")
	assert_false(old_player.playing, "Old player should stop after fade out")


func test_crossfade_when_old_not_playing_only_fades_in_new() -> void:
	# First call starts from silence; old_player not playing.
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await get_tree().process_frame

	var inactive := _audio_manager._inactive_music_player
	assert_false(inactive.playing, "Old/inactive player should not start playing when previously silent")


func test_negative_duration_clamps_to_zero() -> void:
	_audio_manager.play_music(StringName("main_menu"), -1.0)
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_MAIN_MENU))
	assert_almost_eq(_audio_manager._active_music_player.volume_db, 0.0, 0.1)


func test_duration_zero_crossfade_completes_immediately() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.0)
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_MAIN_MENU))
	assert_almost_eq(_audio_manager._active_music_player.volume_db, 0.0, 0.1)


func test_retrigger_kills_previous_tween_and_starts_new_one() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.5)
	await get_tree().process_frame
	var tween_1 := _audio_manager._music_tween
	assert_not_null(tween_1)

	_audio_manager.play_music(StringName("exterior"), 0.5)
	await get_tree().process_frame
	var tween_2 := _audio_manager._music_tween
	assert_not_null(tween_2)
	assert_ne(tween_1, tween_2, "Retrigger should replace the tween")


func test_crossfade_keeps_old_playing_until_tween_finishes() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)
	var old_player := _audio_manager._active_music_player

	_audio_manager.play_music(StringName("exterior"), 0.2)
	await get_tree().process_frame
	assert_true(old_player.playing)

	await get_tree().create_timer(0.05).timeout
	assert_true(old_player.playing, "Old player should still be playing mid-fade")

func test_crossfade_fades_out_old_player_volume_mid_fade() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)
	var old_player := _audio_manager._active_music_player
	assert_almost_eq(old_player.volume_db, 0.0, 0.1)

	_audio_manager.play_music(StringName("exterior"), 0.4)
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout

	assert_lt(old_player.volume_db, 0.0, "Old player volume_db should decrease during fade-out")


func test_cubic_ease_in_out_is_not_linear_at_quarter_time() -> void:
	# Avoid tight wall-clock assumptions; under load, timers can overshoot.
	# Use a longer duration and sample early to distinguish cubic ease-in from linear.
	_audio_manager.play_music(StringName("main_menu"), 2.0)
	await get_tree().process_frame
	var new_player := _audio_manager._active_music_player

	await get_tree().create_timer(0.1).timeout
	assert_lt(new_player.volume_db, -76.5, "Cubic ease-in should still be quieter than linear early in the fade")


func test_cubic_ease_in_out_is_near_full_volume_at_three_quarter_time() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.4)
	await get_tree().process_frame
	var new_player := _audio_manager._active_music_player

	await get_tree().create_timer(0.3).timeout
	assert_gt(new_player.volume_db, -15.0, "Cubic ease-out should be near full volume at 3/4 time")


func test_scene_transition_completed_triggers_music_for_scene() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_MAIN_MENU))

func test_scene_transition_to_interior_house_plays_interior_music() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("interior_house")))
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_INTERIOR))


func test_transition_to_unknown_scene_does_not_stop_current_music() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_MAIN_MENU))

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("unknown_scene")))
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_MAIN_MENU), "Unknown scene should not stop currently playing music")


func test_open_pause_stores_pre_pause_music_id() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("exterior")))
	await get_tree().process_frame

	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_eq(_audio_manager._pre_pause_music_id, StringName("exterior"))


func test_open_pause_switches_to_pause_track() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("exterior")))
	await get_tree().process_frame

	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_PAUSE))


func test_close_pause_restores_pre_pause_track() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("exterior")))
	await get_tree().process_frame
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame

	_store.dispatch(U_NAVIGATION_ACTIONS.close_pause())
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_EXTERIOR))


func test_close_pause_stops_pause_music_if_no_pre_pause_track() -> void:
	# No scene music yet; open pause should still start pause music.
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_PAUSE))
	assert_eq(_audio_manager._pre_pause_music_id, StringName(""))

	_store.dispatch(U_NAVIGATION_ACTIONS.close_pause())
	await get_tree().process_frame
	assert_eq(_audio_manager._current_music_id, StringName(""))

	# close_pause should fade out and then stop pause music when there is no return track.
	var completed := await _await_music_tween(1.5)
	assert_true(completed, "Stop tween should complete")
	assert_false(_is_playing_stream(STREAM_PAUSE))


func test_scene_change_while_paused_updates_return_track_only() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("exterior")))
	await get_tree().process_frame
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_PAUSE))

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("interior_house")))
	await get_tree().process_frame
	assert_true(_is_playing_stream(STREAM_PAUSE), "Pause music should keep playing while paused")
	assert_eq(_audio_manager._pre_pause_music_id, StringName("interior"))


func test_transition_to_main_menu_clears_pre_pause_state() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("exterior")))
	await get_tree().process_frame
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_eq(_audio_manager._pre_pause_music_id, StringName("exterior"))

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame
	assert_eq(_audio_manager._pre_pause_music_id, StringName(""), "Main menu should clear paused return state")


func test_stop_music_clears_current_music_id() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)

	_audio_manager._stop_music(0.01)
	await get_tree().process_frame
	assert_eq(_audio_manager._current_music_id, StringName(""))


func test_stop_music_fades_out_active_player() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)
	var player := _audio_manager._active_music_player
	assert_true(player.playing)

	_audio_manager._stop_music(0.05)
	# Do not assume a per-frame delta smaller than the fade duration; just ensure the stop isn't synchronous.
	assert_true(player.playing, "Player should not stop immediately when fade duration > 0")
	assert_not_null(_audio_manager._music_tween, "Stop should create a tween for fade-out")


func test_stop_music_stops_player_after_fade() -> void:
	_audio_manager.play_music(StringName("main_menu"), 0.01)
	await _await_music_tween(0.5)
	var player := _audio_manager._active_music_player

	_audio_manager._stop_music(0.01)
	var completed := await _await_music_tween(0.5)
	assert_true(completed)
	assert_false(player.playing, "Player should stop after stop tween completes")
