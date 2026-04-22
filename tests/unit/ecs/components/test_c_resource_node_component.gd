extends BaseTest

const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/ecs/components/c_resource_node_component.gd")
const RS_RESOURCE_NODE_SETTINGS := preload("res://scripts/resources/ai/world/rs_resource_node_settings.gd")

func _instantiate(settings: RS_ResourceNodeSettings = null) -> Variant:
	var component := C_RESOURCE_NODE_COMPONENT.new()
	if settings == null:
		settings = RS_RESOURCE_NODE_SETTINGS.new()
	component.settings = settings
	component._on_required_settings_ready()
	add_child_autofree(component)
	return component

func test_component_type_constant() -> void:
	assert_eq(C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE, StringName("C_ResourceNodeComponent"))

func test_init_sets_component_type() -> void:
	var component: Variant = _instantiate()
	assert_eq(component.get_component_type(), C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE)

func test_defaults() -> void:
	var component: Variant = _instantiate()
	assert_eq(component.current_amount, 5)
	assert_eq(component.reserved_by_entity_id, StringName(""))
	assert_eq(component.regrow_timer, 0.0)

func test_on_required_settings_ready_sets_initial_amount() -> void:
	var settings: RS_ResourceNodeSettings = RS_RESOURCE_NODE_SETTINGS.new()
	settings.initial_amount = 10
	var component: Variant = _instantiate(settings)
	assert_eq(component.current_amount, 10)

func test_is_available_true_when_has_stock_and_not_reserved() -> void:
	var settings: RS_ResourceNodeSettings = RS_RESOURCE_NODE_SETTINGS.new()
	settings.initial_amount = 5
	var component: Variant = _instantiate(settings)
	assert_true(component.is_available())

func test_is_available_false_when_depleted() -> void:
	var settings: RS_ResourceNodeSettings = RS_RESOURCE_NODE_SETTINGS.new()
	settings.initial_amount = 5
	var component: Variant = _instantiate(settings)
	component.current_amount = 0
	assert_false(component.is_available())

func test_is_available_false_when_reserved() -> void:
	var settings: RS_ResourceNodeSettings = RS_RESOURCE_NODE_SETTINGS.new()
	settings.initial_amount = 5
	var component: Variant = _instantiate(settings)
	component.reserved_by_entity_id = &"other_agent"
	assert_false(component.is_available())

func test_harvest_reduces_amount() -> void:
	var settings: RS_ResourceNodeSettings = RS_RESOURCE_NODE_SETTINGS.new()
	settings.initial_amount = 5
	var component: Variant = _instantiate(settings)
	var taken: int = component.harvest(3)
	assert_eq(taken, 3)
	assert_eq(component.current_amount, 2)

func test_harvest_clamps_to_available() -> void:
	var settings: RS_ResourceNodeSettings = RS_RESOURCE_NODE_SETTINGS.new()
	settings.initial_amount = 2
	var component: Variant = _instantiate(settings)
	var taken: int = component.harvest(5)
	assert_eq(taken, 2)
	assert_eq(component.current_amount, 0)

func test_clear_reservation_if_owned() -> void:
	var component: Variant = _instantiate()
	component.reserved_by_entity_id = &"owner"
	component.clear_reservation_if_owned(&"other")
	assert_eq(component.reserved_by_entity_id, &"owner")
	component.clear_reservation_if_owned(&"owner")
	assert_eq(component.reserved_by_entity_id, StringName(""))
