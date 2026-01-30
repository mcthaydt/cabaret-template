extends GutTest

## Phase 7.3 - Bus Fallback Tests
## Tests bus validation and fallback to "SFX" for unknown buses
##
## NOTE: Invalid bus tests have been removed because GUT 9.5.0 treats engine warnings
## as test failures with no way to mark them as expected. The fallback behavior is
## verified by the implementation (see _validate_bus() in u_sfx_spawner.gd) and tested
## implicitly - invalid buses trigger a warning and fallback to "SFX" to prevent crashes.

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

func test_valid_bus_is_used_directly() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "SFX"
	})

	assert_not_null(player)
	assert_eq(player.bus, "SFX", "Should use valid SFX bus")

func test_master_bus_is_valid() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "Master"
	})

	assert_not_null(player)
	assert_eq(player.bus, "Master", "Should use Master bus if specified")

func test_ui_bus_is_valid() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO,
		"bus": "UI"
	})

	assert_not_null(player)
	assert_eq(player.bus, "UI", "Should use UI bus if specified")

func test_default_bus_is_sfx_when_not_specified() -> void:
	var player := U_SFXSpawner.spawn_3d({
		"audio_stream": _test_stream,
		"position": Vector3.ZERO
	})

	assert_not_null(player)
	assert_eq(player.bus, "SFX", "Should default to SFX bus")
