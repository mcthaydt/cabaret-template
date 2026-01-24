extends BaseTest

## SFX pooling integration tests (Phase 9.4)
##
## Validates pooled 3D SFX playback via U_SFXSpawner inside M_AudioManager.

const M_AUDIO_MANAGER := preload("res://scripts/managers/m_audio_manager.gd")
const U_SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")

var _audio_manager: M_AudioManager


func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_SFX_SPAWNER.cleanup()
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	await get_tree().process_frame

	_audio_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_audio_manager)
	await get_tree().process_frame


func after_each() -> void:
	U_SFX_SPAWNER.cleanup()
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	super.after_each()


func _first_player() -> AudioStreamPlayer3D:
	if U_SFX_SPAWNER._pool.is_empty():
		return null
	return U_SFX_SPAWNER._pool[0] as AudioStreamPlayer3D


func _count_in_use_players() -> int:
	var count := 0
	for player_variant in U_SFX_SPAWNER._pool:
		var player := player_variant as AudioStreamPlayer3D
		if player == null:
			continue
		if not is_instance_valid(player):
			continue
		if U_SFX_SPAWNER.is_player_in_use(player):
			count += 1
	return count


func test_audio_manager_initializes_sfx_pool_container() -> void:
	assert_not_null(U_SFX_SPAWNER._container)
	assert_true(U_SFX_SPAWNER._container is Node3D)
	assert_eq(U_SFX_SPAWNER._container.name, "SFXPool")
	assert_eq(U_SFX_SPAWNER._container.get_parent(), _audio_manager)


func test_pool_size_is_16_players() -> void:
	assert_eq(U_SFX_SPAWNER._pool.size(), 16)
	assert_eq(U_SFX_SPAWNER._container.get_child_count(), 16)


func test_players_have_default_max_distance() -> void:
	var player := _first_player()
	assert_not_null(player)
	assert_almost_eq(player.max_distance, 50.0, 0.001)


func test_players_have_default_attenuation_model_when_spatial_enabled() -> void:
	var player := _first_player()
	assert_not_null(player)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	assert_almost_eq(player.panning_strength, 1.0, 0.001)


func test_spawn_returns_null_for_empty_config() -> void:
	var player := U_SFX_SPAWNER.spawn_3d({})
	assert_null(player)


func test_spawn_returns_null_when_audio_stream_missing() -> void:
	var player := U_SFX_SPAWNER.spawn_3d({"position": Vector3.ZERO})
	assert_null(player)


func test_spawn_returns_null_when_audio_stream_wrong_type() -> void:
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": 123})
	assert_null(player)


func test_spawn_returns_player_and_marks_in_use() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_not_null(player)
	assert_true(U_SFX_SPAWNER.is_player_in_use(player))
	assert_eq(_count_in_use_players(), 1)


func test_spawn_sets_stream() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_eq(player.stream, stream)


func test_spawn_sets_position() -> void:
	var stream := AudioStreamWAV.new()
	var position := Vector3(1, 2, 3)
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "position": position})
	assert_eq(player.global_position, position)


func test_spawn_sets_volume_db() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "volume_db": -3.0})
	assert_almost_eq(player.volume_db, -3.0, 0.001)


func test_spawn_sets_pitch_scale() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "pitch_scale": 1.25})
	assert_almost_eq(player.pitch_scale, 1.25, 0.001)


func test_spawn_sets_custom_bus() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "bus": "Footsteps"})
	assert_eq(player.bus, "Footsteps")

func test_spawn_starts_playback() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_true(player.playing, "spawn_3d should start playback")


func test_spawn_defaults_missing_fields() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_eq(player.global_position, Vector3.ZERO)
	assert_almost_eq(player.volume_db, 0.0, 0.001)
	assert_almost_eq(player.pitch_scale, 1.0, 0.001)
	assert_eq(player.bus, "SFX")


func test_finished_signal_clears_in_use_meta() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_true(U_SFX_SPAWNER.is_player_in_use(player))

	player.emit_signal("finished")
	assert_false(U_SFX_SPAWNER.is_player_in_use(player))


func test_finished_player_is_reused_by_next_spawn() -> void:
	var stream := AudioStreamWAV.new()
	var first := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	first.emit_signal("finished")

	var second := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_eq(second, first)


func test_pool_exhaustion_returns_null_and_warns() -> void:
	var stream := AudioStreamWAV.new()
	for _i in range(16):
		var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
		assert_not_null(player)

	var exhausted := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_null(exhausted)
	assert_engine_error("SFX pool exhausted")


func test_concurrent_playback_uses_16_unique_players() -> void:
	var stream := AudioStreamWAV.new()
	var ids: Dictionary = {}
	for _i in range(16):
		var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
		ids[player.get_instance_id()] = true
	assert_eq(ids.size(), 16)


func test_can_route_sfx_to_ui_bus() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "bus": "UI"})
	assert_eq(player.bus, "UI")


func test_can_route_sfx_to_footsteps_bus() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "bus": "Footsteps"})
	assert_eq(player.bus, "Footsteps")


func test_ui_and_footsteps_buses_send_to_sfx_bus() -> void:
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("UI")), "SFX")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("Footsteps")), "SFX")


func test_spatial_audio_disabled_disables_attenuation_and_panning() -> void:
	U_SFX_SPAWNER.set_spatial_audio_enabled(false)

	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED)
	assert_almost_eq(player.panning_strength, 0.0, 0.001)


func test_spatial_audio_reenabled_restores_attenuation_and_panning() -> void:
	U_SFX_SPAWNER.set_spatial_audio_enabled(false)
	U_SFX_SPAWNER.set_spatial_audio_enabled(true)

	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	assert_almost_eq(player.panning_strength, 1.0, 0.001)


func test_player_max_distance_remains_default_after_spatial_toggle() -> void:
	U_SFX_SPAWNER.set_spatial_audio_enabled(false)
	U_SFX_SPAWNER.set_spatial_audio_enabled(true)

	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_almost_eq(player.max_distance, 50.0, 0.001)


func test_bus_default_is_sfx_when_not_provided() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream})
	assert_eq(player.bus, "SFX")


func test_spawn_position_defaults_to_zero_when_wrong_type() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "position": "not a Vector3"})
	assert_eq(player.global_position, Vector3.ZERO)


func test_spawn_volume_defaults_to_zero_when_wrong_type() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "volume_db": "not a float"})
	assert_almost_eq(player.volume_db, 0.0, 0.001)


func test_spawn_pitch_defaults_to_one_when_wrong_type() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "pitch_scale": "not a float"})
	assert_almost_eq(player.pitch_scale, 1.0, 0.001)


func test_spawn_bus_casts_to_string() -> void:
	var stream := AudioStreamWAV.new()
	var player := U_SFX_SPAWNER.spawn_3d({"audio_stream": stream, "bus": StringName("SFX")})
	assert_eq(player.bus, "SFX")
