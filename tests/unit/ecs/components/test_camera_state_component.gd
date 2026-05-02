extends BaseTest

const C_CAMERA_STATE_COMPONENT := preload("res://scripts/core/ecs/components/c_camera_state_component.gd")
const BASE_ECS_COMPONENT := preload("res://scripts/core/ecs/base_ecs_component.gd")

func test_extends_base_ecs_component() -> void:
	var component := C_CAMERA_STATE_COMPONENT.new()
	autofree(component)
	assert_true(component is BASE_ECS_COMPONENT, "C_CameraStateComponent should extend BaseECSComponent")

func test_landing_impact_offset_defaults_to_zero_vector() -> void:
	var component := C_CAMERA_STATE_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "landing_impact_offset"))
	assert_eq(component.get("landing_impact_offset"), Vector3.ZERO)

func test_landing_impact_recovery_speed_defaults_to_eight_hz() -> void:
	var component := C_CAMERA_STATE_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "landing_impact_recovery_speed"))
	assert_almost_eq(component.get("landing_impact_recovery_speed"), 8.0, 0.001)

func test_speed_fov_bonus_defaults_to_zero() -> void:
	var component := C_CAMERA_STATE_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "speed_fov_bonus"))
	assert_almost_eq(component.get("speed_fov_bonus"), 0.0, 0.001)

func test_speed_fov_max_bonus_defaults_to_fifteen() -> void:
	var component := C_CAMERA_STATE_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "speed_fov_max_bonus"))
	assert_almost_eq(component.get("speed_fov_max_bonus"), 15.0, 0.001)

func _has_property(object: Object, property_name: String) -> bool:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return true
	return false
