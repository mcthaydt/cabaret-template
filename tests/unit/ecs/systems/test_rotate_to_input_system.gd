extends GutTest

const ECS_MANAGER = preload("res://scripts/ecs/ecs_manager.gd")
const InputComponentScript = preload("res://scripts/ecs/components/input_component.gd")
const RotateComponentScript = preload("res://scripts/ecs/components/rotate_to_input_component.gd")
const RotateSystemScript = preload("res://scripts/ecs/systems/rotate_to_input_system.gd")

func _pump() -> void:
    await get_tree().process_frame

func _setup_context() -> Dictionary:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    await _pump()

    var input = InputComponentScript.new()
    add_child(input)
    await _pump()

    var target = Node3D.new()
    add_child(target)
    await _pump()

    var component = RotateComponentScript.new()
    component.settings = RotateToInputSettings.new()
    add_child(component)
    await _pump()

    component.target_node_path = component.get_path_to(target)
    component.input_component_path = component.get_path_to(input)

    var system = RotateSystemScript.new()
    add_child(system)
    await _pump()

    return {
        "manager": manager,
        "input": input,
        "target": target,
        "component": component,
        "system": system,
    }

func test_rotates_right_input_to_positive_x() -> void:
    var context := await _setup_context()
    var input: InputComponent = context["input"]
    var target: Node3D = context["target"]
    var system: RotateToInputSystem = context["system"]

    input.set_move_vector(Vector2.RIGHT)
    system._physics_process(1.0)

    var expected := -PI / 2.0
    assert_almost_eq(wrapf(target.rotation.y, -PI, PI), expected, 0.001)

    await _cleanup(context)

func test_rotates_left_input_to_negative_x() -> void:
    var context := await _setup_context()
    var input: InputComponent = context["input"]
    var target: Node3D = context["target"]
    var system: RotateToInputSystem = context["system"]

    input.set_move_vector(Vector2.LEFT)
    system._physics_process(1.0)

    var expected := PI / 2.0
    assert_almost_eq(wrapf(target.rotation.y, -PI, PI), expected, 0.001)

    await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            value.queue_free()
    await _pump()
