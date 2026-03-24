extends GutTest

const DYNAMICS_3D_SCRIPT := preload("res://scripts/utils/math/u_second_order_dynamics_3d.gd")

func _step_many(dynamics: Variant, target: Vector3, dt: float, steps: int) -> Vector3:
	var output: Vector3 = dynamics.get_value()
	for _i in range(steps):
		output = dynamics.step(target, dt)
	return output

func test_initial_state_matches_initial_vector() -> void:
	var initial := Vector3(1.0, -2.0, 3.0)
	var dynamics := DYNAMICS_3D_SCRIPT.new(2.0, 1.0, 1.0, initial)
	assert_eq(dynamics.get_value(), initial)

func test_step_moves_toward_target_vector() -> void:
	var dynamics := DYNAMICS_3D_SCRIPT.new(2.0, 1.0, 1.0, Vector3.ZERO)
	var output: Vector3 = _step_many(dynamics, Vector3(5.0, -4.0, 3.0), 1.0 / 60.0, 10)
	assert_true(output.x > 0.0 and output.x < 5.0)
	assert_true(output.y < 0.0 and output.y > -4.0)
	assert_true(output.z > 0.0 and output.z < 3.0)

func test_converges_each_axis_to_target() -> void:
	var target := Vector3(5.0, -4.0, 3.0)
	var dynamics := DYNAMICS_3D_SCRIPT.new(2.0, 1.0, 1.0, Vector3.ZERO)
	var output: Vector3 = _step_many(dynamics, target, 1.0 / 60.0, 600)
	assert_almost_eq(output.x, target.x, 0.05)
	assert_almost_eq(output.y, target.y, 0.05)
	assert_almost_eq(output.z, target.z, 0.05)

func test_axes_are_independent() -> void:
	var initial := Vector3(0.0, 2.0, -3.0)
	var dynamics := DYNAMICS_3D_SCRIPT.new(2.0, 1.0, 1.0, initial)
	var output: Vector3 = _step_many(dynamics, Vector3(10.0, 2.0, -3.0), 1.0 / 60.0, 120)
	assert_true(output.x > 0.0)
	assert_almost_eq(output.y, 2.0, 0.0001)
	assert_almost_eq(output.z, -3.0, 0.0001)

func test_reset_snaps_all_axes() -> void:
	var dynamics := DYNAMICS_3D_SCRIPT.new(2.0, 1.0, 1.0, Vector3.ZERO)
	_step_many(dynamics, Vector3(9.0, 9.0, 9.0), 1.0 / 60.0, 30)
	dynamics.reset(Vector3(1.0, 2.0, 3.0))
	assert_eq(dynamics.get_value(), Vector3(1.0, 2.0, 3.0))

func test_critically_damped_motion_no_overshoot_on_all_axes() -> void:
	var dynamics := DYNAMICS_3D_SCRIPT.new(2.0, 1.0, 1.0, Vector3.ZERO)
	var max_output := Vector3(-INF, -INF, -INF)
	var output := Vector3.ZERO
	for _i in range(600):
		output = dynamics.step(Vector3.ONE, 1.0 / 60.0)
		max_output.x = maxf(max_output.x, output.x)
		max_output.y = maxf(max_output.y, output.y)
		max_output.z = maxf(max_output.z, output.z)
	assert_true(max_output.x <= 1.001 and max_output.y <= 1.001 and max_output.z <= 1.001)
	assert_almost_eq(output.x, 1.0, 0.02)
	assert_almost_eq(output.y, 1.0, 0.02)
	assert_almost_eq(output.z, 1.0, 0.02)

func test_under_damped_overshoots_on_all_axes() -> void:
	var dynamics := DYNAMICS_3D_SCRIPT.new(2.0, 0.3, 1.0, Vector3.ZERO)
	var max_output := Vector3(-INF, -INF, -INF)
	var output := Vector3.ZERO
	for _i in range(600):
		output = dynamics.step(Vector3.ONE, 1.0 / 60.0)
		max_output.x = maxf(max_output.x, output.x)
		max_output.y = maxf(max_output.y, output.y)
		max_output.z = maxf(max_output.z, output.z)
	assert_true(max_output.x > 1.01 and max_output.y > 1.01 and max_output.z > 1.01)
	assert_almost_eq(output.x, 1.0, 0.05)
	assert_almost_eq(output.y, 1.0, 0.05)
	assert_almost_eq(output.z, 1.0, 0.05)

