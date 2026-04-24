extends GutTest

const U_VCAM_RESPONSE_SMOOTHER := preload("res://scripts/ecs/systems/helpers/u_vcam_response_smoother.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/core/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_RESPONSE := preload("res://scripts/core/resources/display/vcam/rs_vcam_response.gd")

class ResponseHolder extends RefCounted:
	var response: Resource = null

var _bypass_state: Dictionary = {}
var _gate_transition_count: int = 0
var _release_log_count: int = 0

func before_each() -> void:
	_bypass_state.clear()
	_gate_transition_count = 0
	_release_log_count = 0

func _response_values(
	follow_frequency: float = 3.0,
	follow_damping: float = 0.7,
	follow_initial_response: float = 1.0,
	rotation_frequency: float = 4.0,
	rotation_damping: float = 1.0,
	rotation_initial_response: float = 1.0,
	bypass_enable_speed: float = 1.0,
	bypass_disable_speed: float = 2.0
) -> Dictionary:
	return {
		"follow_frequency": follow_frequency,
		"follow_damping": follow_damping,
		"follow_initial_response": follow_initial_response,
		"rotation_frequency": rotation_frequency,
		"rotation_damping": rotation_damping,
		"rotation_initial_response": rotation_initial_response,
		"orbit_look_bypass_enable_speed": bypass_enable_speed,
		"orbit_look_bypass_disable_speed": bypass_disable_speed,
	}

func _response_signature(values: Dictionary) -> Array[float]:
	return [
		float(values.get("follow_frequency", 3.0)),
		float(values.get("follow_damping", 0.7)),
		float(values.get("follow_initial_response", 1.0)),
		float(values.get("rotation_frequency", 4.0)),
		float(values.get("rotation_damping", 1.0)),
		float(values.get("rotation_initial_response", 1.0)),
	]

func _result_with_position(position: Vector3) -> Dictionary:
	var transform := Transform3D.IDENTITY
	transform.origin = position
	return {"transform": transform}

func _result_with_yaw(position: Vector3, yaw_rad: float) -> Dictionary:
	var basis := Basis(Vector3.UP, yaw_rad)
	var transform := Transform3D(basis, position)
	return {"transform": transform}

func _update_orbit_bypass(
	vcam_id: StringName,
	mode_script: Script,
	orbit_mode_script: Script,
	has_active_look_input: bool,
	follow_target_speed_mps: float,
	response_values: Dictionary,
	default_enable_speed: float,
	default_disable_speed: float
) -> Dictionary:
	var enable_speed: float = maxf(
		float(response_values.get("orbit_look_bypass_enable_speed", default_enable_speed)),
		0.0
	)
	var disable_speed: float = maxf(
		float(response_values.get("orbit_look_bypass_disable_speed", default_disable_speed)),
		enable_speed
	)
	var had_previous: bool = _bypass_state.has(vcam_id)
	var previous_bypass: bool = bool(_bypass_state.get(vcam_id, false))
	var bypass: bool = false
	if mode_script == orbit_mode_script and has_active_look_input:
		if previous_bypass:
			bypass = follow_target_speed_mps <= disable_speed
		else:
			bypass = follow_target_speed_mps <= enable_speed
	_bypass_state[vcam_id] = bypass
	return {
		"bypass": bypass,
		"previous_bypass": previous_bypass,
		"had_previous_bypass_state": had_previous,
		"enable_speed": enable_speed,
		"disable_speed": disable_speed,
	}

func _debug_gate_transition(
	_vcam_id: StringName,
	_mode_script: Script,
	_has_active_look_input: bool,
	_raw_position: Vector3,
	_follow_dynamics: Variant,
	_follow_target_speed_mps: float,
	_enable_speed: float,
	_disable_speed: float,
	_previous_bypass: bool,
	_current_bypass: bool
) -> void:
	_gate_transition_count += 1

func _debug_release_log(_vcam_id: StringName, _message: String) -> void:
	_release_log_count += 1

func test_smoothing_applies_follow_position_dynamics() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var vcam_id := StringName("cam_smooth")
	var values: Dictionary = _response_values(3.0, 0.7)
	var signature: Array[float] = _response_signature(values)
	var first: Dictionary = helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		1001,
		0.0,
		_result_with_position(Vector3.ZERO),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	var second: Dictionary = helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		1001,
		0.0,
		_result_with_position(Vector3(10.0, 0.0, 0.0)),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	var third: Dictionary = helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		1001,
		0.0,
		_result_with_position(Vector3(10.0, 0.0, 0.0)),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	var first_transform := first.get("transform", Transform3D.IDENTITY) as Transform3D
	var second_transform := second.get("transform", Transform3D.IDENTITY) as Transform3D
	var third_transform := third.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(first_transform.origin.x, 0.0, 0.0001)
	assert_almost_eq(second_transform.origin.x, 0.0, 0.0001)
	assert_true(third_transform.origin.x > 0.0)
	assert_true(third_transform.origin.x < 10.0)

func test_empty_response_values_bypass_and_clear_state() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var vcam_id := StringName("cam_empty_response")
	var values: Dictionary = _response_values()
	var signature: Array[float] = _response_signature(values)
	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		1002,
		0.0,
		_result_with_position(Vector3.ZERO),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	assert_true(helper.get_follow_dynamics_snapshot().has(vcam_id))

	var bypassed: Dictionary = helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		1002,
		0.0,
		_result_with_position(Vector3(4.0, 0.0, 0.0)),
		0.016,
		false,
		{},
		[],
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	var bypassed_transform := bypassed.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(bypassed_transform.origin.x, 4.0, 0.0001)
	assert_false(helper.get_follow_dynamics_snapshot().has(vcam_id))

func test_mode_change_resets_dynamics_to_raw_pose() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var vcam_id := StringName("cam_mode_change")
	var values: Dictionary = _response_values()
	var signature: Array[float] = _response_signature(values)
	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		2001,
		0.0,
		_result_with_position(Vector3.ZERO),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		2001,
		0.0,
		_result_with_position(Vector3(8.0, 0.0, 0.0)),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)

	var reset_result: Dictionary = helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_RESPONSE,
		RS_VCAM_MODE_ORBIT,
		2001,
		0.0,
		_result_with_position(Vector3(12.0, 0.0, 0.0)),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	var reset_transform := reset_result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(reset_transform.origin.x, 12.0, 0.0001)
	var dynamics_variant: Variant = helper.get_follow_dynamics_snapshot().get(vcam_id, null)
	assert_true(dynamics_variant is Object)
	var dynamics := dynamics_variant as Object
	var value_variant: Variant = dynamics.call("get_value")
	assert_true(value_variant is Vector3)
	assert_almost_eq((value_variant as Vector3).x, 12.0, 0.0001)

func test_follow_target_change_resets_dynamics_to_raw_pose() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var vcam_id := StringName("cam_target_change")
	var values: Dictionary = _response_values()
	var signature: Array[float] = _response_signature(values)
	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		3001,
		0.0,
		_result_with_position(Vector3.ZERO),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)

	var reset_result: Dictionary = helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		3002,
		0.0,
		_result_with_position(Vector3(6.0, 0.0, 0.0)),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	var reset_transform := reset_result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(reset_transform.origin.x, 6.0, 0.0001)
	var metadata := helper.get_smoothing_metadata_snapshot().get(vcam_id, {}) as Dictionary
	assert_eq(int(metadata.get("follow_target_id", 0)), 3002)

func test_euler_unwrap_tracks_shortest_path_across_pi_boundary() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var vcam_id := StringName("cam_unwrap")
	var values: Dictionary = _response_values()
	var signature: Array[float] = _response_signature(values)
	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		4001,
		0.0,
		_result_with_yaw(Vector3.ZERO, PI - 0.1),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		4001,
		0.0,
		_result_with_yaw(Vector3.ZERO, -PI + 0.1),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	var cache := helper.get_rotation_target_cache_snapshot()
	var unwrapped: Vector3 = cache.get(vcam_id, Vector3.ZERO) as Vector3
	assert_true(unwrapped.y > PI)
	assert_true(unwrapped.y < PI + 0.5)

func test_orbit_bypass_resets_dynamics_and_returns_raw_result() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var vcam_id := StringName("cam_bypass")
	var values: Dictionary = _response_values()
	var signature: Array[float] = _response_signature(values)
	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		5001,
		0.0,
		_result_with_position(Vector3.ZERO),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)

	var bypassed: Dictionary = helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		5001,
		0.2,
		_result_with_position(Vector3(3.0, 0.0, 0.0)),
		0.016,
		true,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	var transform := bypassed.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(transform.origin.x, 3.0, 0.0001)
	var dynamics_variant: Variant = helper.get_follow_dynamics_snapshot().get(vcam_id, null)
	assert_true(dynamics_variant is Object)
	var dynamics := dynamics_variant as Object
	var value_variant: Variant = dynamics.call("get_value")
	assert_true(value_variant is Vector3)
	assert_almost_eq((value_variant as Vector3).x, 3.0, 0.0001)

func test_bypass_release_handoff_resets_dynamics_and_logs_release() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var vcam_id := StringName("cam_release_handoff")
	var values: Dictionary = _response_values()
	var signature: Array[float] = _response_signature(values)
	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		6001,
		0.0,
		_result_with_position(Vector3.ZERO),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0,
		Callable(self, "_debug_gate_transition"),
		Callable(self, "_debug_release_log")
	)

	helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		6001,
		0.1,
		_result_with_position(Vector3(2.0, 0.0, 0.0)),
		0.016,
		true,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0,
		Callable(self, "_debug_gate_transition"),
		Callable(self, "_debug_release_log")
	)
	var released: Dictionary = helper.apply_response_smoothing(
		vcam_id,
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		6001,
		3.0,
		_result_with_position(Vector3(7.0, 0.0, 0.0)),
		0.016,
		true,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0,
		Callable(self, "_debug_gate_transition"),
		Callable(self, "_debug_release_log")
	)
	var released_transform := released.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(released_transform.origin.x, 7.0, 0.0001)
	assert_true(_gate_transition_count >= 2)
	assert_eq(_release_log_count, 1)

func test_prune_clear_for_vcam_and_clear_all_lifecycle() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var values: Dictionary = _response_values()
	var signature: Array[float] = _response_signature(values)
	helper.apply_response_smoothing(
		StringName("cam_a"),
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		7001,
		0.0,
		_result_with_position(Vector3.ZERO),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)
	helper.apply_response_smoothing(
		StringName("cam_b"),
		RS_VCAM_MODE_ORBIT,
		RS_VCAM_MODE_ORBIT,
		7002,
		0.0,
		_result_with_position(Vector3.ZERO),
		0.016,
		false,
		values,
		signature,
		Callable(self, "_update_orbit_bypass"),
		1.0,
		2.0
	)

	helper.prune([StringName("cam_a")])
	assert_true(helper.get_follow_dynamics_snapshot().has(StringName("cam_a")))
	assert_false(helper.get_follow_dynamics_snapshot().has(StringName("cam_b")))

	helper.clear_for_vcam(StringName("cam_a"))
	assert_false(helper.get_follow_dynamics_snapshot().has(StringName("cam_a")))

	helper.clear_all()
	assert_true(helper.get_follow_dynamics_snapshot().is_empty())
	assert_true(helper.get_rotation_dynamics_snapshot().is_empty())
	assert_true(helper.get_smoothing_metadata_snapshot().is_empty())
	assert_true(helper.get_rotation_target_cache_snapshot().is_empty())

func test_resolve_component_response_values_returns_empty_for_invalid_component_or_script() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	assert_eq(
		helper.resolve_component_response_values(
			null,
			RS_VCAM_RESPONSE,
			1.0,
			2.0
		),
		{}
	)

	var holder := ResponseHolder.new()
	holder.response = RS_VCAM_RESPONSE.new()
	assert_eq(
		helper.resolve_component_response_values(
			holder,
			RS_VCAM_MODE_ORBIT,
			1.0,
			2.0
		),
		{}
	)

func test_resolve_component_response_values_clamps_disable_speed_against_enable() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var response := RS_VCAM_RESPONSE.new()
	response.orbit_look_bypass_enable_speed = 6.0
	response.orbit_look_bypass_disable_speed = 2.0
	var holder := ResponseHolder.new()
	holder.response = response
	var values: Dictionary = helper.resolve_component_response_values(
		holder,
		RS_VCAM_RESPONSE,
		1.0,
		2.0
	)
	assert_false(values.is_empty())
	assert_almost_eq(float(values.get("orbit_look_bypass_enable_speed", 0.0)), 6.0, 0.0001)
	assert_almost_eq(float(values.get("orbit_look_bypass_disable_speed", 0.0)), 6.0, 0.0001)

func test_build_response_signature_includes_look_and_ground_relative_fields() -> void:
	var helper := U_VCAM_RESPONSE_SMOOTHER.new()
	var values: Dictionary = {
		"ground_relative_enabled": true,
		"ground_reanchor_min_height_delta": 1.5,
		"ground_probe_max_distance": 9.0,
		"ground_anchor_blend_hz": 7.0,
	}
	var signature: Array[float] = helper.build_response_signature(
		values,
		0.11,
		0.22,
		0.33,
		0.44,
		0.55,
		0.66,
		0.77,
		0.88
	)
	assert_eq(signature.size(), 18)
	assert_almost_eq(signature[6], 0.11, 0.0001)
	assert_almost_eq(signature[7], 0.22, 0.0001)
	assert_almost_eq(signature[8], 0.33, 0.0001)
	assert_almost_eq(signature[14], 1.0, 0.0001)
	assert_almost_eq(signature[15], 1.5, 0.0001)
	assert_almost_eq(signature[16], 9.0, 0.0001)
	assert_almost_eq(signature[17], 7.0, 0.0001)
