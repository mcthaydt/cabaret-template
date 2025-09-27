extends ECSSystem

class_name MovementSystem

const MOVEMENT_TYPE := StringName("MovementComponent")

func process_tick(delta: float) -> void:
    var body_state := {}
    var bodies := []

    for component in get_components(MOVEMENT_TYPE):
        if component == null:
            continue

        var body = component.get_character_body()
        if body == null:
            continue

        var state = body_state.get(body, null)
        if state == null:
            state = {
                "velocity": body.velocity,
            }
            body_state[body] = state
            bodies.append(body)

        var velocity: Vector3 = state.velocity

        var input_component = component.get_input_component()
        var input_vector := Vector2.ZERO
        if input_component != null:
            input_vector = input_component.move_vector

        if input_vector.length() > 0.0:
            var desired_velocity = _get_desired_velocity(input_vector, component.max_speed)
            velocity.x = move_toward(velocity.x, desired_velocity.x, component.acceleration * delta)
            velocity.z = move_toward(velocity.z, desired_velocity.z, component.acceleration * delta)
        else:
            velocity.x = move_toward(velocity.x, 0.0, component.deceleration * delta)
            velocity.z = move_toward(velocity.z, 0.0, component.deceleration * delta)

        velocity = _clamp_horizontal_speed(velocity, component.max_speed)
        state.velocity = velocity

    for body in bodies:
        var final_velocity: Vector3 = body_state[body].velocity
        body.velocity = final_velocity
        if body.has_method("move_and_slide"):
            body.move_and_slide()

func _get_desired_velocity(input_vector: Vector2, max_speed: float) -> Vector3:
    var normalized = input_vector
    if normalized.length() > 1.0:
        normalized = normalized.normalized()
    return Vector3(normalized.x, 0.0, normalized.y) * max_speed

func _clamp_horizontal_speed(velocity: Vector3, max_speed: float) -> Vector3:
    var horizontal := Vector3(velocity.x, 0.0, velocity.z)
    if horizontal.length() > max_speed:
        horizontal = horizontal.normalized() * max_speed
        velocity.x = horizontal.x
        velocity.z = horizontal.z
    return velocity
