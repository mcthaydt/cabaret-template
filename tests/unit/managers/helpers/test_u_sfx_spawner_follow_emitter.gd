extends GutTest

## Phase 7.7 - Follow-Emitter Mode Tests
## Tests sounds following moving emitters

const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")

var _test_stream: AudioStream
var _target_node: Node3D

func before_each() -> void:
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	U_SFXSpawner.cleanup()
	_test_stream = AudioStreamGenerator.new()
	_test_stream.mix_rate = 44100.0

	var container := Node3D.new()
	add_child_autofree(container)
	U_SFXSpawner.initialize(container)

	_target_node = Node3D.new()
	_target_node.name = "FollowTarget"
	add_child_autofree(_target_node)
	_target_node.global_position = Vector3(5, 10, 15)

func after_each() -> void:
	U_SFXSpawner.cleanup()
	_target_node = null

func test_follow_target_config_stores_target() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"follow_target": _target_node
	})

	assert_not_null(player)
	assert_true(U_SFXSpawner._follow_targets.has(player),
		"Should store follow target in dictionary")
	assert_eq(U_SFXSpawner._follow_targets[player], _target_node,
		"Should store correct target node")

func test_follow_target_null_does_not_store() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"follow_target": null
	})

	assert_not_null(player)
	assert_false(U_SFXSpawner._follow_targets.has(player),
		"Should not store null follow target")

func test_follow_target_invalid_type_does_not_store() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"follow_target": "NotANode3D"
	})

	assert_not_null(player)
	assert_false(U_SFXSpawner._follow_targets.has(player),
		"Should not store non-Node3D follow target")

func test_update_follow_targets_updates_positions() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"follow_target": _target_node
	})

	# Move target
	_target_node.global_position = Vector3(20, 30, 40)

	# Update follow targets
	U_SFXSpawner.update_follow_targets()

	assert_eq(player.global_position, Vector3(20, 30, 40),
		"Should update player position to match target")

func test_update_follow_targets_removes_invalid_entries() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"follow_target": _target_node
	})

	# Free the target node
	_target_node.queue_free()
	await wait_frames(2)

	# Update should remove invalid target
	U_SFXSpawner.update_follow_targets()

	assert_false(U_SFXSpawner._follow_targets.has(player),
		"Should remove entry when target is freed")

func test_update_follow_targets_removes_stopped_players() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"follow_target": _target_node
	})

	# Stop the player
	player.stop()
	player.emit_signal("finished")

	# Update should remove stopped player
	U_SFXSpawner.update_follow_targets()

	assert_false(U_SFXSpawner._follow_targets.has(player),
		"Should remove entry when player is no longer playing")

func test_voice_stealing_clears_follow_target() -> void:
	# Fill the pool with follow targets
	var targets: Array[Node3D] = []
	for i in range(16):
		var target := Node3D.new()
		add_child_autofree(target)
		target.global_position = Vector3(i, 0, 0)
		targets.append(target)

		U_SFXSpawner.spawn_3d({
			"audio_stream": _test_stream,
			"position": Vector3.ZERO,
			"bus": "SFX",
			"follow_target": target
		})

	var initial_count := U_SFXSpawner._follow_targets.size()
	assert_eq(initial_count, 16, "Should have 16 follow targets")

	# Trigger voice stealing
	U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX"
	})

	# One follow target should be removed (the stolen player)
	assert_eq(U_SFXSpawner._follow_targets.size(), 15,
		"Should remove follow target when voice is stolen")

func test_multiple_follow_targets_update_independently() -> void:
	var target1 := Node3D.new()
	add_child_autofree(target1)
	target1.global_position = Vector3(1, 0, 0)

	var target2 := Node3D.new()
	add_child_autofree(target2)
	target2.global_position = Vector3(2, 0, 0)

	var player1 := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"follow_target": target1
	})

	var player2 := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"follow_target": target2
	})

	# Move targets to different positions
	target1.global_position = Vector3(10, 20, 30)
	target2.global_position = Vector3(40, 50, 60)

	U_SFXSpawner.update_follow_targets()

	assert_eq(player1.global_position, Vector3(10, 20, 30),
		"Player 1 should follow target 1")
	assert_eq(player2.global_position, Vector3(40, 50, 60),
		"Player 2 should follow target 2")
