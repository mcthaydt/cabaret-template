extends GutTest

## Performance profiling tests for Audio Manager
##
## Phase 10.7 - Performance Verification
## Validates performance requirements:
## - Voice stealing behavior under load
## - Peak SFX pool usage tracking
## - SFX spawner performance
## - Follow-emitter mode overhead

const U_SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")

func before_each() -> void:
	# Initialize SFX spawner pool
	U_SFX_SPAWNER.cleanup()
	U_SFX_SPAWNER.initialize(self)
	U_SFX_SPAWNER.reset_stats()

func after_each() -> void:
	U_SFX_SPAWNER.reset_stats()
	U_SFX_SPAWNER.cleanup()
	await get_tree().process_frame

## Helper: Create benchmark timer
func _benchmark(label: String, callable: Callable) -> float:
	var start_time: int = Time.get_ticks_usec()
	callable.call()
	var end_time: int = Time.get_ticks_usec()
	var elapsed_ms: float = (end_time - start_time) / 1000.0
	return elapsed_ms

## T1001: Verify voice stealing statistics under load
func test_voice_stealing_statistics() -> void:
	U_SFX_SPAWNER.reset_stats()

	# Create test stream
	var test_stream := AudioStreamGenerator.new()
	test_stream.mix_rate = 44100

	# Spawn sounds to trigger voice stealing (pool size is 16)
	var spawn_count: int = 50
	for i in range(spawn_count):
		U_SFX_SPAWNER.spawn_3d({
			"audio_stream": test_stream,
			"position": Vector3(i * 10.0, 0, 0),
			"bus": "SFX"
		})

	var stats: Dictionary = U_SFX_SPAWNER.get_stats()
	var tracked_spawns: int = stats.get("spawns", 0)
	var steal_count: int = stats.get("steals", 0)
	var peak_usage: int = stats.get("peak_usage", 0)

	# Verify stats tracking
	assert_eq(tracked_spawns, spawn_count, "Should track all spawns")
	assert_gt(steal_count, 0, "Voice stealing should occur when exceeding pool size of 16")
	assert_gte(peak_usage, 16, "Peak usage should be at least 16 (pool exhaustion)")
	assert_lte(peak_usage, 16, "Peak usage should not exceed pool size")

	# Calculate steal rate
	var steal_rate: float = (float(steal_count) / float(spawn_count)) * 100.0

	# Note: With 50 spawns and 16-player pool, expecting ~68% steal rate
	# This is intentionally high for stress testing
	pass_test("Voice stealing: %d steals out of %d spawns (%.1f%% rate), peak usage: %d" % [
		steal_count, spawn_count, steal_rate, peak_usage
	])

## T1002: Profile SFX spawner performance (100 rapid spawns)
func test_sfx_spawner_performance() -> void:
	U_SFX_SPAWNER.reset_stats()

	var test_stream := AudioStreamGenerator.new()
	test_stream.mix_rate = 44100

	# Measure time to spawn 100 sounds
	var elapsed_ms: float = _benchmark("100 Rapid SFX Spawns", func() -> void:
		for i in range(100):
			U_SFX_SPAWNER.spawn_3d({
				"audio_stream": test_stream,
				"position": Vector3(randf() * 100.0, randf() * 50.0, randf() * 100.0),
				"volume_db": randf_range(-10.0, 0.0),
				"pitch_scale": randf_range(0.9, 1.1),
				"bus": "SFX"
			})
	)

	var avg_per_spawn: float = elapsed_ms / 100.0
	var stats: Dictionary = U_SFX_SPAWNER.get_stats()

	# Verify performance
	assert_lt(avg_per_spawn, 1.0, "SFX spawn should be < 1.0ms per sound")

	pass_test("SFX spawner: %.3fms per spawn (%.1fms total for 100 sounds)" % [avg_per_spawn, elapsed_ms])

## T1003: Verify follow-emitter mode performance
func test_follow_emitter_performance() -> void:
	U_SFX_SPAWNER.reset_stats()

	var test_stream := AudioStreamGenerator.new()
	test_stream.mix_rate = 44100

	# Create follow targets
	var targets: Array[Node3D] = []
	for i in range(10):
		var target := Node3D.new()
		target.position = Vector3(i * 10.0, 0, 0)
		add_child(target)
		targets.append(target)
		autofree(target)

	# Spawn sounds with follow targets
	for target in targets:
		U_SFX_SPAWNER.spawn_3d({
			"audio_stream": test_stream,
			"position": target.global_position,
			"bus": "SFX",
			"follow_target": target
		})

	await get_tree().process_frame

	# Measure update performance
	var update_time: float = _benchmark("1000 Follow Target Updates", func() -> void:
		for i in range(1000):
			# Move targets
			for target in targets:
				target.position.x += 0.1
			# Update followers
			U_SFX_SPAWNER.update_follow_targets()
	)

	var avg_update: float = update_time / 1000.0

	# Verify performance
	assert_lt(avg_update, 0.2, "Follow target updates should be < 0.2ms for 10 targets")

	pass_test("Follow-emitter: %.3fms per update (10 targets)" % avg_update)

## T1004: Verify stats reset functionality
func test_stats_reset_clears_all_counters() -> void:
	# Spawn some sounds to populate stats
	var test_stream := AudioStreamGenerator.new()
	test_stream.mix_rate = 44100

	for i in range(20):
		U_SFX_SPAWNER.spawn_3d({
			"audio_stream": test_stream,
			"position": Vector3(i * 5.0, 0, 0),
			"bus": "SFX"
		})

	var stats_before: Dictionary = U_SFX_SPAWNER.get_stats()
	assert_gt(stats_before.get("spawns", 0), 0, "Should have spawns before reset")

	# Reset stats
	U_SFX_SPAWNER.reset_stats()

	var stats_after: Dictionary = U_SFX_SPAWNER.get_stats()
	assert_eq(stats_after.get("spawns", 0), 0, "Spawns should be reset")
	assert_eq(stats_after.get("steals", 0), 0, "Steals should be reset")
	assert_eq(stats_after.get("drops", 0), 0, "Drops should be reset")
	assert_eq(stats_after.get("peak_usage", 0), 0, "Peak usage should be reset")

	pass_test("Stats reset successful")

## T1005: Measure peak usage accuracy
func test_peak_usage_tracking_accuracy() -> void:
	U_SFX_SPAWNER.reset_stats()

	var test_stream := AudioStreamGenerator.new()
	test_stream.mix_rate = 44100

	# Spawn exactly 12 sounds simultaneously
	var concurrent_count: int = 12
	for i in range(concurrent_count):
		U_SFX_SPAWNER.spawn_3d({
			"audio_stream": test_stream,
			"position": Vector3(i * 5.0, 0, 0),
			"bus": "SFX"
		})

	await get_tree().process_frame

	var stats: Dictionary = U_SFX_SPAWNER.get_stats()
	var peak_usage: int = stats.get("peak_usage", 0)

	# Verify peak usage tracking
	assert_gte(peak_usage, concurrent_count, "Peak usage should track at least %d concurrent sounds" % concurrent_count)
	assert_lte(peak_usage, 16, "Peak usage should not exceed pool size")

	pass_test("Peak usage tracked: %d concurrent sounds" % peak_usage)

## T1006: Stress test with rapid spawns and steals
func test_stress_test_rapid_spawns() -> void:
	U_SFX_SPAWNER.reset_stats()

	var test_stream := AudioStreamGenerator.new()
	test_stream.mix_rate = 44100

	# Rapid spawn loop - 200 sounds as fast as possible
	var elapsed_ms: float = _benchmark("200 Rapid Spawns (Stress Test)", func() -> void:
		for i in range(200):
			U_SFX_SPAWNER.spawn_3d({
				"audio_stream": test_stream,
				"position": Vector3(randf() * 200.0, randf() * 100.0, randf() * 200.0),
				"volume_db": randf_range(-15.0, 0.0),
				"pitch_scale": randf_range(0.8, 1.2),
				"bus": "SFX"
			})
	)

	var stats: Dictionary = U_SFX_SPAWNER.get_stats()
	var spawn_count: int = stats.get("spawns", 0)
	var steal_count: int = stats.get("steals", 0)

	# Verify all spawns were processed (even if they stole voices)
	assert_eq(spawn_count, 200, "Should process all 200 spawns")
	assert_gt(steal_count, 0, "Should have voice stealing under stress")

	var avg_spawn: float = elapsed_ms / 200.0

	pass_test("Stress test: %.3fms per spawn, %d steals (%.1f ms total)" % [
		avg_spawn, steal_count, elapsed_ms
	])
