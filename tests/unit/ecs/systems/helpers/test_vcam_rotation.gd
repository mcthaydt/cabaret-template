extends GutTest

const U_VCAM_ROTATION := preload("res://scripts/ecs/systems/helpers/u_vcam_rotation.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/core/resources/display/vcam/rs_vcam_mode_orbit.gd")

class RotationComponentStub extends RefCounted:
	var mode: Resource = null
	var runtime_yaw: float = 0.0
	var runtime_pitch: float = 0.0
	var target: Node3D = null

func _new_orbit_mode(
	authored_yaw: float = 0.0,
	authored_pitch: float = 0.0,
	allow_player_rotation: bool = true,
	lock_x_rotation: bool = false,
	lock_y_rotation: bool = true,
	rotation_speed: float = 1.0
) -> RS_VCamModeOrbit:
	var mode := RS_VCAM_MODE_ORBIT.new()
	mode.authored_yaw = authored_yaw
	mode.authored_pitch = authored_pitch
	mode.allow_player_rotation = allow_player_rotation
	mode.lock_x_rotation = lock_x_rotation
	mode.lock_y_rotation = lock_y_rotation
	mode.rotation_speed = rotation_speed
	return mode

func _resolve_follow_target(component: Object) -> Node3D:
	if component == null:
		return null
	return component.target

func _resolve_mode_values(mode: Resource, fallback: Dictionary) -> Dictionary:
	if mode == null:
		return fallback.duplicate(true)
	if mode.has_method("get_resolved_values"):
		var values_variant: Variant = mode.call("get_resolved_values")
		if values_variant is Dictionary:
			return (values_variant as Dictionary).duplicate(true)
	return fallback.duplicate(true)

func _new_response_values(
	rotation_frequency: float = 4.0,
	rotation_damping: float = 1.0,
	look_release_yaw_damping: float = 10.0,
	look_release_pitch_damping: float = 12.0,
	look_release_stop_threshold: float = 0.05
) -> Dictionary:
	return {
		"rotation_frequency": rotation_frequency,
		"rotation_damping": rotation_damping,
		"look_release_yaw_damping": look_release_yaw_damping,
		"look_release_pitch_damping": look_release_pitch_damping,
		"look_release_stop_threshold": look_release_stop_threshold,
		"auto_level_speed": 0.0,
		"auto_level_delay": 1.0,
	}

func test_continuity_carries_rotation_on_same_mode_same_target() -> void:
	var helper := U_VCAM_ROTATION.new()
	var shared_target := Node3D.new()
	autofree(shared_target)
	var outgoing := RotationComponentStub.new()
	outgoing.mode = _new_orbit_mode()
	outgoing.runtime_yaw = 33.0
	outgoing.runtime_pitch = -7.0
	outgoing.target = shared_target
	var incoming := RotationComponentStub.new()
	incoming.mode = _new_orbit_mode()
	incoming.runtime_yaw = 0.0
	incoming.runtime_pitch = 0.0
	incoming.target = shared_target
	var vcam_index := {
		StringName("cam_out"): outgoing,
		StringName("cam_in"): incoming,
	}

	var updated_last_active: StringName = helper.apply_rotation_continuity_policy(
		StringName("cam_in"),
		vcam_index,
		StringName("cam_out"),
		StringName("cam_out"),
		Callable(self, "_resolve_follow_target"),
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)

	assert_eq(updated_last_active, StringName("cam_in"))
	assert_almost_eq(incoming.runtime_yaw, 33.0, 0.0001)
	assert_almost_eq(incoming.runtime_pitch, -7.0, 0.0001)

func test_continuity_reseeds_to_authored_angles_on_different_target() -> void:
	var helper := U_VCAM_ROTATION.new()
	var outgoing_target := Node3D.new()
	var incoming_target := Node3D.new()
	autofree(outgoing_target)
	autofree(incoming_target)
	var outgoing := RotationComponentStub.new()
	outgoing.mode = _new_orbit_mode()
	outgoing.runtime_yaw = 80.0
	outgoing.runtime_pitch = -25.0
	outgoing.target = outgoing_target
	var incoming_mode := _new_orbit_mode(12.0, -18.0)
	var incoming := RotationComponentStub.new()
	incoming.mode = incoming_mode
	incoming.runtime_yaw = 1.0
	incoming.runtime_pitch = 2.0
	incoming.target = incoming_target
	var vcam_index := {
		StringName("cam_out"): outgoing,
		StringName("cam_in"): incoming,
	}

	helper.apply_rotation_continuity_policy(
		StringName("cam_in"),
		vcam_index,
		StringName("cam_out"),
		StringName("cam_out"),
		Callable(self, "_resolve_follow_target"),
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)

	assert_almost_eq(incoming.runtime_yaw, 12.0, 0.0001)
	assert_almost_eq(incoming.runtime_pitch, -18.0, 0.0001)

func test_update_runtime_rotation_applies_orbit_look_input() -> void:
	var helper := U_VCAM_ROTATION.new()
	var component := RotationComponentStub.new()
	component.mode = _new_orbit_mode(0.0, 0.0, true, false, false, 2.0)

	helper.update_runtime_rotation(
		StringName("cam_orbit"),
		component,
		component.mode,
		null,
		Vector2(1.5, -1.0),
		true,
		false,
		_new_response_values(),
		0.016,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)

	assert_almost_eq(component.runtime_yaw, 3.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, -2.0, 0.0001)

func test_orbit_centering_interpolates_and_completes() -> void:
	var helper := U_VCAM_ROTATION.new()
	var follow_target := Node3D.new()
	add_child_autofree(follow_target)
	var component := RotationComponentStub.new()
	component.mode = _new_orbit_mode(0.0, 0.0, true, false, false, 1.0)
	component.runtime_yaw = 90.0
	component.runtime_pitch = 10.0
	component.target = follow_target

	helper.update_runtime_rotation(
		StringName("cam_center"),
		component,
		component.mode,
		follow_target,
		Vector2.ZERO,
		false,
		true,
		_new_response_values(),
		0.016,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)
	assert_true(helper.is_orbit_centering_active(StringName("cam_center")))

	helper.update_runtime_rotation(
		StringName("cam_center"),
		component,
		component.mode,
		follow_target,
		Vector2.ZERO,
		false,
		false,
		_new_response_values(),
		0.4,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)
	assert_false(helper.is_orbit_centering_active(StringName("cam_center")))
	assert_almost_eq(component.runtime_yaw, 0.0, 0.001)

func test_auto_level_applies_after_delay() -> void:
	var helper := U_VCAM_ROTATION.new()
	var component := RotationComponentStub.new()
	component.mode = _new_orbit_mode(0.0, 0.0, true, false, false, 1.0)
	component.runtime_pitch = 20.0
	var response_values := _new_response_values()
	response_values["auto_level_speed"] = 10.0
	response_values["auto_level_delay"] = 0.05

	helper.update_runtime_rotation(
		StringName("cam_auto"),
		component,
		component.mode,
		null,
		Vector2.ZERO,
		false,
		false,
		response_values,
		0.03,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)
	assert_almost_eq(component.runtime_pitch, 20.0, 0.0001)

	helper.update_runtime_rotation(
		StringName("cam_auto"),
		component,
		component.mode,
		null,
		Vector2.ZERO,
		false,
		false,
		response_values,
		0.03,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)
	assert_true(component.runtime_pitch < 20.0)

func test_resolve_runtime_rotation_reseeds_and_steps() -> void:
	var helper := U_VCAM_ROTATION.new()
	var follow_target := Node3D.new()
	autofree(follow_target)
	var component := RotationComponentStub.new()
	component.mode = _new_orbit_mode(0.0, 0.0, true, false, false, 1.0)
	component.runtime_yaw = 0.0
	component.runtime_pitch = 0.0
	var response_values := _new_response_values(8.0, 0.9)
	var signature: Array[float] = [8.0, 0.9, 1.0]

	var reseed: Vector2 = helper.resolve_runtime_rotation_for_evaluation(
		StringName("cam_rotate"),
		component,
		component.mode,
		follow_target,
		response_values,
		signature,
		true,
		0.016,
		RS_VCAM_MODE_ORBIT
	)
	assert_eq(reseed, Vector2.ZERO)

	component.runtime_yaw = 40.0
	var stepped: Vector2 = helper.resolve_runtime_rotation_for_evaluation(
		StringName("cam_rotate"),
		component,
		component.mode,
		follow_target,
		response_values,
		signature,
		true,
		0.016,
		RS_VCAM_MODE_ORBIT
	)
	assert_true(stepped.x > 0.0 and stepped.x < 40.0)

func test_release_damping_eventually_clears_velocity() -> void:
	var helper := U_VCAM_ROTATION.new()
	var component := RotationComponentStub.new()
	component.mode = _new_orbit_mode(0.0, 0.0, true, false, false, 1.0)
	var response_values := _new_response_values(8.0, 0.9, 12.0, 12.0, 0.05)
	var signature: Array[float] = [8.0, 0.9, 12.0, 12.0, 0.05]

	helper.resolve_runtime_rotation_for_evaluation(
		StringName("cam_release"),
		component,
		component.mode,
		null,
		response_values,
		signature,
		true,
		0.016,
		RS_VCAM_MODE_ORBIT
	)
	component.runtime_yaw = 35.0
	helper.resolve_runtime_rotation_for_evaluation(
		StringName("cam_release"),
		component,
		component.mode,
		null,
		response_values,
		signature,
		true,
		0.016,
		RS_VCAM_MODE_ORBIT
	)

	for _i in range(80):
		helper.resolve_runtime_rotation_for_evaluation(
			StringName("cam_release"),
			component,
			component.mode,
			null,
			response_values,
			signature,
			false,
			0.016,
			RS_VCAM_MODE_ORBIT
		)

	var state: Dictionary = helper.get_look_rotation_state_snapshot().get(StringName("cam_release"), {}) as Dictionary
	assert_false(bool(state.get("input_active", true)))
	assert_true(absf(float(state.get("yaw_velocity", 1.0))) <= 0.05)

func test_prune_and_clear_lifecycle() -> void:
	var helper := U_VCAM_ROTATION.new()
	var component_a := RotationComponentStub.new()
	component_a.mode = _new_orbit_mode(0.0, 0.0, true, false, false, 1.0)
	var component_b := RotationComponentStub.new()
	component_b.mode = _new_orbit_mode(0.0, 0.0, true, false, false, 1.0)
	var response_values := _new_response_values()
	var signature: Array[float] = [4.0, 1.0, 10.0]

	helper.update_runtime_rotation(
		StringName("cam_a"),
		component_a,
		component_a.mode,
		null,
		Vector2.ZERO,
		false,
		true,
		response_values,
		0.016,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)
	helper.update_runtime_rotation(
		StringName("cam_b"),
		component_b,
		component_b.mode,
		null,
		Vector2.ZERO,
		false,
		true,
		response_values,
		0.016,
		Callable(self, "_resolve_mode_values"),
		RS_VCAM_MODE_ORBIT
	)
	helper.resolve_runtime_rotation_for_evaluation(
		StringName("cam_a"),
		component_a,
		component_a.mode,
		null,
		response_values,
		signature,
		true,
		0.016,
		RS_VCAM_MODE_ORBIT
	)
	helper.resolve_runtime_rotation_for_evaluation(
		StringName("cam_b"),
		component_b,
		component_b.mode,
		null,
		response_values,
		signature,
		true,
		0.016,
		RS_VCAM_MODE_ORBIT
	)

	helper.prune([StringName("cam_a")])
	var rotation_snapshot: Dictionary = helper.get_look_rotation_state_snapshot()
	assert_true(rotation_snapshot.has(StringName("cam_a")))
	assert_false(rotation_snapshot.has(StringName("cam_b")))
	var centering_snapshot: Dictionary = helper.get_orbit_centering_state_snapshot()
	assert_true(centering_snapshot.has(StringName("cam_a")))
	assert_false(centering_snapshot.has(StringName("cam_b")))

	helper.clear_for_vcam(StringName("cam_a"))
	assert_false(helper.get_look_rotation_state_snapshot().has(StringName("cam_a")))
	assert_false(helper.get_orbit_centering_state_snapshot().has(StringName("cam_a")))

	helper.clear_all()
	assert_true(helper.get_look_rotation_state_snapshot().is_empty())
	assert_true(helper.get_orbit_centering_state_snapshot().is_empty())
	assert_true(helper.get_orbit_no_look_input_timers_snapshot().is_empty())
