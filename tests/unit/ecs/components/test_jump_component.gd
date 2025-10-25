extends BaseTest

const JumpComponentScript = preload("res://scripts/ecs/components/c_jump_component.gd")
const JumpSettingsScript = preload("res://scripts/ecs/resources/rs_jump_settings.gd")
const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

func _create_jump_component(min_fall_height: float = 0.5) -> C_JumpComponent:
	var component := JumpComponentScript.new()
	var settings := JumpSettingsScript.new()
	settings.min_landing_fall_height = min_fall_height
	component.settings = settings
	return component

# Fall Distance Filter Tests

func test_landing_with_sufficient_fall_distance_triggers() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0
	var start_height := 1.0
	var peak_height := 3.0  # Jumped 2m high
	var land_height := 1.0

	# Simulate becoming airborne
	component.check_landing_transition(false, now, start_height)

	# Simulate airborne period with peak
	component.check_landing_transition(false, now + 0.05, peak_height)
	component.check_landing_transition(false, now + 0.1, peak_height - 0.5)

	# Landing - fall distance = 3.0 - 1.0 = 2.0m (> 0.5m threshold)
	var landed := component.check_landing_transition(true, now + 0.15, land_height)

	assert_true(landed, "Landing with 2.0m fall should trigger")

func test_landing_with_insufficient_fall_distance_blocked() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0
	var start_height := 1.0
	var peak_height := 1.2  # Only 0.2m bounce (ramp oscillation)
	var land_height := 1.0

	# Simulate becoming airborne
	component.check_landing_transition(false, now, start_height)

	# Simulate airborne period with small peak
	component.check_landing_transition(false, now + 0.05, peak_height)

	# Landing - fall distance = 1.2 - 1.0 = 0.2m (< 0.5m threshold)
	var landed := component.check_landing_transition(true, now + 0.1, land_height)

	assert_false(landed, "Landing with 0.2m fall should be blocked (ramp bounce)")

func test_landing_exactly_at_threshold_triggers() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0
	var start_height := 1.0
	var peak_height := 1.5  # Exactly 0.5m
	var land_height := 1.0

	# Simulate becoming airborne
	component.check_landing_transition(false, now, start_height)

	# Simulate airborne period
	component.check_landing_transition(false, now + 0.05, peak_height)

	# Landing - fall distance = 1.5 - 1.0 = 0.5m (exactly at threshold)
	var landed := component.check_landing_transition(true, now + 0.1, land_height)

	assert_true(landed, "Landing with exactly 0.5m fall should trigger")

func test_landing_just_below_threshold_blocked() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0
	var start_height := 1.0
	var peak_height := 1.49  # Just below 0.5m
	var land_height := 1.0

	# Simulate becoming airborne
	component.check_landing_transition(false, now, start_height)

	# Simulate airborne period
	component.check_landing_transition(false, now + 0.05, peak_height)

	# Landing - fall distance = 1.49 - 1.0 = 0.49m (< 0.5m threshold)
	var landed := component.check_landing_transition(true, now + 0.1, land_height)

	assert_false(landed, "Landing with 0.49m fall should be blocked")

# Peak Height Tracking Tests

func test_peak_height_tracks_highest_point_during_airborne() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# Simulate becoming airborne
	component.check_landing_transition(false, now, 1.0)

	# Simulate jump arc: going up, reaching peak, falling down
	component.check_landing_transition(false, now + 0.05, 2.0)
	component.check_landing_transition(false, now + 0.1, 3.0)  # Peak
	component.check_landing_transition(false, now + 0.15, 2.5)
	component.check_landing_transition(false, now + 0.2, 1.5)

	# Landing - should use peak (3.0), not intermediate heights
	# Fall distance = 3.0 - 1.0 = 2.0m
	var landed := component.check_landing_transition(true, now + 0.25, 1.0)

	assert_true(landed, "Should track peak height (3.0m) not intermediate values")

func test_peak_height_resets_on_next_airborne_period() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# First jump cycle
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.05, 3.0)  # High peak
	component.check_landing_transition(true, now + 0.1, 1.0)    # Land

	# Wait for cooldown
	now += 0.15

	# Second jump cycle with lower peak
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.05, 1.6)  # Lower peak (0.6m)
	var landed := component.check_landing_transition(true, now + 0.1, 1.0)

	# Should use new peak (1.6m), not old peak (3.0m)
	# Fall distance = 1.6 - 1.0 = 0.6m (> 0.5m)
	assert_true(landed, "Peak should reset between jumps, not use previous peak")

# Cooldown Tests

func test_landing_cooldown_prevents_duplicate_events() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# First landing
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.05, 2.0)
	var first_land := component.check_landing_transition(true, now + 0.1, 1.0)
	assert_true(first_land, "First landing should succeed")

	# Immediate second landing (within 0.1s cooldown)
	component.check_landing_transition(false, now + 0.11, 1.0)
	component.check_landing_transition(false, now + 0.12, 2.0)
	var second_land := component.check_landing_transition(true, now + 0.15, 1.0)

	assert_false(second_land, "Second landing within cooldown should be blocked")

func test_landing_after_cooldown_expires_succeeds() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# First landing
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.05, 2.0)
	var first_land := component.check_landing_transition(true, now + 0.1, 1.0)
	assert_true(first_land, "First landing should succeed")

	# Wait for cooldown to expire (0.1s + buffer)
	now += 0.15

	# Second landing after cooldown
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.05, 2.0)
	var second_land := component.check_landing_transition(true, now + 0.1, 1.0)

	assert_true(second_land, "Landing after cooldown expires should succeed")

# Minimum Airborne Time Tests

func test_minimum_airborne_time_required() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# Very brief airborne period (< 0.02s minimum)
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.005, 2.0)  # Peak
	var landed := component.check_landing_transition(true, now + 0.01, 1.0)

	assert_false(landed, "Landing with < 0.02s airborne should be blocked")

func test_landing_after_minimum_airborne_time_succeeds() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# Airborne period > 0.02s minimum
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.01, 2.0)
	component.check_landing_transition(false, now + 0.02, 2.0)  # Peak
	var landed := component.check_landing_transition(true, now + 0.03, 1.0)

	assert_true(landed, "Landing with > 0.02s airborne should succeed")

# Configurable Threshold Tests

func test_custom_fall_threshold_respected() -> void:
	var component := _create_jump_component(1.0)  # Higher threshold
	autofree(component)

	var now := 1.0

	# Fall of 0.8m (would pass 0.5m threshold, but not 1.0m)
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.05, 1.8)  # Peak
	var landed := component.check_landing_transition(true, now + 0.1, 1.0)

	assert_false(landed, "0.8m fall should be blocked with 1.0m threshold")

func test_custom_fall_threshold_higher_fall_passes() -> void:
	var component := _create_jump_component(1.0)  # Higher threshold
	autofree(component)

	var now := 1.0

	# Fall of 1.5m (passes 1.0m threshold)
	component.check_landing_transition(false, now, 1.0)
	component.check_landing_transition(false, now + 0.05, 2.5)  # Peak
	var landed := component.check_landing_transition(true, now + 0.1, 1.0)

	assert_true(landed, "1.5m fall should pass 1.0m threshold")

# Edge Case Tests

func test_landing_from_falling_without_upward_jump() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# Start high and fall down (no upward jump)
	component.check_landing_transition(false, now, 5.0)        # Start at 5m
	component.check_landing_transition(false, now + 0.05, 4.5)
	component.check_landing_transition(false, now + 0.1, 4.0)
	var landed := component.check_landing_transition(true, now + 0.15, 3.0)

	# Fall distance = 5.0 - 3.0 = 2.0m
	assert_true(landed, "Falling from height without jumping should trigger landing")

func test_landing_at_lower_elevation_than_takeoff() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# Jump from platform and land below takeoff point
	component.check_landing_transition(false, now, 5.0)        # Takeoff at 5m
	component.check_landing_transition(false, now + 0.05, 6.0) # Peak at 6m
	component.check_landing_transition(false, now + 0.1, 5.0)
	var landed := component.check_landing_transition(true, now + 0.15, 3.0)  # Land at 3m

	# Fall distance = 6.0 - 3.0 = 3.0m
	assert_true(landed, "Landing below takeoff height should use peak for calculation")

func test_multiple_airborne_transitions_before_landing() -> void:
	var component := _create_jump_component(0.5)
	autofree(component)

	var now := 1.0

	# Simulate multiple state checks while airborne
	component.check_landing_transition(false, now, 1.0)
	for i in range(10):
		component.check_landing_transition(false, now + i * 0.01, 2.0 + i * 0.1)

	# Land after extended airborne period
	var landed := component.check_landing_transition(true, now + 0.15, 1.0)

	# Peak should be around 3.0m, fall distance ~2.0m
	assert_true(landed, "Extended airborne period with many checks should still track peak")
