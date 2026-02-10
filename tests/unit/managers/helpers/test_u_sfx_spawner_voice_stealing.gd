extends GutTest

## Phase 7.1 - Voice Stealing Tests
## Tests voice stealing behavior when 16-player pool is exhausted

const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")

var _test_stream: AudioStream

func before_each() -> void:
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	U_SFXSpawner.cleanup()
	_test_stream = AudioStreamGenerator.new()
	_test_stream.mix_rate = 44100.0
	add_child_autofree(Node3D.new())
	U_SFXSpawner.initialize(get_child(get_child_count() - 1))

func after_each() -> void:
	U_SFXSpawner.cleanup()

func test_pool_exhaustion_triggers_voice_stealing() -> void:
	# Spawn 16 sounds to fill the pool
	var players: Array[AudioStreamPlayer3D] = []
	for i in range(16):
		var player := U_SFXSpawner.spawn_3d({
			"audio_stream": _test_stream,
			"position": Vector3(i, 0, 0),
			"bus": "SFX"
		})
		assert_not_null(player, "Should spawn player %d" % i)
		players.append(player)

	# 17th spawn should trigger voice stealing (not return null)
	var stolen_player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3(16, 0, 0),
		"bus": "SFX"
	})
	assert_not_null(stolen_player, "Should steal voice instead of returning null")
	assert_true(players.has(stolen_player), "Stolen player should be from the pool")

func test_steal_oldest_voice_selects_oldest_playing_sound() -> void:
	# Spawn sounds with small delays to establish order
	var first_player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX"
	})
	await wait_frames(2)

	U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3(1, 0, 0),
		"bus": "SFX"
	})
	await wait_frames(2)

	# Fill the rest of the pool
	for i in range(2, 16):
		U_SFXSpawner.spawn_3d({
			"audio_stream": _test_stream,
			"position": Vector3(i, 0, 0),
			"bus": "SFX"
		})

	# Trigger voice stealing - should steal the first (oldest) player
	var stolen := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3(16, 0, 0),
		"bus": "SFX"
	})

	assert_eq(stolen, first_player, "Should steal the oldest player")

func test_stats_tracking_spawns() -> void:
	U_SFXSpawner.reset_stats()

	U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX"
	})
	U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3(1, 0, 0),
		"bus": "SFX"
	})

	var stats := U_SFXSpawner.get_stats()
	assert_eq(stats["spawns"], 2, "Should track 2 spawns")

func test_stats_tracking_steals() -> void:
	U_SFXSpawner.reset_stats()

	# Fill pool
	for i in range(16):
		U_SFXSpawner.spawn_3d({
			"audio_stream": _test_stream,
			"position": Vector3(i, 0, 0),
			"bus": "SFX"
		})

	# Trigger 2 voice steals
	U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3(16, 0, 0),
		"bus": "SFX"
	})
	U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3(17, 0, 0),
		"bus": "SFX"
	})

	var stats := U_SFXSpawner.get_stats()
	assert_eq(stats["steals"], 2, "Should track 2 voice steals")

func test_stats_tracking_peak_usage() -> void:
	U_SFXSpawner.reset_stats()

	# Spawn 10 sounds
	for i in range(10):
		U_SFXSpawner.spawn_3d({
			"audio_stream": _test_stream,
			"position": Vector3(i, 0, 0),
			"bus": "SFX"
		})

	var stats := U_SFXSpawner.get_stats()
	assert_eq(stats["peak_usage"], 10, "Should track peak usage of 10")

func test_reset_stats_clears_counters() -> void:
	# Generate some stats
	for i in range(16):
		U_SFXSpawner.spawn_3d({
			"audio_stream": _test_stream,
			"position": Vector3(i, 0, 0),
			"bus": "SFX"
		})
	# Trigger voice steal
	U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3(16, 0, 0),
		"bus": "SFX"
	})

	U_SFXSpawner.reset_stats()

	var stats := U_SFXSpawner.get_stats()
	assert_eq(stats["spawns"], 0, "Should reset spawns")
	assert_eq(stats["steals"], 0, "Should reset steals")
	assert_eq(stats["peak_usage"], 0, "Should reset peak_usage")
