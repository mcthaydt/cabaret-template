extends GutTest

## Phase 7.5 - Per-Sound Spatialization Tests
## Tests per-sound spatialization configuration overrides

const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")

var _test_stream: AudioStream

func before_each() -> void:
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	U_SFXSpawner.cleanup()
	_test_stream = AudioStreamGenerator.new()
	_test_stream.mix_rate = 44100.0
	add_child_autofree(Node3D.new())
	U_SFXSpawner.initialize(get_child(get_child_count() - 1))
	U_SFXSpawner.set_spatial_audio_enabled(true)

func after_each() -> void:
	U_SFXSpawner.cleanup()

func test_max_distance_override_is_applied() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"max_distance": 100.0
	})

	assert_not_null(player)
	assert_eq(player.max_distance, 100.0, "Should apply custom max_distance")

func test_default_max_distance_when_not_specified() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX"
	})

	assert_not_null(player)
	assert_eq(player.max_distance, 50.0, "Should use default max_distance of 50.0")

func test_max_distance_zero_uses_default() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"max_distance": 0.0
	})

	assert_not_null(player)
	assert_eq(player.max_distance, 50.0, "Should use default when max_distance is 0")

func test_max_distance_negative_uses_default() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"max_distance": -5.0
	})

	assert_not_null(player)
	assert_eq(player.max_distance, 50.0, "Should use default when max_distance is negative")

func test_attenuation_model_override_is_applied() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"attenuation_model": AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	})

	assert_not_null(player)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC,
		"Should apply custom attenuation_model")

func test_default_attenuation_model_when_not_specified() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX"
	})

	assert_not_null(player)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
		"Should use default ATTENUATION_INVERSE_DISTANCE")

func test_attenuation_model_negative_uses_default() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"attenuation_model": -1
	})

	assert_not_null(player)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
		"Should use default when attenuation_model is negative")

func test_respects_spatial_audio_disabled_flag() -> void:
	U_SFXSpawner.set_spatial_audio_enabled(false)

	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"max_distance": 100.0,  # This should be ignored
		"attenuation_model": AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC  # This should be ignored
	})

	assert_not_null(player)
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED,
		"Should disable attenuation when spatial audio disabled")
	assert_eq(player.panning_strength, 0.0,
		"Should disable panning when spatial audio disabled")

func test_combined_spatialization_overrides() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX",
		"max_distance": 75.0,
		"attenuation_model": AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	})

	assert_not_null(player)
	assert_eq(player.max_distance, 75.0, "Should apply custom max_distance")
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC,
		"Should apply custom attenuation_model")
	assert_eq(player.panning_strength, 1.0, "Should maintain default panning strength")
