extends GutTest

const ECS_MANAGER = preload("res://scripts/ecs/ecs_manager.gd")
const InputComponentScript = preload("res://scripts/ecs/components/input_component.gd")
const InputSystemScript = preload("res://scripts/ecs/systems/input_system.gd")

func before_all() -> void:
    _ensure_action("move_left")
    _ensure_action("move_right")
    _ensure_action("move_forward")
    _ensure_action("move_backward")
    _ensure_action("jump")

func after_each() -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    Input.action_release("move_forward")
    Input.action_release("move_backward")
    Input.action_release("jump")

func _pump() -> void:
    await get_tree().process_frame

func _setup_entity() -> Dictionary:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    await _pump()

    var component = InputComponentScript.new()
    add_child(component)
    await _pump()

    var system = InputSystemScript.new()
    add_child(system)
    await _pump()

    return {
        "manager": manager,
        "component": component,
        "system": system,
    }

func test_input_system_updates_move_vector_from_actions() -> void:
    var context := await _setup_entity()
    var component = context["component"]
    var system = context["system"]

    Input.action_press("move_right")
    Input.action_press("move_forward")

    system._physics_process(0.016)

    assert_almost_eq(component.move_vector.x, 0.7071, 0.01)
    assert_almost_eq(component.move_vector.y, -0.7071, 0.01)

    await _cleanup(context)

func test_input_system_sets_jump_flag_on_press() -> void:
    var context := await _setup_entity()
    var component = context["component"]
    var system = context["system"]

    Input.action_press("jump")

    system._physics_process(0.016)

    assert_true(component.jump_pressed)

    await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            value.queue_free()
    await _pump()

func _ensure_action(action_name: String) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
