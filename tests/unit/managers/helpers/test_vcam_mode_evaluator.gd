extends GutTest

const EVALUATOR_SCRIPT := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")
const MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const FIRST_PERSON_MODE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")

func _new_mode() -> Resource:
	return MODE_SCRIPT.new()

func _new_first_person_mode() -> Resource:
	return FIRST_PERSON_MODE_SCRIPT.new()

func _new_follow_target(position: Vector3 = Vector3.ZERO) -> Node3D:
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	follow_target.global_position = position
	return follow_target

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

	var result: Dictionary = EVALUATOR_SCRIPT.evaluate(mode, follow_target, null, 90.0, -10.0)
	var camera_transform: Transform3D = result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected_position: Vector3 = _compute_expected_offset(5.0, -30.0, 90.0)

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
