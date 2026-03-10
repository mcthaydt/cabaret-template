extends BaseTest

const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const BASE_ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const RS_VCAM_RESPONSE := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")

func test_extends_base_ecs_component() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(component is BASE_ECS_COMPONENT, "C_VCamComponent should extend BaseECSComponent")

func test_component_type_constant_is_vcam_component() -> void:
	assert_eq(C_VCAM_COMPONENT.COMPONENT_TYPE, StringName("VCamComponent"))

func test_vcam_id_export_exists() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "vcam_id"), "vcam_id export should exist")

func test_priority_defaults_to_zero() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_eq(component.priority, 0, "priority should default to 0")

func test_mode_export_exists() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "mode"), "mode export should exist")

func test_fixed_anchor_path_export_exists() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "fixed_anchor_path"), "fixed_anchor_path export should exist")

func test_follow_target_path_export_exists() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "follow_target_path"), "follow_target_path export should exist")

func test_follow_target_entity_id_defaults_to_empty() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_eq(component.follow_target_entity_id, StringName(""))

func test_follow_target_tag_defaults_to_empty() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_eq(component.follow_target_tag, StringName(""))

func test_look_at_target_path_export_exists() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "look_at_target_path"), "look_at_target_path export should exist")

func test_path_node_path_export_exists() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "path_node_path"), "path_node_path export should exist")

func test_soft_zone_export_exists() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "soft_zone"), "soft_zone export should exist")

func test_blend_hint_export_exists() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "blend_hint"), "blend_hint export should exist")

func test_response_export_is_typed_and_accepts_vcam_response() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(_has_property(component, "response"), "response export should exist")
	var response_property: Dictionary = _get_property_definition(component, "response")
	assert_eq(int(response_property.get("type", -1)), TYPE_OBJECT, "response should be an object-typed export")
	assert_eq(int(response_property.get("hint", -1)), PROPERTY_HINT_RESOURCE_TYPE, "response should enforce resource type hints")
	assert_true(
		str(response_property.get("hint_string", "")).contains("RS_VCamResponse"),
		"response export should target RS_VCamResponse"
	)
	var response := RS_VCAM_RESPONSE.new()
	component.set("response", response)
	assert_eq(component.get("response"), response, "response should accept RS_VCamResponse resources")

func test_is_active_defaults_true() -> void:
	var component := C_VCAM_COMPONENT.new()
	autofree(component)
	assert_true(component.is_active, "is_active should default to true")

func _has_property(object: Object, property_name: String) -> bool:
	return not _get_property_definition(object, property_name).is_empty()

func _get_property_definition(object: Object, property_name: String) -> Dictionary:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return property
	return {}
