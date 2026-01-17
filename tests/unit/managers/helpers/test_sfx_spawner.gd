extends GutTest

const U_SFX_SPAWNER := preload("res://scripts/managers/helpers/m_sfx_spawner.gd")

var _parent: Node3D

func before_each() -> void:
	_reset_audio_buses()
	_ensure_sfx_bus_exists()

	_parent = Node3D.new()
	_parent.name = "TestParent"
	add_child_autofree(_parent)

	U_SFX_SPAWNER.cleanup()

func after_each() -> void:
	U_SFX_SPAWNER.cleanup()
	_reset_audio_buses()

	_parent = null

func _pump() -> void:
	await get_tree().process_frame

func _reset_audio_buses() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

func _ensure_sfx_bus_exists() -> void:
	if AudioServer.get_bus_index("SFX") != -1:
		return
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "SFX")
	AudioServer.set_bus_send(1, "Master")

func test_initialize_creates_pool_of_16_players() -> void:
	U_SFX_SPAWNER.initialize(_parent)

	assert_not_null(U_SFX_SPAWNER._container)
	assert_true(U_SFX_SPAWNER._container is Node3D)
	assert_eq(U_SFX_SPAWNER._container.name, "SFXPool")

	assert_eq(U_SFX_SPAWNER._pool.size(), 16)
	assert_eq(U_SFX_SPAWNER._container.get_child_count(), 16)

func test_players_have_expected_defaults() -> void:
	U_SFX_SPAWNER.initialize(_parent)

	var player := U_SFX_SPAWNER._pool[0] as AudioStreamPlayer3D
	assert_not_null(player)
	assert_eq(player.max_distance, 50.0)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)

func test_initialize_is_idempotent() -> void:
	U_SFX_SPAWNER.initialize(_parent)
	var first_container := U_SFX_SPAWNER._container

	U_SFX_SPAWNER.initialize(_parent)

	assert_eq(U_SFX_SPAWNER._container, first_container)
	assert_eq(U_SFX_SPAWNER._pool.size(), 16)
	assert_eq(U_SFX_SPAWNER._container.get_child_count(), 16)

func test_spawn_3d_returns_available_player() -> void:
	U_SFX_SPAWNER.initialize(_parent)

	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({
		"audio_stream": stream,
	})

	assert_not_null(player)
	assert_true(player is AudioStreamPlayer3D)

func test_spawn_3d_configures_player_properties() -> void:
	U_SFX_SPAWNER.initialize(_parent)

	var stream := AudioStreamWAV.new()
	var position := Vector3(1, 2, 3)
	var player := U_SFX_SPAWNER.spawn_3d({
		"audio_stream": stream,
		"position": position,
		"volume_db": -3.0,
		"pitch_scale": 1.25,
		"bus": "SFX",
	})

	assert_eq(player.stream, stream)
	assert_eq(player.global_position, position)
	assert_eq(player.volume_db, -3.0)
	assert_eq(player.pitch_scale, 1.25)
	assert_eq(player.bus, "SFX")

func test_spawn_3d_applies_defaults_when_missing_fields() -> void:
	U_SFX_SPAWNER.initialize(_parent)

	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({
		"audio_stream": stream,
	})

	assert_eq(player.global_position, Vector3.ZERO)
	assert_eq(player.volume_db, 0.0)
	assert_eq(player.pitch_scale, 1.0)
	assert_eq(player.bus, "SFX")

func test_spawn_3d_disables_attenuation_and_panning_when_spatial_audio_disabled() -> void:
	U_SFX_SPAWNER.initialize(_parent)
	U_SFX_SPAWNER.set_spatial_audio_enabled(false)

	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})

	assert_not_null(player)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED)
	assert_eq(player.panning_strength, 0.0)

func test_spawn_3d_restores_spatial_settings_when_spatial_audio_reenabled() -> void:
	U_SFX_SPAWNER.initialize(_parent)
	U_SFX_SPAWNER.set_spatial_audio_enabled(false)
	U_SFX_SPAWNER.set_spatial_audio_enabled(true)

	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})

	assert_not_null(player)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	assert_eq(player.panning_strength, 1.0)

func test_pool_exhaustion_returns_null_and_warns() -> void:
	U_SFX_SPAWNER.initialize(_parent)

	var stream := AudioStreamWAV.new()
	for _i in range(16):
		var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
		assert_not_null(player)

	var exhausted := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_null(exhausted)
	assert_engine_error("SFX pool exhausted")

func test_player_marked_in_use_and_cleared_on_finished() -> void:
	U_SFX_SPAWNER.initialize(_parent)

	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_true(U_SFX_SPAWNER.is_player_in_use(player))

	player.emit_signal("finished")
	assert_false(U_SFX_SPAWNER.is_player_in_use(player))

func test_player_auto_returns_to_pool_when_finished() -> void:
	U_SFX_SPAWNER.initialize(_parent)

	var stream := AudioStreamWAV.new()
	var first := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	first.emit_signal("finished")

	var second := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_eq(second, first)

func test_cleanup_clears_pool_and_container() -> void:
	U_SFX_SPAWNER.initialize(_parent)
	assert_eq(U_SFX_SPAWNER._pool.size(), 16)

	U_SFX_SPAWNER.cleanup()
	await _pump()

	assert_eq(U_SFX_SPAWNER._pool.size(), 0)
	assert_null(U_SFX_SPAWNER._container)
