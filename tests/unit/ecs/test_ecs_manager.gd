extends GutTest

const ECS_MANAGER := preload("res://scripts/ecs/ecs_manager.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/ecs_component.gd")
const ECS_SYSTEM := preload("res://scripts/ecs/ecs_system.gd")
const PLAYER_SCENE := preload("res://templates/player_template.tscn")
const BASE_SCENE := preload("res://templates/base_scene_template.tscn")

class FakeComponent extends ECS_COMPONENT:
    const TYPE := StringName("FakeComponent")

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
    var manager := ECS_MANAGER.new()
    add_child(manager)
    await get_tree().process_frame

    var component := FakeComponent.new()
    add_child(component)
    await get_tree().process_frame

    var components := manager.get_components(FakeComponent.TYPE)
    assert_eq(components, [component])

    component.queue_free()
    manager.queue_free()
    await get_tree().process_frame

func test_system_auto_registers_with_manager_on_ready() -> void:
    var manager := ECS_MANAGER.new()
    add_child(manager)
    await get_tree().process_frame

    var system := FakeSystem.new()
    add_child(system)
    await get_tree().process_frame

    var systems: Array = manager.get_systems()
    assert_true(systems.has(system))
    assert_eq(system.get_manager(), manager)

    system.queue_free()
    manager.queue_free()
    await get_tree().process_frame

func test_register_component_adds_to_lookup() -> void:
    var manager := ECS_MANAGER.new()
    add_child(manager)

    var component := FakeComponent.new()
    manager.register_component(component)

    var components := manager.get_components(FakeComponent.TYPE)
    assert_not_null(components)
    assert_eq(components.size(), 1)
    assert_true(components.has(component))

    component.queue_free()
    manager.queue_free()
    await get_tree().process_frame

func test_register_component_emits_signals() -> void:
    var manager := ECS_MANAGER.new()
    add_child(manager)

    var component := FakeComponent.new()
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

    component.queue_free()
    manager.queue_free()
    await get_tree().process_frame

func test_register_system_configures_and_queries_components() -> void:
    var manager := ECS_MANAGER.new()
    add_child(manager)

    var component := FakeComponent.new()
    manager.register_component(component)

    var system := FakeSystem.new()
    manager.register_system(system)

    system._physics_process(0.016)

    assert_eq(system.observed_components, [component])

    system.queue_free()
    component.queue_free()
    manager.queue_free()
    await get_tree().process_frame

func test_player_template_components_register_with_manager() -> void:
    var manager := ECS_MANAGER.new()
    add_child(manager)
    await get_tree().process_frame

    var player := PLAYER_SCENE.instantiate()
    add_child(player)
    await get_tree().process_frame

    var expected_types := [
        StringName("MovementComponent"),
        StringName("JumpComponent"),
        StringName("InputComponent"),
        StringName("RotateToInputComponent"),
    ]

    for component_type in expected_types:
        var components := manager.get_components(component_type)
        assert_eq(components.size(), 1, "Expected component %s to auto-register" % component_type)

    player.queue_free()
    manager.queue_free()
    await get_tree().process_frame

func test_base_scene_systems_register_with_manager() -> void:
    var scene := BASE_SCENE.instantiate()
    add_child(scene)
    await get_tree().process_frame

    var manager := scene.get_node("Managers/ECS_Manager")
    assert_not_null(manager)

    var systems: Array = manager.get_systems()
    assert_true(systems.size() >= 1, "Expected systems to auto-register in base scene")

    scene.queue_free()
    await get_tree().process_frame
