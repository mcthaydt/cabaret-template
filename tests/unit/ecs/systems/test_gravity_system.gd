extends GutTest

const ECS_MANAGER = preload("res://scripts/ecs/m_ecs_manager.gd")
const GravitySystemScript = preload("res://scripts/ecs/systems/s_gravity_system.gd")
const MovementComponentScript = preload("res://scripts/ecs/components/c_movement_component.gd")

class FakeBody extends CharacterBody3D:
    var grounded := false

    @warning_ignore("native_method_override")
    func is_on_floor() -> bool:
        return grounded

func _pump() -> void:
    await get_tree().process_frame

func _setup_entity() -> Dictionary:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    await _pump()

    var body := FakeBody.new()
    add_child(body)
    await _pump()

    var movement: C_MovementComponent = MovementComponentScript.new()
    movement.settings = RS_MovementSettings.new()
    add_child(movement)
    await _pump()

    movement.character_body_path = movement.get_path_to(body)

    var system = GravitySystemScript.new()
    add_child(system)
    await _pump()

    return {
        "manager": manager,
        "body": body,
        "movement": movement,
        "system": system,
    }

func test_gravity_system_accelerates_downward_when_not_on_floor() -> void:
    var context := await _setup_entity()
    var body: FakeBody = context["body"]
    var system = context["system"]

    body.velocity = Vector3.ZERO
    body.grounded = false

    system._physics_process(0.1)

    assert_true(body.velocity.y < 0.0)

    await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            value.queue_free()
    await _pump()
