extends GutTest

const DYNAMICS_SCRIPT := preload("res://scripts/utils/math/u_second_order_dynamics.gd")

func _step_many(dynamics: Variant, target: float, dt: float, steps: int) -> float:
	var output: float = dynamics.get_value()
	for _i in range(steps):
		output = dynamics.step(target, dt)
	return output

func test_initial_state_matches_initial_value() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 1.0, 1.0, 5.0)
	assert_almost_eq(dynamics.get_value(), 5.0, 0.0001)
	assert_almost_eq(dynamics.get_velocity(), 0.0, 0.0001)

func test_step_moves_toward_target() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 1.0, 1.0, 0.0)
	var output: float = _step_many(dynamics, 10.0, 1.0 / 60.0, 10)
	assert_true(output > 0.0)
	assert_true(output < 10.0)

func test_converges_to_target_after_many_steps() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 1.0, 1.0, 0.0)
	var output: float = _step_many(dynamics, 10.0, 1.0 / 60.0, 600)
	assert_almost_eq(output, 10.0, 0.05)

func test_critically_damped_does_not_overshoot() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 1.0, 1.0, 0.0)
	var max_output: float = -INF
	var output: float = 0.0
	for _i in range(600):
		output = dynamics.step(1.0, 1.0 / 60.0)
		max_output = maxf(max_output, output)
	assert_true(max_output <= 1.001)
	assert_almost_eq(output, 1.0, 0.02)

func test_under_damped_overshoots_then_settles() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 0.3, 1.0, 0.0)
	var max_output: float = -INF
	var output: float = 0.0
	for _i in range(600):
		output = dynamics.step(1.0, 1.0 / 60.0)
		max_output = maxf(max_output, output)
	assert_true(max_output > 1.01)
	assert_almost_eq(output, 1.0, 0.05)

func test_over_damped_is_slower_than_critical_and_no_overshoot() -> void:
	var critical := DYNAMICS_SCRIPT.new(2.0, 1.0, 1.0, 0.0)
	var overdamped := DYNAMICS_SCRIPT.new(2.0, 2.0, 1.0, 0.0)
	var critical_output: float = _step_many(critical, 1.0, 1.0 / 60.0, 60)
	var overdamped_output: float = _step_many(overdamped, 1.0, 1.0 / 60.0, 60)
	assert_true(overdamped_output < critical_output)
	assert_true(overdamped_output <= 1.001)

func test_zero_delta_returns_current_value_unchanged() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 1.0, 1.0, 2.5)
	var output: float = dynamics.step(10.0, 0.0)
	assert_almost_eq(output, 2.5, 0.0001)
	assert_almost_eq(dynamics.get_value(), 2.5, 0.0001)
	assert_almost_eq(dynamics.get_velocity(), 0.0, 0.0001)

func test_large_delta_remains_finite_and_stable() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 0.8, 1.0, 0.0)
	var output: float = dynamics.step(100.0, 10.0)
	assert_false(is_nan(output) or is_inf(output))
	assert_false(is_nan(dynamics.get_velocity()) or is_inf(dynamics.get_velocity()))

func test_negative_frequency_is_clamped_to_minimum() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(-5.0, 1.0, 1.0, 0.0)
	var output: float = dynamics.step(1.0, 1.0 / 60.0)
	assert_false(is_nan(output) or is_inf(output))
	assert_false(is_nan(dynamics.get_velocity()) or is_inf(dynamics.get_velocity()))

func test_reset_sets_value_and_zero_velocity() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 1.0, 1.0, 0.0)
	_step_many(dynamics, 5.0, 1.0 / 60.0, 30)
	dynamics.reset(3.0)
	assert_almost_eq(dynamics.get_value(), 3.0, 0.0001)
	assert_almost_eq(dynamics.get_velocity(), 0.0, 0.0001)

func test_higher_frequency_reaches_target_faster() -> void:
	var slow := DYNAMICS_SCRIPT.new(1.0, 1.0, 1.0, 0.0)
	var fast := DYNAMICS_SCRIPT.new(5.0, 1.0, 1.0, 0.0)
	_step_many(slow, 1.0, 1.0 / 60.0, 30)
	_step_many(fast, 1.0, 1.0 / 60.0, 30)
	var slow_distance: float = absf(1.0 - slow.get_value())
	var fast_distance: float = absf(1.0 - fast.get_value())
	assert_true(fast_distance < slow_distance)

func test_initial_response_above_zero_boosts_first_step_velocity() -> void:
	var gradual := DYNAMICS_SCRIPT.new(2.0, 1.0, 0.0, 0.0)
	var immediate := DYNAMICS_SCRIPT.new(2.0, 1.0, 1.0, 0.0)
	gradual.step(1.0, 1.0 / 60.0)
	immediate.step(1.0, 1.0 / 60.0)
	assert_true(immediate.get_velocity() > gradual.get_velocity())
	assert_true(immediate.get_velocity() > 0.0)

func test_initial_response_zero_has_no_first_step_position_jump() -> void:
	var dynamics := DYNAMICS_SCRIPT.new(2.0, 1.0, 0.0, 0.0)
	var first_output: float = dynamics.step(1.0, 1.0 / 60.0)
	assert_almost_eq(first_output, 0.0, 0.000001)

