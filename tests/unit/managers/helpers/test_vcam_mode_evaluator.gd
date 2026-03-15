extends GutTest

const EVALUATOR_SCRIPT := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")
const MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const FIRST_PERSON_MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")
const OTS_MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_ots.gd")
const FIXED_MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")

func _new_mode() -> Resource:
	return MODE_SCRIPT.new()

func _new_first_person_mode() -> Resource:
	return FIRST_PERSON_MODE_SCRIPT.new()

func _new_ots_mode() -> Resource:
	return OTS_MODE_SCRIPT.new()

func _new_fixed_mode() -> Resource:
	return FIXED_MODE_SCRIPT.new()

func _new_follow_target(position: Vector3 = Vector3.ZERO) -> Node3D:
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	follow_target.global_position = position
	return follow_target

func _new_fixed_anchor(position: Vector3 = Vector3.ZERO, basis: Basis = Basis.IDENTITY) -> Node3D:
	var fixed_anchor := Node3D.new()
	add_child_autofree(fixed_anchor)
	fixed_anchor.global_transform = Transform3D(basis, position)
	return fixed_anchor

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

func _compute_expected_ots_transform(
	follow_position: Vector3,
	shoulder_offset: Vector3,
	camera_distance: float,
	runtime_yaw: float,
	runtime_pitch: float
) -> Transform3D:
	var yaw_rad: float = deg_to_rad(runtime_yaw)
	var pitch_rad: float = deg_to_rad(runtime_pitch)
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3.UP, yaw_rad)
	basis = basis.rotated(basis.x, pitch_rad)
	var rotated_offset: Vector3 = shoulder_offset.rotated(Vector3.UP, yaw_rad)
	var origin: Vector3 = follow_position + rotated_offset + (basis.z * camera_distance)
	return Transform3D(basis, origin)

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

func test_first_person_returns_transform() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(5.0, 0.0, 10.0))
	var mode: Resource = _new_first_person_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_true(result.has("transform"))
	var transform_value: Variant = result.get("transform")
	assert_true(transform_value is Transform3D)

func test_first_person_returns_fov_from_mode() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_first_person_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_almost_eq(float(result.get("fov", 0.0)), 75.0, 0.0001)

func test_first_person_returns_mode_name() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_first_person_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_eq(String(result.get("mode_name", "")), "first_person")

func test_first_person_position_uses_head_offset() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(5.0, 0.0, 10.0))
	var mode: Resource = _new_first_person_mode()
	mode.set("head_offset", Vector3(0.0, 1.7, 0.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(camera_transform.origin.x, 5.0, 0.001)
	assert_almost_eq(camera_transform.origin.y, 1.7, 0.001)
	assert_almost_eq(camera_transform.origin.z, 10.0, 0.001)

func test_first_person_applies_runtime_yaw_rotation() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(5.0, 0.0, 10.0))
	var mode: Resource = _new_first_person_mode()
	mode.set("head_offset", Vector3(0.0, 1.7, 0.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 90.0, 0.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var forward: Vector3 = -camera_transform.basis.z.normalized()
	var expected_forward: Vector3 = (Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(90.0)) * Vector3(0.0, 0.0, -1.0)).normalized()

	assert_almost_eq(forward.dot(expected_forward), 1.0, 0.001)
	assert_almost_eq(camera_transform.origin.x, 5.0, 0.001)
	assert_almost_eq(camera_transform.origin.y, 1.7, 0.001)
	assert_almost_eq(camera_transform.origin.z, 10.0, 0.001)

func test_first_person_applies_runtime_pitch_rotation() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(5.0, 0.0, 10.0))
	var mode: Resource = _new_first_person_mode()
	mode.set("head_offset", Vector3(0.0, 1.7, 0.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, -30.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var forward: Vector3 = -camera_transform.basis.z.normalized()

	assert_almost_eq(forward.y, -0.5, 0.001)
	assert_almost_eq(camera_transform.origin.x, 5.0, 0.001)
	assert_almost_eq(camera_transform.origin.y, 1.7, 0.001)
	assert_almost_eq(camera_transform.origin.z, 10.0, 0.001)

func test_first_person_clamps_pitch_to_minimum() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_first_person_mode()
	mode.set("pitch_min", -89.0)
	mode.set("pitch_max", 89.0)

	var clamped_result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, -100.0)
	var boundary_result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, -89.0)
	var clamped_transform: Transform3D = clamped_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var boundary_transform: Transform3D = boundary_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var clamped_forward: Vector3 = -clamped_transform.basis.z.normalized()
	var boundary_forward: Vector3 = -boundary_transform.basis.z.normalized()

	assert_almost_eq(clamped_forward.dot(boundary_forward), 1.0, 0.001)

func test_first_person_pitch_at_min_boundary_is_stable() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_first_person_mode()
	mode.set("pitch_min", -89.0)
	mode.set("pitch_max", 89.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, -89.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var forward: Vector3 = -camera_transform.basis.z.normalized()

	assert_almost_eq(forward.y, -sin(deg_to_rad(89.0)), 0.001)

func test_first_person_pitch_at_max_boundary_is_stable() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_first_person_mode()
	mode.set("pitch_min", -89.0)
	mode.set("pitch_max", 89.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 89.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var forward: Vector3 = -camera_transform.basis.z.normalized()

	assert_almost_eq(forward.y, sin(deg_to_rad(89.0)), 0.001)

func test_first_person_returns_empty_result_when_follow_target_is_null() -> void:
	var mode: Resource = _new_first_person_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, null, null, 0.0, 0.0)

	assert_eq(result.size(), 0)

func test_ots_returns_transform() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_ots_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_true(result.has("transform"))
	var transform_value: Variant = result.get("transform")
	assert_true(transform_value is Transform3D)

func test_ots_returns_fov_from_mode() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_ots_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_almost_eq(float(result.get("fov", 0.0)), 60.0, 0.0001)

func test_ots_returns_mode_name() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_ots_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)

	assert_eq(String(result.get("mode_name", "")), "ots")

func test_ots_position_matches_expected_offset_and_back_distance() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(5.0, 0.0, 10.0))
	var mode: Resource = _new_ots_mode()
	mode.set("shoulder_offset", Vector3(0.3, 1.6, -0.5))
	mode.set("camera_distance", 1.8)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0)
	var transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected: Transform3D = _compute_expected_ots_transform(
		follow_target.global_position,
		Vector3(0.3, 1.6, -0.5),
		1.8,
		0.0,
		0.0
	)

	assert_almost_eq(transform.origin.x, expected.origin.x, 0.001)
	assert_almost_eq(transform.origin.y, expected.origin.y, 0.001)
	assert_almost_eq(transform.origin.z, expected.origin.z, 0.001)

func test_ots_applies_runtime_yaw_rotation() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(5.0, 0.0, 10.0))
	var mode: Resource = _new_ots_mode()
	mode.set("shoulder_offset", Vector3(0.3, 1.6, -0.5))
	mode.set("camera_distance", 1.8)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 90.0, 0.0)
	var transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected: Transform3D = _compute_expected_ots_transform(
		follow_target.global_position,
		Vector3(0.3, 1.6, -0.5),
		1.8,
		90.0,
		0.0
	)

	assert_almost_eq(transform.origin.x, expected.origin.x, 0.001)
	assert_almost_eq(transform.origin.y, expected.origin.y, 0.001)
	assert_almost_eq(transform.origin.z, expected.origin.z, 0.001)
	_assert_basis_matches(transform.basis, expected.basis)

func test_ots_applies_runtime_pitch_rotation() -> void:
	var follow_target: Node3D = _new_follow_target(Vector3(5.0, 0.0, 10.0))
	var mode: Resource = _new_ots_mode()
	mode.set("pitch_min", -60.0)
	mode.set("pitch_max", 50.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, -30.0)
	var transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected: Transform3D = _compute_expected_ots_transform(
		follow_target.global_position,
		Vector3(0.3, 1.6, -0.5),
		1.8,
		0.0,
		-30.0
	)

	_assert_basis_matches(transform.basis, expected.basis)

func test_ots_clamps_pitch_to_minimum() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_ots_mode()
	mode.set("pitch_min", -60.0)
	mode.set("pitch_max", 50.0)

	var clamped_result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, -100.0)
	var boundary_result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, -60.0)
	var clamped_transform: Transform3D = clamped_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var boundary_transform: Transform3D = boundary_result.get("transform", Transform3D.IDENTITY) as Transform3D

	_assert_basis_matches(clamped_transform.basis, boundary_transform.basis)

func test_ots_pitch_at_min_boundary_is_stable() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_ots_mode()
	mode.set("pitch_min", -60.0)
	mode.set("pitch_max", 50.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, -60.0)
	var transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var forward: Vector3 = -transform.basis.z.normalized()

	assert_almost_eq(forward.y, -sin(deg_to_rad(60.0)), 0.001)

func test_ots_pitch_at_max_boundary_is_stable() -> void:
	var follow_target: Node3D = _new_follow_target()
	var mode: Resource = _new_ots_mode()
	mode.set("pitch_min", -60.0)
	mode.set("pitch_max", 50.0)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 50.0)
	var transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var forward: Vector3 = -transform.basis.z.normalized()

	assert_almost_eq(forward.y, sin(deg_to_rad(50.0)), 0.001)

func test_ots_returns_empty_result_when_follow_target_is_null() -> void:
	var mode: Resource = _new_ots_mode()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, null, null, 0.0, 0.0)

	assert_eq(result.size(), 0)

func test_fixed_world_anchor_uses_anchor_position() -> void:
	var mode: Resource = _new_fixed_mode()
	var follow_target: Node3D = _new_follow_target(Vector3(2.0, 1.0, 0.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(10.0, 5.0, -3.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(camera_transform.origin.x, 10.0, 0.001)
	assert_almost_eq(camera_transform.origin.y, 5.0, 0.001)
	assert_almost_eq(camera_transform.origin.z, -3.0, 0.001)

func test_fixed_returns_fov_from_mode() -> void:
	var mode: Resource = _new_fixed_mode()
	var follow_target: Node3D = _new_follow_target()
	var fixed_anchor: Node3D = _new_fixed_anchor()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)

	assert_almost_eq(float(result.get("fov", 0.0)), 75.0, 0.0001)

func test_fixed_returns_mode_name() -> void:
	var mode: Resource = _new_fixed_mode()
	var follow_target: Node3D = _new_follow_target()
	var fixed_anchor: Node3D = _new_fixed_anchor()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)

	assert_eq(String(result.get("mode_name", "")), "fixed")

func test_fixed_with_tracking_looks_toward_follow_target() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("track_target", true)
	var follow_target: Node3D = _new_follow_target(Vector3(0.0, 0.0, 0.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(10.0, 5.0, 0.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var forward: Vector3 = -camera_transform.basis.z.normalized()
	var to_target: Vector3 = (follow_target.global_position - camera_transform.origin).normalized()

	assert_almost_eq(forward.dot(to_target), 1.0, 0.001)

func test_fixed_without_tracking_keeps_anchor_basis() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("track_target", false)
	var follow_target: Node3D = _new_follow_target(Vector3(0.0, 0.0, 0.0))
	var anchor_basis := Basis(Vector3.UP, deg_to_rad(35.0)).rotated(Vector3.RIGHT, deg_to_rad(-15.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(2.0, 3.0, 4.0), anchor_basis)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	_assert_basis_matches(camera_transform.basis, anchor_basis)

func test_fixed_tracking_with_null_follow_target_falls_back_to_anchor_basis() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("track_target", true)
	var anchor_basis := Basis(Vector3.UP, deg_to_rad(20.0)).rotated(Vector3.RIGHT, deg_to_rad(-10.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(1.0, 2.0, 3.0), anchor_basis)

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, null, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	_assert_basis_matches(camera_transform.basis, anchor_basis)

func test_fixed_ignores_runtime_yaw_and_pitch() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("track_target", false)
	var follow_target: Node3D = _new_follow_target()
	var anchor_basis := Basis(Vector3.UP, deg_to_rad(-40.0)).rotated(Vector3.RIGHT, deg_to_rad(12.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(1.0, 2.0, 3.0), anchor_basis)

	var with_runtime: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 90.0, -45.0, fixed_anchor)
	var without_runtime: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var with_runtime_transform: Transform3D = with_runtime.get("transform", Transform3D.IDENTITY) as Transform3D
	var without_runtime_transform: Transform3D = without_runtime.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(with_runtime_transform.origin.distance_to(without_runtime_transform.origin), 0.0, 0.001)
	_assert_basis_matches(with_runtime_transform.basis, without_runtime_transform.basis)

func test_fixed_follow_offset_mode_positions_from_follow_target() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("use_world_anchor", false)
	mode.set("follow_offset", Vector3(0.0, 3.0, 5.0))
	var follow_target: Node3D = _new_follow_target(Vector3(10.0, 0.0, 0.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(50.0, 50.0, 50.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(camera_transform.origin.x, 10.0, 0.001)
	assert_almost_eq(camera_transform.origin.y, 3.0, 0.001)
	assert_almost_eq(camera_transform.origin.z, 5.0, 0.001)

func test_fixed_follow_offset_mode_with_tracking_looks_at_follow_target() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("use_world_anchor", false)
	mode.set("track_target", true)
	mode.set("follow_offset", Vector3(0.0, 3.0, 5.0))
	var follow_target: Node3D = _new_follow_target(Vector3(0.0, 0.0, 0.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(100.0, 100.0, 100.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var forward: Vector3 = -camera_transform.basis.z.normalized()
	var to_target: Vector3 = (follow_target.global_position - camera_transform.origin).normalized()

	assert_almost_eq(forward.dot(to_target), 1.0, 0.001)

func test_fixed_follow_offset_mode_with_null_follow_target_returns_empty() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("use_world_anchor", false)
	mode.set("follow_offset", Vector3(0.0, 3.0, 5.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(10.0, 5.0, -3.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, null, null, 0.0, 0.0, fixed_anchor)

	assert_eq(result.size(), 0)

func test_fixed_use_path_uses_anchor_position_and_basis() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("use_path", true)
	var anchor_basis := Basis(Vector3.UP, deg_to_rad(60.0)).rotated(Vector3.RIGHT, deg_to_rad(-5.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(3.0, 4.0, 5.0), anchor_basis)
	var follow_target: Node3D = _new_follow_target(Vector3(0.0, 0.0, 0.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(camera_transform.origin.x, 3.0, 0.001)
	assert_almost_eq(camera_transform.origin.y, 4.0, 0.001)
	assert_almost_eq(camera_transform.origin.z, 5.0, 0.001)
	_assert_basis_matches(camera_transform.basis, anchor_basis)

func test_fixed_use_path_ignores_track_target() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("use_path", true)
	mode.set("track_target", true)
	var anchor_basis := Basis(Vector3.UP, deg_to_rad(60.0)).rotated(Vector3.RIGHT, deg_to_rad(-5.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(3.0, 4.0, 5.0), anchor_basis)
	var follow_target: Node3D = _new_follow_target(Vector3(50.0, 0.0, 0.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	_assert_basis_matches(camera_transform.basis, anchor_basis)

func test_fixed_use_path_with_null_anchor_returns_empty() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("use_path", true)
	var follow_target: Node3D = _new_follow_target()

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, null)

	assert_eq(result.size(), 0)

func test_fixed_use_path_ignores_follow_offset_and_use_world_anchor_flags() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("use_path", true)
	mode.set("use_world_anchor", false)
	mode.set("follow_offset", Vector3(99.0, 99.0, 99.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(7.0, 8.0, 9.0), Basis(Vector3.UP, deg_to_rad(10.0)))
	var follow_target: Node3D = _new_follow_target(Vector3(1.0, 2.0, 3.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(camera_transform.origin.x, 7.0, 0.001)
	assert_almost_eq(camera_transform.origin.y, 8.0, 0.001)
	assert_almost_eq(camera_transform.origin.z, 9.0, 0.001)

func test_fixed_tracking_handles_zero_length_direction_without_nan() -> void:
	var mode: Resource = _new_fixed_mode()
	mode.set("track_target", true)
	var anchor_basis := Basis(Vector3.UP, deg_to_rad(42.0)).rotated(Vector3.RIGHT, deg_to_rad(-8.0))
	var fixed_anchor: Node3D = _new_fixed_anchor(Vector3(4.0, 5.0, 6.0), anchor_basis)
	var follow_target: Node3D = _new_follow_target(Vector3(4.0, 5.0, 6.0))

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D

	_assert_basis_matches(camera_transform.basis, anchor_basis)
	assert_true(camera_transform.basis.x.is_finite())
	assert_true(camera_transform.basis.y.is_finite())
	assert_true(camera_transform.basis.z.is_finite())
