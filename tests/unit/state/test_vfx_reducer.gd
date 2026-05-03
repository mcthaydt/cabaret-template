extends GutTest

# Tests for U_VFXReducer (Phase 0 - Task 0.3)


# Test 1: Default state structure
func test_default_state_has_all_fields() -> void:
	var default_state: Dictionary = U_VFXReducer.get_default_vfx_state()

	assert_true(
		default_state.has("screen_shake_enabled"),
		"Default state should have screen_shake_enabled"
	)
	assert_true(
		default_state.has("screen_shake_intensity"),
		"Default state should have screen_shake_intensity"
	)
	assert_true(
		default_state.has("damage_flash_enabled"),
		"Default state should have damage_flash_enabled"
	)
	assert_true(
		default_state.has("particles_enabled"),
		"Default state should have particles_enabled"
	)

# Test 2: Default values are sensible
func test_default_state_has_sensible_values() -> void:
	var default_state: Dictionary = U_VFXReducer.get_default_vfx_state()

	assert_true(
		default_state["screen_shake_enabled"] is bool,
		"screen_shake_enabled should be a boolean"
	)
	assert_true(
		default_state["screen_shake_intensity"] is float,
		"screen_shake_intensity should be a float"
	)
	assert_true(
		default_state["damage_flash_enabled"] is bool,
		"damage_flash_enabled should be a boolean"
	)
	assert_true(
		default_state["particles_enabled"] is bool,
		"particles_enabled should be a boolean"
	)

	# Intensity should be in valid range
	var intensity: float = default_state["screen_shake_intensity"]
	assert_true(
		intensity >= 0.0 and intensity <= 2.0,
		"Default intensity should be in range 0.0-2.0"
	)

# Test 3: set_screen_shake_enabled enables shake
func test_set_screen_shake_enabled_true() -> void:
	var state := _make_vfx_state(false, 1.0, true)
	var action := U_VFXActions.set_screen_shake_enabled(true)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_true(
		reduced["screen_shake_enabled"],
		"screen_shake_enabled should be true"
	)

# Test 4: set_screen_shake_enabled disables shake
func test_set_screen_shake_enabled_false() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_screen_shake_enabled(false)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_false(
		reduced["screen_shake_enabled"],
		"screen_shake_enabled should be false"
	)

# Test 5: set_screen_shake_intensity updates intensity
func test_set_screen_shake_intensity_normal_value() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_screen_shake_intensity(1.5)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_almost_eq(
		reduced["screen_shake_intensity"],
		1.5,
		0.0001,
		"Intensity should be set to 1.5"
	)

# Test 6: set_screen_shake_intensity clamps lower bound
func test_set_screen_shake_intensity_clamp_lower() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_screen_shake_intensity(-0.5)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_almost_eq(
		reduced["screen_shake_intensity"],
		0.0,
		0.0001,
		"Intensity should be clamped to 0.0"
	)

# Test 7: set_screen_shake_intensity clamps upper bound
func test_set_screen_shake_intensity_clamp_upper() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_screen_shake_intensity(3.5)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_almost_eq(
		reduced["screen_shake_intensity"],
		2.0,
		0.0001,
		"Intensity should be clamped to 2.0"
	)

# Test 8: set_damage_flash_enabled enables flash
func test_set_damage_flash_enabled_true() -> void:
	var state := _make_vfx_state(true, 1.0, false)
	var action := U_VFXActions.set_damage_flash_enabled(true)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_true(
		reduced["damage_flash_enabled"],
		"damage_flash_enabled should be true"
	)

# Test 9: set_damage_flash_enabled disables flash
func test_set_damage_flash_enabled_false() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_damage_flash_enabled(false)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_false(
		reduced["damage_flash_enabled"],
		"damage_flash_enabled should be false"
	)

# Test 10: set_particles_enabled disables particles
func test_set_particles_enabled_false() -> void:
	var state := _make_vfx_state(true, 1.0, true, true)
	var action := U_VFXActions.set_particles_enabled(false)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_false(
		reduced["particles_enabled"],
		"particles_enabled should be false"
	)

# Test 11: set_particles_enabled enables particles
func test_set_particles_enabled_true() -> void:
	var state := _make_vfx_state(true, 1.0, true, false)
	var action := U_VFXActions.set_particles_enabled(true)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_true(
		reduced["particles_enabled"],
		"particles_enabled should be true"
	)

# Test 12: Reducer is immutable
func test_reducer_immutability() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_screen_shake_enabled(false)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_ne(
		state,
		reduced,
		"Reducer should return a new state object"
	)
	assert_true(
		state["screen_shake_enabled"],
		"Original state should remain unchanged"
	)

# Test 13: Unknown action returns null (no change)
func test_unhandled_action_returns_null() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := {"type": StringName("vfx/unknown_action")}
	var reduced: Variant = U_VFXReducer.reduce(state, action)

	assert_null(
		reduced,
		"Unknown action should return null (indicating no change)"
	)

# Test 14: Multiple field updates preserve other fields
func test_updating_one_field_preserves_others() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_screen_shake_intensity(0.5)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_true(
		reduced["screen_shake_enabled"],
		"screen_shake_enabled should be preserved"
	)
	assert_true(
		reduced["damage_flash_enabled"],
		"damage_flash_enabled should be preserved"
	)
	assert_true(
		reduced["particles_enabled"],
		"particles_enabled should be preserved"
	)

# Test 15: Zero intensity is valid
func test_set_screen_shake_intensity_zero() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_screen_shake_intensity(0.0)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_almost_eq(
		reduced["screen_shake_intensity"],
		0.0,
		0.0001,
		"Zero intensity should be allowed"
	)

# Test 16: Max intensity (2.0) is valid
func test_set_screen_shake_intensity_max() -> void:
	var state := _make_vfx_state(true, 1.0, true)
	var action := U_VFXActions.set_screen_shake_intensity(2.0)
	var reduced: Dictionary = U_VFXReducer.reduce(state, action)

	assert_almost_eq(
		reduced["screen_shake_intensity"],
		2.0,
		0.0001,
		"Max intensity (2.0) should be allowed"
	)

# Test 17: Empty state initializes with defaults
func test_empty_state_initializes_defaults() -> void:
	var action := U_VFXActions.set_screen_shake_enabled(true)
	var reduced: Dictionary = U_VFXReducer.reduce({}, action)

	assert_true(
		reduced.has("screen_shake_enabled"),
		"Reducer should initialize defaults for empty state"
	)
	assert_true(
		reduced.has("screen_shake_intensity"),
		"Reducer should initialize intensity for empty state"
	)
	assert_true(
		reduced.has("damage_flash_enabled"),
		"Reducer should initialize flash for empty state"
	)
	assert_true(
		reduced.has("particles_enabled"),
		"Reducer should initialize particles_enabled for empty state"
	)

# Helper: Create VFX state for testing
func _make_vfx_state(
	shake_enabled: bool,
	shake_intensity: float,
	flash_enabled: bool,
	particles_enabled: bool = true
) -> Dictionary:
	return {
		"screen_shake_enabled": shake_enabled,
		"screen_shake_intensity": shake_intensity,
		"damage_flash_enabled": flash_enabled,
		"particles_enabled": particles_enabled
	}
