extends BaseTest

const S_FLOATING_SYSTEM := preload("res://scripts/core/ecs/systems/s_floating_system.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Simulates N frames of the spring and returns how many times the body
## crosses the hover target (height_error sign changes from positive to
## negative, i.e. overshoots from below).
func _count_overshoots(
	initial_height_error: float,
	initial_vel: float,
	frequency: float,
	damping_ratio: float,
	frames: int,
	delta: float
) -> int:
	var height_error := initial_height_error
	var vel := initial_vel
	var overshoots := 0
	var was_below := height_error > 0.0

	for _i in range(frames):
		var accel := S_FLOATING_SYSTEM.compute_spring_accel(height_error, vel, frequency, damping_ratio)
		vel += accel * delta
		height_error -= vel * delta  # moving up (vel>0) reduces height_error
		var is_below := height_error > 0.0
		if was_below and not is_below:
			overshoots += 1
		was_below = is_below

	return overshoots

# ---------------------------------------------------------------------------
# Directional correctness (these should pass before and after the fix)
# ---------------------------------------------------------------------------

func test_spring_pushes_up_when_below_target() -> void:
	# height_error > 0 means body is below target → expect upward acceleration
	var accel := S_FLOATING_SYSTEM.compute_spring_accel(0.5, 0.0, 3.0, 1.0)
	assert_gt(accel, 0.0, "spring should push up when body is below target")

func test_spring_pushes_down_when_above_target() -> void:
	# height_error < 0 means body is above target → expect downward acceleration
	var accel := S_FLOATING_SYSTEM.compute_spring_accel(-0.5, 0.0, 3.0, 1.0)
	assert_lt(accel, 0.0, "spring should push down when body is above target")

func test_zero_frequency_returns_zero() -> void:
	var accel := S_FLOATING_SYSTEM.compute_spring_accel(1.0, 1.0, 0.0, 1.0)
	assert_eq(accel, 0.0, "zero frequency should return zero acceleration")

# ---------------------------------------------------------------------------
# Damping correctness — these FAIL on the buggy implementation
# ---------------------------------------------------------------------------

func test_spring_damps_upward_velocity_exactly_at_target() -> void:
	# Body is exactly at hover height (height_error = 0) but moving upward.
	# The spring restoring force is zero; only damping should act.
	# Expected: negative accel (decelerate the body).
	# Bug: the clamp zeros this out → accel = 0.
	var accel := S_FLOATING_SYSTEM.compute_spring_accel(0.0, 1.0, 3.0, 1.0)
	assert_lt(accel, 0.0,
		"damping must decelerate upward motion at target height (accel was %.4f)" % accel)

func test_spring_damps_when_damping_dominates_near_target() -> void:
	# Body is just below target (height_error = 0.02) moving upward fast (vel = 3.0).
	# The damping term dominates: combined accel should be negative so the body decelerates.
	# Bug: because height_error >= 0 and combined accel < 0, it gets clamped to 0.
	var accel := S_FLOATING_SYSTEM.compute_spring_accel(0.02, 3.0, 3.0, 1.0)
	assert_lt(accel, 0.0,
		"damping must win over spring when velocity is high near target (accel was %.4f)" % accel)

# ---------------------------------------------------------------------------
# Simulation — critically damped spring should not overshoot
# ---------------------------------------------------------------------------

func test_critically_damped_spring_does_not_overshoot() -> void:
	# Starting 0.5 units below target, zero initial velocity.
	# A critically damped (ratio = 1.0) spring must converge without crossing
	# the target more than once. Bug causes repeated oscillation.
	var overshoots := _count_overshoots(0.5, 0.0, 3.0, 1.0, 240, 1.0 / 60.0)
	assert_eq(overshoots, 0,
		"critically damped spring must not overshoot the hover target (overshoots=%d)" % overshoots)

func test_overdamped_spring_does_not_overshoot() -> void:
	# Damping ratio > 1 → overdamped; must definitely not overshoot.
	var overshoots := _count_overshoots(0.5, 0.0, 3.0, 2.0, 240, 1.0 / 60.0)
	assert_eq(overshoots, 0,
		"overdamped spring must not overshoot the hover target (overshoots=%d)" % overshoots)
