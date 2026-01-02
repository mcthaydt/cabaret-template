extends GutTest

## Tests for U_VFXSelectors (Phase 0 - Task 0.5)
##
## Verifies VFX selectors compute derived state correctly and handle edge cases
## (missing vfx slice, null state, missing fields).

const U_VFXSelectors := preload("res://scripts/state/selectors/u_vfx_selectors.gd")

# Test 1: is_screen_shake_enabled with valid state (enabled)
func test_is_screen_shake_enabled_returns_true() -> void:
	var state := _make_state(true, 1.0, true)
	var result: bool = U_VFXSelectors.is_screen_shake_enabled(state)

	assert_true(
		result,
		"is_screen_shake_enabled should return true when enabled"
	)

# Test 2: is_screen_shake_enabled with valid state (disabled)
func test_is_screen_shake_enabled_returns_false() -> void:
	var state := _make_state(false, 1.0, true)
	var result: bool = U_VFXSelectors.is_screen_shake_enabled(state)

	assert_false(
		result,
		"is_screen_shake_enabled should return false when disabled"
	)

# Test 3: is_screen_shake_enabled with missing vfx slice
func test_is_screen_shake_enabled_missing_vfx_slice() -> void:
	var state := {}
	var result: bool = U_VFXSelectors.is_screen_shake_enabled(state)

	assert_true(
		result,
		"is_screen_shake_enabled should return true (default) when vfx slice missing"
	)

# Test 4: is_screen_shake_enabled with missing field
func test_is_screen_shake_enabled_missing_field() -> void:
	var state := {"vfx": {"screen_shake_intensity": 1.0}}
	var result: bool = U_VFXSelectors.is_screen_shake_enabled(state)

	assert_true(
		result,
		"is_screen_shake_enabled should return true (default) when field missing"
	)

# Test 5: get_screen_shake_intensity with valid state
func test_get_screen_shake_intensity_returns_value() -> void:
	var state := _make_state(true, 1.5, true)
	var result: float = U_VFXSelectors.get_screen_shake_intensity(state)

	assert_almost_eq(
		result,
		1.5,
		0.0001,
		"get_screen_shake_intensity should return correct value"
	)

# Test 6: get_screen_shake_intensity with missing vfx slice
func test_get_screen_shake_intensity_missing_vfx_slice() -> void:
	var state := {}
	var result: float = U_VFXSelectors.get_screen_shake_intensity(state)

	assert_almost_eq(
		result,
		1.0,
		0.0001,
		"get_screen_shake_intensity should return 1.0 (default) when vfx slice missing"
	)

# Test 7: get_screen_shake_intensity with missing field
func test_get_screen_shake_intensity_missing_field() -> void:
	var state := {"vfx": {"screen_shake_enabled": true}}
	var result: float = U_VFXSelectors.get_screen_shake_intensity(state)

	assert_almost_eq(
		result,
		1.0,
		0.0001,
		"get_screen_shake_intensity should return 1.0 (default) when field missing"
	)

# Test 8: is_damage_flash_enabled with valid state (enabled)
func test_is_damage_flash_enabled_returns_true() -> void:
	var state := _make_state(true, 1.0, true)
	var result: bool = U_VFXSelectors.is_damage_flash_enabled(state)

	assert_true(
		result,
		"is_damage_flash_enabled should return true when enabled"
	)

# Test 9: is_damage_flash_enabled with valid state (disabled)
func test_is_damage_flash_enabled_returns_false() -> void:
	var state := _make_state(true, 1.0, false)
	var result: bool = U_VFXSelectors.is_damage_flash_enabled(state)

	assert_false(
		result,
		"is_damage_flash_enabled should return false when disabled"
	)

# Test 10: is_damage_flash_enabled with missing vfx slice
func test_is_damage_flash_enabled_missing_vfx_slice() -> void:
	var state := {}
	var result: bool = U_VFXSelectors.is_damage_flash_enabled(state)

	assert_true(
		result,
		"is_damage_flash_enabled should return true (default) when vfx slice missing"
	)

# Test 11: is_damage_flash_enabled with missing field
func test_is_damage_flash_enabled_missing_field() -> void:
	var state := {"vfx": {"screen_shake_enabled": true}}
	var result: bool = U_VFXSelectors.is_damage_flash_enabled(state)

	assert_true(
		result,
		"is_damage_flash_enabled should return true (default) when field missing"
	)

# Test 12: Selectors are pure functions (same input = same output)
func test_selectors_are_pure_functions() -> void:
	var state := _make_state(false, 0.5, false)

	var result1_enabled: bool = U_VFXSelectors.is_screen_shake_enabled(state)
	var result2_enabled: bool = U_VFXSelectors.is_screen_shake_enabled(state)

	var result1_intensity: float = U_VFXSelectors.get_screen_shake_intensity(state)
	var result2_intensity: float = U_VFXSelectors.get_screen_shake_intensity(state)

	var result1_flash: bool = U_VFXSelectors.is_damage_flash_enabled(state)
	var result2_flash: bool = U_VFXSelectors.is_damage_flash_enabled(state)

	assert_eq(
		result1_enabled,
		result2_enabled,
		"is_screen_shake_enabled should return same result for same input"
	)
	assert_almost_eq(
		result1_intensity,
		result2_intensity,
		0.0001,
		"get_screen_shake_intensity should return same result for same input"
	)
	assert_eq(
		result1_flash,
		result2_flash,
		"is_damage_flash_enabled should return same result for same input"
	)

# Test 13: Selectors do not mutate state
func test_selectors_do_not_mutate_state() -> void:
	var original_state := _make_state(true, 1.5, true)
	var state_copy: Dictionary = original_state.duplicate(true)

	var _enabled: bool = U_VFXSelectors.is_screen_shake_enabled(original_state)
	var _intensity: float = U_VFXSelectors.get_screen_shake_intensity(original_state)
	var _flash: bool = U_VFXSelectors.is_damage_flash_enabled(original_state)

	assert_eq(
		original_state,
		state_copy,
		"Selectors should not mutate state"
	)

# Helper: Create full state with vfx slice
func _make_state(
	shake_enabled: bool,
	shake_intensity: float,
	flash_enabled: bool
) -> Dictionary:
	return {
		"vfx": {
			"screen_shake_enabled": shake_enabled,
			"screen_shake_intensity": shake_intensity,
			"damage_flash_enabled": flash_enabled
		}
	}
