extends GutTest

# Phase 2 Task 2.1 (Red): Tests for M_ScreenShake helper
# Testing screen shake algorithm with quadratic falloff and noise-based offset/rotation

const M_ScreenShake := preload("res://scripts/managers/helpers/m_screen_shake.gd")
const ShakeResult := preload("res://scripts/managers/helpers/m_shake_result.gd")

var _shake_helper: M_ScreenShake


func before_each() -> void:
	_shake_helper = M_ScreenShake.new()


func after_each() -> void:
	_shake_helper = null


# Test 1: Initialization creates FastNoiseLite instance
func test_initialization_with_fast_noise_lite() -> void:
	assert_not_null(_shake_helper, "ScreenShake helper should be initialized")
	# We can't directly access _noise (private), but we can verify behavior
	# by checking that calculate_shake produces noise-based results
	var result = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	assert_not_null(result, "calculate_shake should return a result")


# Test 2: calculate_shake returns ShakeResult instance
func test_calculate_shake_returns_shake_result_instance() -> void:
	var result = _shake_helper.calculate_shake(0.5, 1.0, 0.016)
	assert_true(result is ShakeResult, "calculate_shake should return ShakeResult")


# Test 3: Result has offset field with Vector2 value
func test_result_has_offset_field() -> void:
	var result = _shake_helper.calculate_shake(0.5, 1.0, 0.016)
	assert_true(result.offset is Vector2, "Offset should be Vector2")


# Test 4: Result has rotation field with float value
func test_result_has_rotation_field() -> void:
	var result = _shake_helper.calculate_shake(0.5, 1.0, 0.016)
	assert_true(result.rotation is float, "Rotation should be float")


# Test 5: Trauma 0.0 produces zero offset
func test_trauma_zero_produces_zero_offset() -> void:
	var result = _shake_helper.calculate_shake(0.0, 1.0, 0.016)
	var offset: Vector2 = result.offset
	assert_almost_eq(offset.x, 0.0, 0.01, "Offset X should be ~0 with trauma 0.0")
	assert_almost_eq(offset.y, 0.0, 0.01, "Offset Y should be ~0 with trauma 0.0")


# Test 6: Trauma 0.0 produces zero rotation
func test_trauma_zero_produces_zero_rotation() -> void:
	var result = _shake_helper.calculate_shake(0.0, 1.0, 0.016)
	var rotation: float = result.rotation
	assert_almost_eq(rotation, 0.0, 0.01, "Rotation should be ~0 with trauma 0.0")


# Test 7: Trauma 1.0 produces full shake (offset within max bounds)
func test_trauma_one_produces_full_shake() -> void:
	# Set deterministic seed to avoid flakiness
	_shake_helper.set_noise_seed_for_testing(42)
	var result = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	var offset: Vector2 = result.offset
	# With trauma 1.0 and multiplier 1.0, offset should be within max bounds
	# max_offset defaults to (10.0, 8.0)
	assert_true(abs(offset.x) <= 10.0, "Offset X should be within max bounds")
	assert_true(abs(offset.y) <= 8.0, "Offset Y should be within max bounds")
	# Should NOT be zero (noise produces values)
	assert_true(offset.length() > 0.1, "Offset should be non-zero with trauma 1.0")


# Test 8: Trauma 1.0 produces full rotation (within max bounds)
func test_trauma_one_produces_full_rotation() -> void:
	# Set deterministic seed to avoid flakiness
	_shake_helper.set_noise_seed_for_testing(42)
	var result = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	var rotation: float = result.rotation
	# max_rotation defaults to 0.05 radians
	assert_true(abs(rotation) <= 0.05, "Rotation should be within max bounds")
	# Should NOT be zero (noise produces values)
	assert_true(abs(rotation) > 0.001, "Rotation should be non-zero with trauma 1.0")


# Test 9: Quadratic falloff (trauma 0.5 → shake_amount 0.25)
func test_quadratic_falloff() -> void:
	# With trauma 0.5, shake_amount should be 0.5 * 0.5 = 0.25
	# This means the shake should be ~25% of max intensity
	# Use separate helpers with same seed to get consistent noise samples
	var helper_half := M_ScreenShake.new()
	var helper_full := M_ScreenShake.new()

	# Set same seed for consistent comparison
	helper_half.set_noise_seed_for_testing(12345)
	helper_full.set_noise_seed_for_testing(12345)

	var result_half = helper_half.calculate_shake(0.5, 1.0, 0.016)
	var result_full = helper_full.calculate_shake(1.0, 1.0, 0.016)

	var offset_half: Vector2 = result_half.offset
	var offset_full: Vector2 = result_full.offset

	# The ratio should be approximately 0.25 (quadratic falloff)
	# With same noise samples, the ratio should be very close to trauma^2
	var ratio: float = offset_half.length() / offset_full.length() if offset_full.length() > 0 else 0.0
	assert_almost_eq(ratio, 0.25, 0.05, "Trauma 0.5 should produce ~25% intensity (quadratic)")


# Test 10: settings_multiplier scales offset
func test_settings_multiplier_scales_offset() -> void:
	# Use separate helpers with same seed to get consistent noise samples
	var helper_normal := M_ScreenShake.new()
	var helper_doubled := M_ScreenShake.new()

	# Set same seed for consistent comparison
	helper_normal.set_noise_seed_for_testing(54321)
	helper_doubled.set_noise_seed_for_testing(54321)

	var result_normal = helper_normal.calculate_shake(1.0, 1.0, 0.016)
	var result_doubled = helper_doubled.calculate_shake(1.0, 2.0, 0.016)

	var offset_normal: Vector2 = result_normal.offset
	var offset_doubled: Vector2 = result_doubled.offset

	# Doubled multiplier should produce ~2x offset
	var ratio: float = offset_doubled.length() / offset_normal.length() if offset_normal.length() > 0 else 0.0
	assert_almost_eq(ratio, 2.0, 0.05, "Multiplier 2.0 should double offset magnitude")


# Test 11: settings_multiplier scales rotation
func test_settings_multiplier_scales_rotation() -> void:
	# Use separate helpers with same seed to get consistent noise samples
	var helper_normal := M_ScreenShake.new()
	var helper_doubled := M_ScreenShake.new()

	# Set same seed for consistent comparison
	helper_normal.set_noise_seed_for_testing(67890)
	helper_doubled.set_noise_seed_for_testing(67890)

	var result_normal = helper_normal.calculate_shake(1.0, 1.0, 0.016)
	var result_doubled = helper_doubled.calculate_shake(1.0, 2.0, 0.016)

	var rotation_normal: float = result_normal.rotation
	var rotation_doubled: float = result_doubled.rotation

	# Doubled multiplier should produce ~2x rotation
	var ratio: float = abs(rotation_doubled) / abs(rotation_normal) if abs(rotation_normal) > 0 else 0.0
	assert_almost_eq(ratio, 2.0, 0.05, "Multiplier 2.0 should double rotation magnitude")


# Test 12: Noise-based randomness produces different offsets over time
func test_noise_produces_different_offsets() -> void:
	var result1 = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	var result2 = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	var result3 = _shake_helper.calculate_shake(1.0, 1.0, 0.016)

	var offset1: Vector2 = result1.offset
	var offset2: Vector2 = result2.offset
	var offset3: Vector2 = result3.offset

	# Offsets should be different (noise advances over time)
	assert_true(offset1.distance_to(offset2) > 0.1, "Offsets should differ over time")
	assert_true(offset2.distance_to(offset3) > 0.1, "Offsets should differ over time")


# Test 13: Noise-based randomness produces different rotations over time
func test_noise_produces_different_rotations() -> void:
	var result1 = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	var result2 = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	var result3 = _shake_helper.calculate_shake(1.0, 1.0, 0.016)

	var rotation1: float = result1.rotation
	var rotation2: float = result2.rotation
	var rotation3: float = result3.rotation

	# Rotations should be different (noise advances over time)
	assert_true(abs(rotation1 - rotation2) > 0.001, "Rotations should differ over time")
	assert_true(abs(rotation2 - rotation3) > 0.001, "Rotations should differ over time")


# Test 14: Offset respects max_offset bounds
func test_max_offset_clamping() -> void:
	# Test with extreme trauma and multiplier
	for i in range(10):
		var result = _shake_helper.calculate_shake(1.0, 10.0, 0.016)
		var offset: Vector2 = result.offset

		# max_offset defaults to (10.0, 8.0), multiplier is 10.0
		# So max possible offset is (100.0, 80.0)
		assert_true(abs(offset.x) <= 100.0, "Offset X should not exceed max_offset * multiplier")
		assert_true(abs(offset.y) <= 80.0, "Offset Y should not exceed max_offset * multiplier")


# Test 15: Rotation respects max_rotation bounds
func test_max_rotation_clamping() -> void:
	# Test with extreme trauma and multiplier
	for i in range(10):
		var result = _shake_helper.calculate_shake(1.0, 10.0, 0.016)
		var rotation: float = result.rotation

		# max_rotation defaults to 0.05 radians, multiplier is 10.0
		# So max possible rotation is 0.5 radians
		assert_true(abs(rotation) <= 0.5, "Rotation should not exceed max_rotation * multiplier")


# Test 16: set_noise_seed_for_testing produces deterministic results
func test_set_noise_seed_for_testing_makes_deterministic() -> void:
	var helper_a := M_ScreenShake.new()
	var helper_b := M_ScreenShake.new()

	helper_a.set_noise_seed_for_testing(13579)
	helper_b.set_noise_seed_for_testing(13579)

	var result_a = helper_a.calculate_shake(1.0, 1.0, 0.016)
	var result_b = helper_b.calculate_shake(1.0, 1.0, 0.016)

	assert_almost_eq(result_a.offset.x, result_b.offset.x, 0.0001, "Offset X should match for same seed")
	assert_almost_eq(result_a.offset.y, result_b.offset.y, 0.0001, "Offset Y should match for same seed")
	assert_almost_eq(result_a.rotation, result_b.rotation, 0.0001, "Rotation should match for same seed")


# Test 17: set_sample_time_for_testing freezes time
func test_set_sample_time_for_testing_freezes_time() -> void:
	_shake_helper.set_noise_seed_for_testing(24680)
	_shake_helper.set_sample_time_for_testing(2.5)

	var result1 = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	var result2 = _shake_helper.calculate_shake(1.0, 1.0, 0.5)

	assert_almost_eq(result1.offset.x, result2.offset.x, 0.0001, "Offset X should stay fixed when time is frozen")
	assert_almost_eq(result1.offset.y, result2.offset.y, 0.0001, "Offset Y should stay fixed when time is frozen")
	assert_almost_eq(result1.rotation, result2.rotation, 0.0001, "Rotation should stay fixed when time is frozen")


# Test 18: get_sample_time returns current time
func test_get_sample_time_returns_current_time() -> void:
	_shake_helper.set_sample_time_for_testing(3.25)
	_shake_helper.calculate_shake(1.0, 1.0, 0.016)

	assert_almost_eq(_shake_helper.get_sample_time(), 3.25, 0.0001, "get_sample_time should return the current time")


# Test 19: Same seed produces identical shake results
func test_same_seed_produces_same_results() -> void:
	var helper_a := M_ScreenShake.new()
	var helper_b := M_ScreenShake.new()

	helper_a.set_noise_seed_for_testing(112233)
	helper_b.set_noise_seed_for_testing(112233)
	helper_a.set_sample_time_for_testing(4.5)
	helper_b.set_sample_time_for_testing(4.5)

	var result_a: ShakeResult = helper_a.calculate_shake(1.0, 1.0, 0.016)
	var result_b: ShakeResult = helper_b.calculate_shake(1.0, 1.0, 0.016)

	assert_almost_eq(result_a.offset.x, result_b.offset.x, 0.0001, "Offset X should match for same seed")
	assert_almost_eq(result_a.offset.y, result_b.offset.y, 0.0001, "Offset Y should match for same seed")
	assert_almost_eq(result_a.rotation, result_b.rotation, 0.0001, "Rotation should match for same seed")


# Test 20: Different seeds produce different shake results
func test_different_seeds_produce_different_results() -> void:
	var helper_a := M_ScreenShake.new()
	var helper_b := M_ScreenShake.new()

	helper_a.set_noise_seed_for_testing(1)
	helper_b.set_noise_seed_for_testing(2)
	helper_a.set_sample_time_for_testing(4.5)
	helper_b.set_sample_time_for_testing(4.5)

	var result_a: ShakeResult = helper_a.calculate_shake(1.0, 1.0, 0.016)
	var result_b: ShakeResult = helper_b.calculate_shake(1.0, 1.0, 0.016)

	var offset_delta: float = result_a.offset.distance_to(result_b.offset)
	var rotation_delta: float = absf(result_a.rotation - result_b.rotation)
	assert_true(offset_delta > 0.0001 or rotation_delta > 0.0001,
		"Different seeds should produce different shake results")


# Test 21: Frozen time produces identical shake results
func test_frozen_time_produces_same_results() -> void:
	_shake_helper.set_noise_seed_for_testing(13579)
	_shake_helper.set_sample_time_for_testing(2.75)

	var result1: ShakeResult = _shake_helper.calculate_shake(1.0, 1.0, 0.016)
	var result2: ShakeResult = _shake_helper.calculate_shake(1.0, 1.0, 0.5)

	assert_almost_eq(result1.offset.x, result2.offset.x, 0.0001, "Offset X should stay fixed when time is frozen")
	assert_almost_eq(result1.offset.y, result2.offset.y, 0.0001, "Offset Y should stay fixed when time is frozen")
	assert_almost_eq(result1.rotation, result2.rotation, 0.0001, "Rotation should stay fixed when time is frozen")
