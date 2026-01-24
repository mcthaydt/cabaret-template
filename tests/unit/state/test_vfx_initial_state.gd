extends GutTest

# Tests for RS_VFXInitialState resource (Phase 0 - Task 0.1)

const RS_VFXInitialState := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")

var initial_state: RS_VFXInitialState

func before_each() -> void:
	initial_state = RS_VFXInitialState.new()

func after_each() -> void:
	initial_state = null

# Test 1: Has screen_shake_enabled field
func test_has_screen_shake_enabled_field() -> void:
	assert_true(
		"screen_shake_enabled" in initial_state,
		"RS_VFXInitialState should have screen_shake_enabled field"
	)

# Test 2: Has screen_shake_intensity field
func test_has_screen_shake_intensity_field() -> void:
	assert_true(
		"screen_shake_intensity" in initial_state,
		"RS_VFXInitialState should have screen_shake_intensity field"
	)

# Test 3: Has damage_flash_enabled field
func test_has_damage_flash_enabled_field() -> void:
	assert_true(
		"damage_flash_enabled" in initial_state,
		"RS_VFXInitialState should have damage_flash_enabled field"
	)

# Test 4: Has particles_enabled field
func test_has_particles_enabled_field() -> void:
	assert_true(
		"particles_enabled" in initial_state,
		"RS_VFXInitialState should have particles_enabled field"
	)

# Test 5: to_dictionary returns all fields
func test_to_dictionary_returns_all_fields() -> void:
	var dict: Dictionary = initial_state.to_dictionary()

	assert_true(
		dict.has("screen_shake_enabled"),
		"to_dictionary should include screen_shake_enabled"
	)
	assert_true(
		dict.has("screen_shake_intensity"),
		"to_dictionary should include screen_shake_intensity"
	)
	assert_true(
		dict.has("damage_flash_enabled"),
		"to_dictionary should include damage_flash_enabled"
	)
	assert_true(
		dict.has("particles_enabled"),
		"to_dictionary should include particles_enabled"
	)

# Test 6: Defaults match reducer defaults
func test_defaults_match_reducer() -> void:
	# This test will verify defaults once the reducer is implemented
	# For now, just verify the resource has sensible defaults
	assert_true(
		initial_state.screen_shake_enabled is bool,
		"screen_shake_enabled should be a boolean"
	)
	assert_true(
		initial_state.screen_shake_intensity is float,
		"screen_shake_intensity should be a float"
	)
	assert_true(
		initial_state.damage_flash_enabled is bool,
		"damage_flash_enabled should be a boolean"
	)
	assert_true(
		initial_state.particles_enabled is bool,
		"particles_enabled should be a boolean"
	)

	# Verify intensity is in valid range (0.0-2.0)
	assert_true(
		initial_state.screen_shake_intensity >= 0.0 and initial_state.screen_shake_intensity <= 2.0,
		"screen_shake_intensity should be in range 0.0-2.0"
	)
