extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/ecs_component.gd")
const ECS_SYSTEM := preload("res://scripts/ecs/ecs_system.gd")
const PLAYER_SCENE := preload("res://templates/player_template.tscn")
const BASE_SCENE := preload("res://templates/base_scene_template.tscn")

class FakeComponent extends ECS_COMPONENT:
	const TYPE := StringName("C_FakeComponent")

	func _init():
		component_type = TYPE

	func get_snapshot() -> Dictionary:
		return {"id": 42}

class FakeSystem extends ECS_SYSTEM:
	var observed_components: Array = []

	func process_tick(_delta: float) -> void:
		observed_components = get_components(FakeComponent.TYPE)

var _expected_component
var _expected_manager
var _added_calls := 0
var _registered_calls := 0

func _on_component_added(component_type, received) -> void:
	_added_calls += 1
	assert_eq(component_type, FakeComponent.TYPE)
	assert_eq(received, _expected_component)

func _on_component_registered(received_manager, received_component) -> void:
	_registered_calls += 1
	assert_eq(received_manager, _expected_manager)
	assert_eq(received_component, _expected_component)

func test_component_auto_registers_with_manager_on_ready() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var component := FakeComponent.new()
	add_child(component)
	autofree(component)
	await get_tree().process_frame

	var components := manager.get_components(FakeComponent.TYPE)
	assert_eq(components, [component])

func test_system_auto_registers_with_manager_on_ready() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var system := FakeSystem.new()
	add_child(system)
	autofree(system)
	await get_tree().process_frame

	var systems: Array = manager.get_systems()
	assert_true(systems.has(system))
	assert_eq(system.get_manager(), manager)

func test_register_component_adds_to_lookup() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var component := FakeComponent.new()
	autofree(component)
	manager.register_component(component)

	var components := manager.get_components(FakeComponent.TYPE)
	assert_not_null(components)
	assert_eq(components.size(), 1)
	assert_true(components.has(component))

func test_register_component_emits_signals() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var component := FakeComponent.new()
	autofree(component)
	_expected_component = component
	_expected_manager = manager
	_added_calls = 0
	_registered_calls = 0

	assert_true(component.has_method("on_registered"))

	var add_err := manager.component_added.connect(Callable(self, "_on_component_added"))
	assert_eq(add_err, OK)

	var reg_err := component.registered.connect(Callable(self, "_on_component_registered"))
	assert_eq(reg_err, OK)

	manager.register_component(component)

	assert_eq(_added_calls, 1)
	assert_eq(_registered_calls, 1)

func test_register_system_configures_and_queries_components() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var component := FakeComponent.new()
	autofree(component)
	manager.register_component(component)

	var system := FakeSystem.new()
	autofree(system)
	manager.register_system(system)

	system._physics_process(0.016)

	assert_eq(system.observed_components, [component])

func test_player_template_components_register_with_manager() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	autofree(player)
	await get_tree().process_frame

	var expected_types := [
		StringName("C_MovementComponent"),
		StringName("C_JumpComponent"),
		StringName("C_InputComponent"),
		StringName("C_RotateToInputComponent"),
	]

	for component_type in expected_types:
		var components := manager.get_components(component_type)
		assert_eq(components.size(), 1, "Expected component %s to auto-register" % component_type)

func test_base_scene_systems_register_with_manager() -> void:
	var scene := BASE_SCENE.instantiate()
	add_child(scene)
	autofree(scene)
	await get_tree().process_frame

	var manager: M_ECSManager = scene.get_node("Managers/M_ECSManager") as M_ECSManager
	assert_not_null(manager)

	var systems: Array = manager.get_systems()
	assert_true(systems.size() >= 1, "Expected systems to auto-register in base scene")
