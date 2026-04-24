extends RefCounted
class_name U_VCamLandingImpact

const U_SECOND_ORDER_DYNAMICS_3D := preload("res://scripts/core/utils/math/u_second_order_dynamics_3d.gd")
const U_RULE_UTILS := preload("res://scripts/core/utils/ecs/u_rule_utils.gd")

const DEFAULT_FALL_SPEED_MIN: float = 5.0
const DEFAULT_FALL_SPEED_MAX: float = 30.0

var _landing_recovery_dynamics = null
var _landing_recovery_state_id: int = 0
var _landing_recovery_frequency_hz: float = -1.0
var _landing_response_event_serial: int = 0
var _landing_response_normalized: float = 0.0

func normalize_fall_speed(
	fall_speed: float,
	fall_speed_min: float = DEFAULT_FALL_SPEED_MIN,
	fall_speed_max: float = DEFAULT_FALL_SPEED_MAX
) -> float:
	var min_speed: float = minf(fall_speed_min, fall_speed_max)
	var max_speed: float = maxf(fall_speed_min, fall_speed_max)
	if max_speed <= min_speed:
		return 0.0
	var magnitude: float = absf(fall_speed)
	var normalized: float = (magnitude - min_speed) / (max_speed - min_speed)
	return clampf(normalized, 0.0, 1.0)

func record_landing_event(
	event_payload: Dictionary,
	expected_entity_id: StringName = StringName("player"),
	fall_speed_min: float = DEFAULT_FALL_SPEED_MIN,
	fall_speed_max: float = DEFAULT_FALL_SPEED_MAX
) -> float:
	if event_payload.is_empty():
		return _landing_response_normalized

	if expected_entity_id != StringName(""):
		var payload_entity_id: StringName = U_RuleUtils.variant_to_string_name(event_payload.get("entity_id", StringName("")))
		if payload_entity_id != expected_entity_id:
			return _landing_response_normalized

	var fall_speed_info: Dictionary = _resolve_event_fall_speed(event_payload)
	if not bool(fall_speed_info.get("valid", false)):
		return _landing_response_normalized

	var fall_speed: float = float(fall_speed_info.get("fall_speed", 0.0))
	_landing_response_normalized = normalize_fall_speed(fall_speed, fall_speed_min, fall_speed_max)
	_landing_response_event_serial += 1
	return _landing_response_normalized

func resolve_offset(
	delta: float,
	camera_state: Object,
	read_camera_state_vector3: Callable,
	get_camera_state_float: Callable,
	write_camera_state_vector3: Callable,
	default_recovery_speed: float
) -> Vector3:
	if camera_state == null:
		_clear_recovery_state()
		return Vector3.ZERO
	if not read_camera_state_vector3.is_valid() or not get_camera_state_float.is_valid():
		_clear_recovery_state()
		return Vector3.ZERO

	var current_offset_variant: Variant = read_camera_state_vector3.call(
		camera_state,
		"landing_impact_offset",
		Vector3.ZERO
	)
	var current_offset: Vector3 = current_offset_variant as Vector3 if current_offset_variant is Vector3 else Vector3.ZERO
	if current_offset.is_zero_approx():
		_clear_recovery_state()
		return Vector3.ZERO

	var recovery_speed_variant: Variant = get_camera_state_float.call(
		camera_state,
		"landing_impact_recovery_speed",
		default_recovery_speed
	)
	var recovery_speed_hz: float = maxf(float(recovery_speed_variant), 0.0)
	if recovery_speed_hz <= 0.0:
		_clear_recovery_state()
		return current_offset

	var camera_state_id: int = camera_state.get_instance_id()
	var needs_rebuild: bool = (
		_landing_recovery_dynamics == null
		or _landing_recovery_state_id != camera_state_id
		or not is_equal_approx(_landing_recovery_frequency_hz, recovery_speed_hz)
	)
	if needs_rebuild:
		_landing_recovery_dynamics = U_SECOND_ORDER_DYNAMICS_3D.new(
			recovery_speed_hz,
			1.0,
			1.0,
			current_offset
		)
		_landing_recovery_state_id = camera_state_id
		_landing_recovery_frequency_hz = recovery_speed_hz
		if delta <= 0.0:
			return current_offset

	var recovered_offset: Vector3 = _landing_recovery_dynamics.step(Vector3.ZERO, delta)
	if recovered_offset.length_squared() <= 0.000001:
		recovered_offset = Vector3.ZERO
		_clear_recovery_state()

	if write_camera_state_vector3.is_valid():
		write_camera_state_vector3.call(camera_state, "landing_impact_offset", recovered_offset)
	return recovered_offset

func apply_offset(result: Dictionary, landing_offset: Vector3, apply_position_offset: Callable) -> Dictionary:
	if landing_offset.is_zero_approx():
		return result
	if not apply_position_offset.is_valid():
		return result
	var offset_result_variant: Variant = apply_position_offset.call(result, landing_offset)
	if offset_result_variant is Dictionary:
		return offset_result_variant as Dictionary
	return result

func clear_state() -> void:
	_clear_recovery_state()
	_landing_response_event_serial = 0
	_landing_response_normalized = 0.0

func get_state_snapshot() -> Dictionary:
	return {
		"landing_recovery_state_id": _landing_recovery_state_id,
		"landing_recovery_frequency_hz": _landing_recovery_frequency_hz,
		"landing_response_event_serial": _landing_response_event_serial,
		"landing_response_normalized": _landing_response_normalized,
		"has_landing_recovery_dynamics": _landing_recovery_dynamics != null,
	}

func _clear_recovery_state() -> void:
	_landing_recovery_dynamics = null
	_landing_recovery_state_id = 0
	_landing_recovery_frequency_hz = -1.0

func _resolve_event_fall_speed(event_payload: Dictionary) -> Dictionary:
	var fall_speed_variant: Variant = event_payload.get("fall_speed", null)
	if fall_speed_variant is float or fall_speed_variant is int:
		return {"valid": true, "fall_speed": absf(float(fall_speed_variant))}

	var vertical_velocity_variant: Variant = event_payload.get("vertical_velocity", null)
	if vertical_velocity_variant is float or vertical_velocity_variant is int:
		return {"valid": true, "fall_speed": absf(float(vertical_velocity_variant))}

	var velocity_variant: Variant = event_payload.get("velocity", null)
	if velocity_variant is Vector3:
		var velocity_3d := velocity_variant as Vector3
		return {"valid": true, "fall_speed": absf(velocity_3d.y)}

	return {"valid": false, "fall_speed": 0.0}
