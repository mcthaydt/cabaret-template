extends BaseTest

const ENTITY_QUERY := preload("res://scripts/ecs/entity_query.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/ecs_component.gd")

const OPTIONAL_TYPE := StringName("C_OptionalComponent")

class TestComponent extends BaseECSComponent:
	const COMPONENT_TYPE := StringName("C_TestComponent")

	func _init() -> void:
		component_type = COMPONENT_TYPE

func test_get_component_returns_component_for_required_type() -> void:
	var query := ENTITY_QUERY.new()
	var entity := autofree(Node.new())
	var component := TestComponent.new()
	autofree(component)

	query.entity = entity
	query.components = {
		TestComponent.COMPONENT_TYPE: component,
	}

	var retrieved: BaseECSComponent = query.get_component(TestComponent.COMPONENT_TYPE)
	assert_eq(retrieved, component)

func test_has_component_detects_optional_component() -> void:
	var query := ENTITY_QUERY.new()
	var component := TestComponent.new()
	autofree(component)

	query.components = {
		TestComponent.COMPONENT_TYPE: component,
	}

	assert_true(query.has_component(TestComponent.COMPONENT_TYPE))
	assert_false(query.has_component(OPTIONAL_TYPE))

func test_get_all_components_returns_copy() -> void:
	var query := ENTITY_QUERY.new()
	var component := TestComponent.new()
	autofree(component)

	query.components = {
		TestComponent.COMPONENT_TYPE: component,
	}

	var copied: Dictionary = query.get_all_components()
	copied.erase(TestComponent.COMPONENT_TYPE)

	assert_false(copied.has(TestComponent.COMPONENT_TYPE))
	assert_true(query.has_component(TestComponent.COMPONENT_TYPE))
	assert_eq(query.get_component(TestComponent.COMPONENT_TYPE), component)
