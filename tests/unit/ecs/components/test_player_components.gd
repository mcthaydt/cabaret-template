extends GutTest

const ECS_MANAGER := preload("res://scripts/ecs/ecs_manager.gd")
const MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/movement_component.gd")
const JUMP_COMPONENT := preload("res://scripts/ecs/components/jump_component.gd")
const INPUT_COMPONENT := preload("res://scripts/ecs/components/input_component.gd")
const ROTATE_COMPONENT := preload("res://scripts/ecs/components/rotate_to_input_component.gd")

func _add_manager() -> ECS_MANAGER:
    var manager := ECS_MANAGER.new()
    add_child(manager)
    return manager

func _pump() -> void:
    await get_tree().process_frame

func test_movement_component_defaults_and_registration() -> void:
    var manager := _add_manager()
    await _pump()

    var component := MOVEMENT_COMPONENT.new()
    component.settings = MovementSettings.new()
    add_child(component)
    await _pump()

    assert_eq(component.get_component_type(), MOVEMENT_COMPONENT.COMPONENT_TYPE)
    assert_eq(component.settings.max_speed, 6.0)
    assert_eq(component.settings.acceleration, 20.0)
    assert_eq(component.settings.deceleration, 25.0)

    var components := manager.get_components(MOVEMENT_COMPONENT.COMPONENT_TYPE)
    assert_eq(components, [component])

    component.queue_free()
    manager.queue_free()
    await _pump()

func test_jump_component_defaults_and_registration() -> void:
    var manager := _add_manager()
    await _pump()

    var component := JUMP_COMPONENT.new()
    component.settings = JumpSettings.new()
    add_child(component)
    await _pump()

    assert_eq(component.get_component_type(), JUMP_COMPONENT.COMPONENT_TYPE)
    assert_eq(component.settings.jump_force, 12.0)
    assert_eq(component.settings.coyote_time, 0.15)
    assert_eq(component.settings.max_air_jumps, 0)

    var components := manager.get_components(JUMP_COMPONENT.COMPONENT_TYPE)
    assert_eq(components, [component])

    component.queue_free()
    manager.queue_free()
    await _pump()

func test_input_component_defaults_and_registration() -> void:
    var manager := _add_manager()
    await _pump()

    var component := INPUT_COMPONENT.new()
    add_child(component)
    await _pump()

    assert_eq(component.get_component_type(), INPUT_COMPONENT.COMPONENT_TYPE)
    assert_eq(component.move_vector, Vector2.ZERO)
    assert_false(component.jump_pressed)

    var components := manager.get_components(INPUT_COMPONENT.COMPONENT_TYPE)
    assert_eq(components, [component])

    component.queue_free()
    manager.queue_free()
    await _pump()

func test_rotate_component_defaults_and_registration() -> void:
    var manager := _add_manager()
    await _pump()

    var component := ROTATE_COMPONENT.new()
    component.settings = RotateToInputSettings.new()
    add_child(component)
    await _pump()

    assert_eq(component.get_component_type(), ROTATE_COMPONENT.COMPONENT_TYPE)
    assert_eq(component.settings.turn_speed_degrees, 720.0)

    var components := manager.get_components(ROTATE_COMPONENT.COMPONENT_TYPE)
    assert_eq(components, [component])

    component.queue_free()
    manager.queue_free()
    await _pump()
