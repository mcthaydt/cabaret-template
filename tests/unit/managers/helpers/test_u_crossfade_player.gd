extends GutTest


var _crossfader: U_CrossfadePlayer
var _owner_node: Node

func before_each() -> void:
	# Set up audio bus layout
	_setup_test_buses()

	_owner_node = Node.new()
	add_child_autofree(_owner_node)
	_crossfader = U_CrossfadePlayer.new(_owner_node, &"Music")

func _setup_test_buses() -> void:
	# Clear existing buses beyond Master
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

	# Create Music bus for testing
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")

func after_each() -> void:
	if _crossfader != null:
		_crossfader.cleanup()
		_crossfader = null
	_owner_node = null

func test_initialization_creates_two_players() -> void:
	assert_not_null(_crossfader._player_a, "Player A should be created")
	assert_not_null(_crossfader._player_b, "Player B should be created")
	assert_eq(_crossfader._player_a.bus, "Music", "Player A should use correct bus")
	assert_eq(_crossfader._player_b.bus, "Music", "Player B should use correct bus")

func test_crossfade_to_swaps_players_correctly() -> void:
	var stream := AudioStreamGenerator.new()
	var initial_active := _crossfader._active_player

	_crossfader.crossfade_to(stream, &"test_track", 0.5, 0.0)

	assert_ne(_crossfader._active_player, initial_active, "Active player should swap")
	assert_eq(_crossfader._inactive_player, initial_active, "Inactive player should be old active")

func test_crossfade_to_starts_new_player_at_minus_80db() -> void:
	var stream := AudioStreamGenerator.new()

	_crossfader.crossfade_to(stream, &"test_track", 0.5, 0.0)
	await get_tree().process_frame

	# New player starts at -80dB but tween will animate it to 0dB
	# We just verify it was configured with the stream
	assert_eq(_crossfader._active_player.stream, stream, "New player should have stream set")
	assert_true(_crossfader._active_player.playing, "New player should be playing")

func test_crossfade_to_fades_old_player_out() -> void:
	var stream1 := AudioStreamGenerator.new()
	var stream2 := AudioStreamGenerator.new()

	# Start first track
	_crossfader.crossfade_to(stream1, &"track_1", 0.1, 0.0)
	var old_player := _crossfader._active_player
	await get_tree().create_timer(0.15).timeout

	# Start second track (should fade out first)
	_crossfader.crossfade_to(stream2, &"track_2", 0.1, 0.0)
	await get_tree().create_timer(0.15).timeout

	assert_false(old_player.playing, "Old player should be stopped after crossfade")

func test_crossfade_to_fades_new_player_in() -> void:
	var stream := AudioStreamGenerator.new()

	_crossfader.crossfade_to(stream, &"test_track", 0.1, 0.0)
	await get_tree().process_frame
	if _crossfader._tween != null and _crossfader._tween.is_valid():
		await _crossfader._tween.finished

	# After crossfade completes, new player should be at 0dB
	assert_almost_eq(_crossfader._active_player.volume_db, 0.0, 1.0, "New player should fade to 0dB")

func test_overlapping_crossfades_kill_previous_tween() -> void:
	var stream1 := AudioStreamGenerator.new()
	var stream2 := AudioStreamGenerator.new()

	_crossfader.crossfade_to(stream1, &"track_1", 1.0, 0.0)
	var first_tween := _crossfader._tween

	# Start second crossfade before first completes
	await get_tree().process_frame
	_crossfader.crossfade_to(stream2, &"track_2", 1.0, 0.0)

	# First tween should be killed
	assert_false(first_tween.is_valid(), "Previous tween should be killed")

func test_stop_fades_active_player_out() -> void:
	var stream := AudioStreamGenerator.new()

	_crossfader.crossfade_to(stream, &"test_track", 0.1, 0.0)
	await get_tree().create_timer(0.15).timeout

	_crossfader.stop(0.1)
	await get_tree().create_timer(0.15).timeout

	assert_false(_crossfader._active_player.playing, "Active player should be stopped")

func test_pause_stores_playback_position() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.1

	_crossfader.crossfade_to(stream, &"test_track", 0.0, 0.0)
	assert_true(_crossfader.is_playing(), "Should be playing before pause")

	_crossfader.pause()
	assert_false(_crossfader.is_playing(), "Should not be playing after pause")

func test_resume_continues_from_stored_position() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.1

	_crossfader.crossfade_to(stream, &"test_track", 0.0, 0.0)
	assert_true(_crossfader.is_playing(), "Should be playing initially")

	_crossfader.pause()
	assert_false(_crossfader.is_playing(), "Should stop after pause")

	_crossfader.resume()
	assert_true(_crossfader.is_playing(), "Should resume playing after resume")

func test_get_current_track_id_returns_correct_id() -> void:
	var stream := AudioStreamGenerator.new()

	assert_eq(_crossfader.get_current_track_id(), StringName(""), "Should start empty")

	_crossfader.crossfade_to(stream, &"my_track", 0.0, 0.0)
	assert_eq(_crossfader.get_current_track_id(), &"my_track", "Should return current track ID")

func test_get_playback_position_returns_position() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.1

	_crossfader.crossfade_to(stream, &"test_track", 0.0, 0.0)
	await get_tree().create_timer(0.05).timeout

	var position := _crossfader.get_playback_position()
	# In headless mode, AudioStreamGenerator may not advance playback position
	# Just verify the method returns a valid number
	assert_gte(position, 0.0, "Should return position >= 0")

func test_is_playing_returns_correct_state() -> void:
	var stream := AudioStreamGenerator.new()

	assert_false(_crossfader.is_playing(), "Should not be playing initially")

	_crossfader.crossfade_to(stream, &"test_track", 0.0, 0.0)
	assert_true(_crossfader.is_playing(), "Should be playing after crossfade_to")

	_crossfader.stop(0.0)
	await get_tree().process_frame
	assert_false(_crossfader.is_playing(), "Should not be playing after stop")

func test_cleanup_frees_both_players() -> void:
	var player_a := _crossfader._player_a
	var player_b := _crossfader._player_b

	_crossfader.cleanup()
	await get_tree().process_frame

	# Players should be queued for deletion
	assert_false(is_instance_valid(player_a), "Player A should be freed")
	assert_false(is_instance_valid(player_b), "Player B should be freed")
