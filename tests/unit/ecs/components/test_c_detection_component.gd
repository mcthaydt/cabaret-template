extends BaseTest

const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")

func _instantiate_component() -> Variant:
	var component: Variant = C_DETECTION_COMPONENT.new()
	add_child_autofree(component)
	return component

func test_component_type_constant() -> void:
	assert_eq(C_DETECTION_COMPONENT.COMPONENT_TYPE, StringName("C_DetectionComponent"))

func test_init_sets_component_type() -> void:
	var component: Variant = _instantiate_component()
	assert_eq(component.get_component_type(), C_DETECTION_COMPONENT.COMPONENT_TYPE)

func test_defaults_are_safe() -> void:
	var component: Variant = _instantiate_component()
	assert_eq(component.detection_radius, 8.0)
	assert_eq(component.ai_flag_id, StringName(""))
	assert_false(component.is_player_in_range)
	assert_true(component.set_flag_on_exit)
	assert_eq(component.exit_flag_value, false)
	assert_eq(component.enter_event_name, StringName(""))

func test_validate_required_settings_rejects_non_positive_radius() -> void:
	var component: Variant = _instantiate_component()
	component.detection_radius = 0.0
	assert_false(component._validate_required_settings())
	assert_push_error("C_DetectionComponent detection_radius must be > 0.0.")
