extends BaseTest

const ECS_MANAGER = preload("res://scripts/managers/m_ecs_manager.gd")
const RotateComponentScript = preload("res://scripts/ecs/components/c_rotate_to_input_component.gd")
const InputComponentScript = preload("res://scripts/ecs/components/c_input_component.gd")
const RotateSystemScript = preload("res://scripts/ecs/systems/s_rotate_to_input_system.gd")

func _pump() -> void:
    await get_tree().process_frame

func _setup_entity() -> Dictionary:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    await _pump()

    var rotate_component: C_RotateToInputComponent = RotateComponentScript.new()
    rotate_component.settings = RS_RotateToInputSettings.new()
    add_child(rotate_component)
    await _pump()

    var input: C_InputComponent = InputComponentScript.new()
    add_child(input)
    await _pump()

    var body := Node3D.new()
    add_child(body)
    await _pump()

    rotate_component.target_node_path = rotate_component.get_path_to(body)
    rotate_component.input_component_path = rotate_component.get_path_to(input)

    var system: S_RotateToInputSystem = RotateSystemScript.new()
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
    autofree_context(context)
    var input: C_InputComponent = context["input"]
    var body: Node3D = context["body"]
    var system: S_RotateToInputSystem = context["system"]

    body.transform = Transform3D.IDENTITY
    input.set_move_vector(Vector2.RIGHT)

    system._physics_process(0.1)

    assert_true(body.transform != Transform3D.IDENTITY)

func test_rotate_system_uses_second_order_for_smooth_turn() -> void:
    var context := await _setup_entity()
    autofree_context(context)
    var rotate_component: C_RotateToInputComponent = context["rotate_component"]
    var input: C_InputComponent = context["input"]
    var body: Node3D = context["body"]
    var system: S_RotateToInputSystem = context["system"]

    rotate_component.settings.use_second_order = true
    rotate_component.settings.rotation_frequency = 2.0
    rotate_component.settings.rotation_damping = 0.7
    rotate_component.settings.max_turn_speed_degrees = 1080.0

    body.rotation = Vector3.ZERO
    input.set_move_vector(Vector2.RIGHT)

    system._physics_process(0.1)
    var first_rotation := body.rotation.y

    system._physics_process(0.1)
    var second_rotation := body.rotation.y

    var desired_direction: Vector3 = Vector3(input.move_vector.x, 0.0, input.move_vector.y).normalized()
    var desired_yaw: float = atan2(-desired_direction.x, -desired_direction.z)
    var first_error: float = abs(wrapf(desired_yaw - first_rotation, -PI, PI))
    var second_error: float = abs(wrapf(desired_yaw - second_rotation, -PI, PI))

    assert_true(first_rotation < 0.0)
    assert_true(second_error <= first_error + 0.00001)
    assert_true(abs(second_rotation) <= PI / 2.0 + 0.00001)

func test_rotate_system_resets_second_order_state_without_input() -> void:
    var context := await _setup_entity()
    autofree_context(context)
    var rotate_component: C_RotateToInputComponent = context["rotate_component"]
    var input: C_InputComponent = context["input"]
    var body: Node3D = context["body"]
    var system: S_RotateToInputSystem = context["system"]

    rotate_component.settings.use_second_order = true
    rotate_component.settings.rotation_frequency = 2.0
    rotate_component.settings.rotation_damping = 0.7

    body.rotation = Vector3.ZERO
    input.set_move_vector(Vector2.RIGHT)

    system._physics_process(0.1)

    input.set_move_vector(Vector2.ZERO)
    system._physics_process(0.1)

    assert_almost_eq(rotate_component.get_rotation_velocity(), 0.0, 0.001)
