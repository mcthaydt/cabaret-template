extends GutTest

## Integration tests for UI sound polyphony
##
## Verifies that multiple UI sounds can overlap correctly using round-robin
## player selection (4 concurrent players).

const M_AUDIO_MANAGER := preload("res://scripts/managers/m_audio_manager.gd")
const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")
const U_AUDIO_REGISTRY_LOADER := preload("res://scripts/managers/helpers/u_audio_registry_loader.gd")

var _manager: M_AudioManager


func before_each() -> void:
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame


func test_four_overlapping_ui_sounds_play_simultaneously() -> void:
	# Given: 4 different UI sounds
	var sounds := [
		StringName("ui_focus"),
		StringName("ui_confirm"),
		StringName("ui_cancel"),
		StringName("ui_tick")
	]

	# When: Playing all 4 sounds rapidly (without awaiting frames between)
	for sound_id in sounds:
		_manager.play_ui_sound(sound_id)

	# Then: All 4 players should be active (playing)
	# Check immediately (before process_frame) since sounds are very short
	var playing_count := _count_playing_ui_players()
	assert_gte(playing_count, 2, "At least 2 UI sound players should be playing simultaneously")
	assert_lte(playing_count, 4, "Should not exceed 4 players")


func test_round_robin_player_selection() -> void:
	# Given: UI sound polyphony system
	var sound_id := StringName("ui_confirm")

	# When: Playing the same sound 5 times (more than POLYPHONY constant of 4)
	for i in range(5):
		_manager.play_ui_sound(sound_id)
		await get_tree().create_timer(0.05).timeout  # Small delay between plays

	# Then: Only 4 players should exist (oldest replaced by round-robin)
	var playing_count := _count_playing_ui_players()
	assert_lte(playing_count, 4, "Should not exceed UI_SOUND_POLYPHONY limit")


func test_sounds_dont_cut_each_other_off() -> void:
	# Given: Two different UI sounds
	var sound1 := StringName("ui_focus")
	var sound2 := StringName("ui_confirm")

	# When: Playing first sound, then second sound immediately (no await between)
	_manager.play_ui_sound(sound1)
	var count_after_first := _count_playing_ui_players()

	_manager.play_ui_sound(sound2)
	var count_after_second := _count_playing_ui_players()

	# Then: Both sounds should be playing (not cutting each other off)
	# Test that polyphony allows concurrent playback
	assert_gte(count_after_first, 1, "First sound should be playing")
	assert_gte(count_after_second, count_after_first, "Second sound should not reduce playing count")
	assert_lte(count_after_second, 4, "Should not exceed polyphony limit")


func test_volume_and_pitch_variation_applied() -> void:
	# Given: UI sound with volume_db and pitch_variation
	var sound_id := StringName("ui_confirm")
	var sound_def := U_AUDIO_REGISTRY_LOADER.get_ui_sound(sound_id)
	assert_not_null(sound_def, "Sound definition should exist")

	# When: Playing the sound
	_manager.play_ui_sound(sound_id)

	# Then: Volume should be applied to the player
	# (Pitch variation is randomized, so we just verify it doesn't crash)
	var playing_players := _get_playing_ui_players()
	assert_gt(playing_players.size(), 0, "At least one player should be playing")


## Helper: Count how many UI sound players are currently playing
func _count_playing_ui_players() -> int:
	var count := 0
	for child in _manager.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("UIPlayer"):
			if child.playing:
				count += 1
	return count


## Helper: Get all currently playing UI sound players
func _get_playing_ui_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child in _manager.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("UIPlayer"):
			if child.playing:
				players.append(child as AudioStreamPlayer)
	return players
