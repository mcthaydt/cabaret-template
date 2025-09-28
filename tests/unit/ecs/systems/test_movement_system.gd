extends GutTest

const ECS_MANAGER = preload("res://scripts/ecs/ecs_manager.gd")
const MovementComponentScript = preload("res://scripts/ecs/components/movement_component.gd")
const MovementSystemScript = preload("res://scripts/ecs/systems/movement_system.gd")
const InputComponentScript = preload("res://scripts/ecs/components/input_component.gd")

class FakeBody extends CharacterBody3D:
    var move_called := false

    func move_and_slide() -> bool:
        move_called = true
        return super.move_and_slide()

func _pump() -> void:
    await get_tree().process_frame

func _setup_entity() -> Dictionary:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    await _pump()

    var movement = MovementComponentScript.new()
    add_child(movement)
    await _pump()

    var input = InputComponentScript.new()
    add_child(input)
    await _pump()

    var body := FakeBody.new()
    add_child(body)
    await _pump()

    movement.character_body_path = movement.get_path_to(body)
    movement.input_component_path = movement.get_path_to(input)

    var system = MovementSystemScript.new()
    add_child(system)
    await _pump()

    return {
        "manager": manager,
        "movement": movement,
        "input": input,
        "body": body,
        "system": system,
    }

func test_movement_system_updates_velocity_towards_input() -> void:
    var context := await _setup_entity()
    var movement = context["movement"]
    var input = context["input"]
    var body: FakeBody = context["body"]
    var system = context["system"]

    body.velocity = Vector3.ZERO
    input.set_move_vector(Vector2.RIGHT)

    system._physics_process(0.1)

    assert_true(body.velocity.x > 0.0)
    assert_true(body.velocity.length() <= movement.max_speed + 0.01)
    assert_true(body.move_called)

    await _cleanup(context)

func test_movement_system_applies_deceleration_when_no_input() -> void:
    var context := await _setup_entity()
    var input = context["input"]
    var body: FakeBody = context["body"]
    var system = context["system"]

    body.velocity = Vector3(5, 0, 0)
    input.set_move_vector(Vector2.ZERO)

    system._physics_process(0.1)

    assert_true(body.velocity.x < 5.0)
    assert_true(body.velocity.x >= 0.0)
    assert_true(body.move_called)

    await _cleanup(context)

func test_movement_system_second_order_dynamics_response() -> void:
    var context := await _setup_entity()
    var movement = context["movement"]
    var input = context["input"]
    var body: FakeBody = context["body"]
    var system = context["system"]

    movement.use_second_order_dynamics = true
    movement.response_frequency = 1.0
    movement.damping_ratio = 0.5
    movement.max_speed = 10.0

    body.velocity = Vector3.ZERO
    input.set_move_vector(Vector2.RIGHT)

    system._physics_process(0.1)

    assert_almost_eq(body.velocity.x, 3.9478, 0.01)
    assert_almost_eq(movement.get_horizontal_dynamics_velocity().x, 39.478, 0.1)

    await _cleanup(context)

func test_movement_second_order_settles_quickly_after_input_release() -> void:
    var context := await _setup_entity()
    var movement = context["movement"]
    var input = context["input"]
    var body: FakeBody = context["body"]
    var system = context["system"]

    movement.use_second_order_dynamics = true
    movement.response_frequency = 1.0
    movement.damping_ratio = 0.5
    movement.max_speed = 10.0
    movement.deceleration = 25.0

    body.velocity = Vector3.ZERO
    input.set_move_vector(Vector2.RIGHT)

    system._physics_process(0.1)

    input.set_move_vector(Vector2.ZERO)

    system._physics_process(0.1)

    assert_true(body.velocity.x <= 1.5)
    assert_almost_eq(movement.get_horizontal_dynamics_velocity().x, 0.0, 0.01)

    await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            value.queue_free()
    await _pump()
