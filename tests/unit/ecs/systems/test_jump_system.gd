extends GutTest

const ECS_MANAGER = preload("res://scripts/ecs/ecs_manager.gd")
const JumpComponentScript = preload("res://scripts/ecs/components/jump_component.gd")
const InputComponentScript = preload("res://scripts/ecs/components/input_component.gd")
const JumpSystemScript = preload("res://scripts/ecs/systems/jump_system.gd")

class FakeBody extends CharacterBody3D:
    var grounded := true

    func is_on_floor() -> bool:
        return grounded

func _pump() -> void:
    await get_tree().process_frame

func _setup_entity() -> Dictionary:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    await _pump()

    var jump_component = JumpComponentScript.new()
    add_child(jump_component)
    await _pump()

    var input = InputComponentScript.new()
    add_child(input)
    await _pump()

    var body := FakeBody.new()
    add_child(body)
    await _pump()

    jump_component.character_body_path = jump_component.get_path_to(body)
    jump_component.input_component_path = jump_component.get_path_to(input)

    var system = JumpSystemScript.new()
    add_child(system)
    await _pump()

    return {
        "manager": manager,
        "jump": jump_component,
        "input": input,
        "body": body,
        "system": system,
    }

func test_jump_system_applies_vertical_velocity_when_jump_pressed() -> void:
    var context := await _setup_entity()
    var jump = context["jump"]
    var input = context["input"]
    var body: FakeBody = context["body"]
    var system = context["system"]

    body.velocity = Vector3.ZERO
    body.grounded = true

    input.set_jump_pressed(true)

    system._physics_process(0.016)

    assert_true(body.velocity.y > 0.0)
    assert_eq(body.velocity.y, jump.jump_force)

    await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            value.queue_free()
    await _pump()
