extends GutTest

## Unit tests for U_UISoundPlayer throttle behavior
##
## Verifies that per-sound throttles prevent rapid repeated plays
## based on the throttle_ms setting in RS_UISoundDefinition.

const U_UI_SOUND_PLAYER := preload("res://scripts/ui/utils/u_ui_sound_player.gd")
const M_AUDIO_MANAGER := preload("res://scripts/managers/m_audio_manager.gd")
const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")
const U_AUDIO_REGISTRY_LOADER := preload("res://scripts/managers/helpers/u_audio_registry_loader.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _manager: M_AUDIO_MANAGER


func before_each() -> void:
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame
	U_UI_SOUND_PLAYER.reset_throttles()


func test_throttle_ms_blocks_rapid_plays() -> void:
	# Given: UI sound with throttle_ms = 100 (ui_tick)
	var sound_def := U_AUDIO_REGISTRY_LOADER.get_ui_sound(StringName("ui_tick"))
	assert_not_null(sound_def, "ui_tick should exist")
	assert_eq(sound_def.throttle_ms, 100, "ui_tick should have 100ms throttle")

	# When: Playing twice within throttle window
	U_UI_SOUND_PLAYER.play_slider_tick()
	var time_before: int = U_UI_SOUND_PLAYER._last_play_times.get(StringName("ui_tick"), 0)
	await get_tree().create_timer(0.05).timeout  # 50ms < 100ms throttle
	U_UI_SOUND_PLAYER.play_slider_tick()
	var time_after: int = U_UI_SOUND_PLAYER._last_play_times.get(StringName("ui_tick"), 0)

	# Then: Second play should be throttled (timestamp unchanged)
	assert_eq(time_before, time_after, "Second play within throttle window should be blocked (timestamp unchanged)")


func test_throttle_ms_allows_play_after_window() -> void:
	# Given: UI sound with throttle_ms = 100 (ui_tick)
	var sound_def := U_AUDIO_REGISTRY_LOADER.get_ui_sound(StringName("ui_tick"))
	assert_not_null(sound_def, "ui_tick should exist")

	# When: Playing twice with delay exceeding throttle window
	U_UI_SOUND_PLAYER.play_slider_tick()
	var time_before: int = U_UI_SOUND_PLAYER._last_play_times.get(StringName("ui_tick"), 0)
	await get_tree().create_timer(0.15).timeout  # 150ms > 100ms throttle
	U_UI_SOUND_PLAYER.play_slider_tick()
	var time_after: int = U_UI_SOUND_PLAYER._last_play_times.get(StringName("ui_tick"), 0)

	# Then: Second play should be allowed (timestamp updated)
	assert_gt(time_after, time_before, "Second play after throttle window should succeed (timestamp updated)")


func test_throttle_ms_zero_allows_all_plays() -> void:
	# Given: UI sounds with throttle_ms = 0 (ui_focus, ui_confirm, ui_cancel)
	var sound_def := U_AUDIO_REGISTRY_LOADER.get_ui_sound(StringName("ui_confirm"))
	assert_not_null(sound_def, "ui_confirm should exist")
	assert_eq(sound_def.throttle_ms, 0, "ui_confirm should have no throttle")

	# When: Playing same sound multiple times rapidly
	var ui_index_before := _manager._ui_sound_index
	for i in range(3):
		U_UI_SOUND_PLAYER.play_confirm()
	var ui_index_after := _manager._ui_sound_index

	# Then: All plays should succeed (index advances by 3, wrapping at polyphony limit)
	var expected_index := (ui_index_before + 3) % M_AUDIO_MANAGER.UI_SOUND_POLYPHONY
	assert_eq(ui_index_after, expected_index, "All plays should succeed when throttle_ms = 0 (index advanced)")


func test_different_sounds_have_independent_throttles() -> void:
	# Given: Two different UI sounds
	# ui_tick has throttle_ms = 100
	# ui_confirm has throttle_ms = 0

	# When: Playing both sounds rapidly
	U_UI_SOUND_PLAYER.play_slider_tick()
	U_UI_SOUND_PLAYER.play_confirm()

	await get_tree().process_frame

	# Then: Both sounds should play (independent throttles)
	var playing_count := _count_playing_ui_players()
	assert_eq(playing_count, 2, "Different sounds should have independent throttles")


## Helper: Count how many UI sound players are currently playing
func _count_playing_ui_players() -> int:
	var count := 0
	for child in _manager.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("UIPlayer"):
			if child.playing:
				count += 1
	return count
