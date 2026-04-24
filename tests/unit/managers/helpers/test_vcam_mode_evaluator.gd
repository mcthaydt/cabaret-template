extends GutTest

const EVALUATOR_SCRIPT := preload("res://scripts/core/managers/helpers/u_vcam_mode_evaluator.gd")
const MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")

func _new_mode() -> Resource:
	return MODE_SCRIPT.new()

func _new_follow_target(position: Vector3 = Vector3.ZERO) -> Node3D:
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	follow_target.global_position = position
	return follow_target

func _assert_basis_matches(lhs: Basis, rhs: Basis, epsilon: float = 0.001) -> void:
	assert_almost_eq(lhs.x.normalized().dot(rhs.x.normalized()), 1.0, epsilon)
	assert_almost_eq(lhs.y.normalized().dot(rhs.y.normalized()), 1.0, epsilon)
	assert_almost_eq(lhs.z.normalized().dot(rhs.z.normalized()), 1.0, epsilon)

func _compute_expected_offset(distance: float, pitch_deg: float, yaw_deg: float) -> Vector3:
	var pitch_rad: float = deg_to_rad(pitch_deg)
	var yaw_rad: float = deg_to_rad(yaw_deg)
	return Vector3(
		distance * cos(pitch_rad) * sin(yaw_rad),
		-distance * sin(pitch_rad),
		distance * cos(pitch_rad) * cos(yaw_rad)
	)

func test_orbit_returns_transform() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_true(result.has("transform"))
	var transform_value: Variant = result.get("transform")
	assert_true(transform_value is Transform3D)

func test_orbit_returns_fov_from_mode() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_almost_eq(float(result.get("fov", 0.0)), 75.0, 0.0001)

func test_orbit_returns_mode_name() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_eq(String(result.get("mode_name", "")), "orbit")

func test_orbit_position_matches_spherical_offset() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(1.0, 2.0, 3.0))
	var mode: Resource = _new_mode()
	mode.set("distance", 5.0)
	mode.set("authored_pitch", -20.0)
	mode.set("authored_yaw", 0.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected_position: Vector3 = follow_target.global_position + _compute_expected_offset(5.0, -20.0, 0.0)

	assert_almost_eq(camera_transform.origin.x, expected_position.x, 0.001)
	assert_almost_eq(camera_transform.origin.y, expected_position.y, 0.001)
	assert_almost_eq(camera_transform.origin.z, expected_position.z, 0.001)

func test_orbit_camera_looks_at_follow_target() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(0.0, 0.0, 0.0))
	var mode: Resource = _new_mode()
	mode.set("distance", 5.0)
	mode.set("authored_pitch", -20.0)
	mode.set("authored_yaw", 30.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var camera_forward: Vector3 = -camera_transform.basis.z.normalized()
	var to_target: Vector3 = (follow_target.global_position - camera_transform.origin).normalized()

	assert_almost_eq(camera_forward.dot(to_target), 1.0, 0.001)

func test_orbit_applies_runtime_rotation_when_enabled() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()
	mode.set("distance", 5.0)
	mode.set("authored_pitch", -20.0)
	mode.set("authored_yaw", 0.0)
	mode.set("allow_player_rotation", true)
	mode.set("lock_y_rotation", false)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 90.0, -10.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected_position: Vector3 = _compute_expected_offset(5.0, -30.0, 90.0)

	assert_almost_eq(camera_transform.origin.x, expected_position.x, 0.001)
	assert_almost_eq(camera_transform.origin.y, expected_position.y, 0.001)
	assert_almost_eq(camera_transform.origin.z, expected_position.z, 0.001)

func test_orbit_lock_x_rotation_ignores_runtime_yaw() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()
	mode.set("distance", 5.0)
	mode.set("authored_pitch", -20.0)
	mode.set("authored_yaw", 15.0)
	mode.set("allow_player_rotation", true)
	mode.set("lock_x_rotation", true)
	mode.set("lock_y_rotation", false)

	var with_runtime: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 90.0, -10.0)
	var expected_position: Vector3 = _compute_expected_offset(5.0, -30.0, 15.0)
	var camera_transform: Transform3D = with_runtime.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(camera_transform.origin.x, expected_position.x, 0.001)
	assert_almost_eq(camera_transform.origin.y, expected_position.y, 0.001)
	assert_almost_eq(camera_transform.origin.z, expected_position.z, 0.001)

func test_orbit_lock_y_rotation_ignores_runtime_pitch() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()
	mode.set("distance", 5.0)
	mode.set("authored_pitch", -20.0)
	mode.set("authored_yaw", 10.0)
	mode.set("allow_player_rotation", true)
	mode.set("lock_x_rotation", false)
	mode.set("lock_y_rotation", true)

	var with_runtime: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 30.0, -25.0)
	var expected_position: Vector3 = _compute_expected_offset(5.0, -20.0, 40.0)
	var camera_transform: Transform3D = with_runtime.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(camera_transform.origin.x, expected_position.x, 0.001)
	assert_almost_eq(camera_transform.origin.y, expected_position.y, 0.001)
	assert_almost_eq(camera_transform.origin.z, expected_position.z, 0.001)

func test_orbit_ignores_runtime_rotation_when_disabled() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()
	mode.set("distance", 5.0)
	mode.set("authored_pitch", -20.0)
	mode.set("authored_yaw", 15.0)
	mode.set("allow_player_rotation", false)

	var with_runtime: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 90.0, -10.0)
	var without_runtime: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)
	var with_runtime_transform: Transform3D = with_runtime.get("transform", Transform3D.IDENTITY) as Transform3D
	var without_runtime_transform: Transform3D = without_runtime.get("transform", Transform3D.IDENTITY) as Transform3D
	var position_delta: float = with_runtime_transform.origin.distance_to(without_runtime_transform.origin)
	var forward_dot: float = (-with_runtime_transform.basis.z).normalized().dot((-without_runtime_transform.basis.z).normalized())

	assert_almost_eq(position_delta, 0.0, 0.001)
	assert_almost_eq(forward_dot, 1.0, 0.001)

func test_orbit_returns_empty_result_when_distance_is_zero() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()
	mode.set("distance", 0.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_eq(result.size(), 0)

func test_orbit_returns_empty_result_when_distance_resolves_non_positive() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()
	mode.set("distance", -5.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_eq(result.size(), 0)

func test_orbit_uses_resolved_fov_when_authored_fov_is_invalid() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_mode()
	mode.set("fov", 180.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_almost_eq(float(result.get("fov", 0.0)), 179.0, 0.0001)

func test_orbit_returns_empty_result_when_follow_target_is_null() -> void:
	var mode: Resource = _new_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, null, null, 0.0, 0.0)

	assert_eq(result.size(), 0)

func test_orbit_returns_empty_result_when_mode_is_null() -> void:
	var follow_target: Node3D = _new_follow_target()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(null, follow_target, null, 0.0, 0.0)

	assert_eq(result.size(), 0)

func test_unsupported_mode_returns_empty_result() -> void:
	var follow_target: Node3D = _new_follow_target()
	var unsupported_mode := Resource.new()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(unsupported_mode, follow_target, null, 0.0, 0.0)

	assert_eq(result.size(), 0)
