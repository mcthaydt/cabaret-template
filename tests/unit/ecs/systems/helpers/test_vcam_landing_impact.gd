extends GutTest

const U_VCAM_LANDING_IMPACT := preload("res://scripts/core/ecs/systems/helpers/u_vcam_landing_impact.gd")

class CameraStateStub extends RefCounted:
	var landing_impact_offset: Vector3 = Vector3.ZERO
	var landing_impact_recovery_speed: float = 0.0

func _has_property(object_value: Object, property_name: String) -> bool:
	if object_value == null:
		return false
	var properties: Array[Dictionary] = object_value.get_property_list()
	for property_info in properties:
		var name_variant: Variant = property_info.get("name", "")
		if str(name_variant) == property_name:
			return true
	return false

func _read_camera_state_vector3(camera_state: Object, property_name: String, fallback: Vector3) -> Vector3:
	if camera_state == null:
		return fallback
	if not _has_property(camera_state, property_name):
		return fallback
	var value: Variant = camera_state.get(property_name)
	if value is Vector3:
		return value as Vector3
	return fallback

func _get_camera_state_float(camera_state: Object, property_name: String, fallback: float) -> float:
	if camera_state == null:
		return fallback
	if not _has_property(camera_state, property_name):
		return fallback
	var value: Variant = camera_state.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func _write_camera_state_vector3(camera_state: Object, property_name: String, value: Vector3) -> void:
	if camera_state == null:
		return
	if not _has_property(camera_state, property_name):
		return
	camera_state.set(property_name, value)

func _apply_position_offset(result: Dictionary, offset: Vector3) -> Dictionary:
	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return result
	var transform := transform_variant as Transform3D
	var updated: Dictionary = result.duplicate(true)
	transform.origin += offset
	updated["transform"] = transform
	return updated

func test_record_landing_event_normalizes_fall_speed_to_unit_range() -> void:
	var helper := U_VCAM_LANDING_IMPACT.new()

	var normalized: float = helper.record_landing_event(
		{
			"entity_id": StringName("player"),
			"fall_speed": 17.5,
		}
	)

	assert_almost_eq(normalized, 0.5, 0.0001)
	var snapshot: Dictionary = helper.get_state_snapshot()
	assert_eq(int(snapshot.get("landing_response_event_serial", -1)), 1)
	assert_almost_eq(float(snapshot.get("landing_response_normalized", -1.0)), 0.5, 0.0001)

func test_record_landing_event_ignores_mismatched_entity() -> void:
	var helper := U_VCAM_LANDING_IMPACT.new()

	var normalized: float = helper.record_landing_event(
		{
			"entity_id": StringName("npc"),
			"fall_speed": 25.0,
		}
	)

	assert_almost_eq(normalized, 0.0, 0.0001)
	var snapshot: Dictionary = helper.get_state_snapshot()
	assert_eq(int(snapshot.get("landing_response_event_serial", -1)), 0)

func test_resolve_offset_recovers_toward_zero_and_writes_camera_state() -> void:
	var helper := U_VCAM_LANDING_IMPACT.new()
	var camera_state := CameraStateStub.new()
	camera_state.landing_impact_offset = Vector3(0.0, -0.3, 0.0)
	camera_state.landing_impact_recovery_speed = 8.0

	var first_resolved: Vector3 = helper.resolve_offset(
		0.016,
		camera_state,
		Callable(self, "_read_camera_state_vector3"),
		Callable(self, "_get_camera_state_float"),
		Callable(self, "_write_camera_state_vector3"),
		8.0
	)
	var recovered: Vector3 = first_resolved
	for _i in range(20):
		recovered = helper.resolve_offset(
			0.016,
			camera_state,
			Callable(self, "_read_camera_state_vector3"),
			Callable(self, "_get_camera_state_float"),
			Callable(self, "_write_camera_state_vector3"),
			8.0
		)

	assert_true(recovered.length() < first_resolved.length())
	assert_true(recovered.y <= 0.0)
	assert_almost_eq(camera_state.landing_impact_offset.y, recovered.y, 0.0001)
	var snapshot: Dictionary = helper.get_state_snapshot()
	var has_dynamics: bool = bool(snapshot.get("has_landing_recovery_dynamics", false))
	assert_true(has_dynamics or recovered.is_zero_approx())

func test_resolve_offset_with_zero_delta_returns_current_offset() -> void:
	var helper := U_VCAM_LANDING_IMPACT.new()
	var camera_state := CameraStateStub.new()
	camera_state.landing_impact_offset = Vector3(0.0, -0.3, 0.0)
	camera_state.landing_impact_recovery_speed = 8.0

	var resolved: Vector3 = helper.resolve_offset(
		0.0,
		camera_state,
		Callable(self, "_read_camera_state_vector3"),
		Callable(self, "_get_camera_state_float"),
		Callable(self, "_write_camera_state_vector3"),
		8.0
	)

	assert_almost_eq(resolved.y, -0.3, 0.0001)
	assert_almost_eq(camera_state.landing_impact_offset.y, -0.3, 0.0001)

func test_apply_offset_modifies_transform_origin() -> void:
	var helper := U_VCAM_LANDING_IMPACT.new()
	var transform := Transform3D.IDENTITY
	transform.origin = Vector3(1.0, 2.0, 3.0)

	var result: Dictionary = helper.apply_offset(
		{"transform": transform},
		Vector3(0.0, -0.3, 0.0),
		Callable(self, "_apply_position_offset")
	)

	var updated_transform := result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(updated_transform.origin.x, 1.0, 0.0001)
	assert_almost_eq(updated_transform.origin.y, 1.7, 0.0001)
	assert_almost_eq(updated_transform.origin.z, 3.0, 0.0001)

func test_clear_state_resets_recovery_and_event_tracking() -> void:
	var helper := U_VCAM_LANDING_IMPACT.new()
	var camera_state := CameraStateStub.new()
	camera_state.landing_impact_offset = Vector3(0.0, -0.3, 0.0)
	camera_state.landing_impact_recovery_speed = 8.0

	helper.record_landing_event({"entity_id": StringName("player"), "velocity": Vector3(0.0, -20.0, 0.0)})
	helper.resolve_offset(
		0.016,
		camera_state,
		Callable(self, "_read_camera_state_vector3"),
		Callable(self, "_get_camera_state_float"),
		Callable(self, "_write_camera_state_vector3"),
		8.0
	)

	helper.clear_state()
	var snapshot: Dictionary = helper.get_state_snapshot()
	assert_eq(int(snapshot.get("landing_recovery_state_id", -1)), 0)
	assert_almost_eq(float(snapshot.get("landing_recovery_frequency_hz", 1.0)), -1.0, 0.0001)
	assert_false(bool(snapshot.get("has_landing_recovery_dynamics", true)))
	assert_eq(int(snapshot.get("landing_response_event_serial", -1)), 0)
	assert_almost_eq(float(snapshot.get("landing_response_normalized", -1.0)), 0.0, 0.0001)
