extends GutTest

const ECS_MANAGER = preload("res://scripts/ecs/ecs_manager.gd")
const RotateComponentScript = preload("res://scripts/ecs/components/rotate_to_input_component.gd")
const InputComponentScript = preload("res://scripts/ecs/components/input_component.gd")
const RotateSystemScript = preload("res://scripts/ecs/systems/rotate_to_input_system.gd")

func _pump() -> void:
    await get_tree().process_frame

func _setup_entity() -> Dictionary:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    await _pump()

    var rotate_component = RotateComponentScript.new()
    add_child(rotate_component)
    await _pump()

    var input = InputComponentScript.new()
    add_child(input)
    await _pump()

    var body := Node3D.new()
    add_child(body)
    await _pump()

    rotate_component.target_node_path = rotate_component.get_path_to(body)
    rotate_component.input_component_path = rotate_component.get_path_to(input)

    var system = RotateSystemScript.new()
    add_child(system)
    await _pump()

    return {
        "manager": manager,
        "rotate_component": rotate_component,
        "input": input,
        "body": body,
        "system": system,
    }

func test_rotate_system_turns_towards_input_direction() -> void:
    var context := await _setup_entity()
    var input = context["input"]
    var body: Node3D = context["body"]
    var system = context["system"]

    body.transform = Transform3D.IDENTITY
    input.set_move_vector(Vector2.RIGHT)

    system._physics_process(0.1)

    assert_true(body.transform != Transform3D.IDENTITY)

    await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            value.queue_free()
    await _pump()
