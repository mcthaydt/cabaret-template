extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_SYSTEM := preload("res://scripts/ecs/ecs_system.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/ecs_component.gd")

class QueryComponent extends ECS_COMPONENT:
	const TYPE := StringName("C_QueryComponent")

	func _init() -> void:
		component_type = TYPE

class QueryPassthroughSystem extends ECS_SYSTEM:
	var captured: Array = []

	func process_tick(_delta: float) -> void:
		captured = query_entities([QueryComponent.TYPE])

func _pump() -> void:
	await get_tree().process_frame

func _setup_scene() -> Dictionary:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_QuerySystemEntity"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var component := QueryComponent.new()
	entity.add_child(component)
	autofree(component)
	await _pump()

	var system := QueryPassthroughSystem.new()
	manager.add_child(system)
	autofree(system)
	await _pump()

	return {
		"manager": manager,
		"system": system,
	}

func test_query_entities_passthrough_matches_manager_results() -> void:
	var context := await _setup_scene()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"]
	var system: QueryPassthroughSystem = context["system"]

	system._physics_process(0.016)

	var expected: Array = manager.query_entities([QueryComponent.TYPE])
	assert_eq(system.captured.size(), expected.size())
	if expected.size() > 0:
		assert_true(system.captured[0] == expected[0])

func test_execution_priority_defaults_to_zero_and_is_exported() -> void:
	var system := ECS_SYSTEM.new()
	add_child(system)
	autofree(system)

	assert_eq(system.execution_priority, 0, "ECSSystem should default execution_priority to zero")

	var property_info: Dictionary = {}
	for info in system.get_property_list():
		var name: String = info.get("name", "")
		if name == "execution_priority":
			property_info = info
			break

	assert_false(property_info.is_empty(), "execution_priority should be exported for editor configuration")

	var usage: int = property_info.get("usage", 0)
	assert_true((usage & PROPERTY_USAGE_EDITOR) != 0, "execution_priority should be visible in the editor")
