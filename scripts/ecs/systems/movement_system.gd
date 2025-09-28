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

		var has_input: bool = input_vector.length() > 0.0
		var desired_velocity := Vector3.ZERO
		if has_input:
			desired_velocity = _get_desired_velocity(input_vector, component.max_speed)

		var wants_second_order: bool = component.use_second_order_dynamics and component.response_frequency > 0.0
		if wants_second_order and has_input:
			velocity = _apply_second_order_dynamics(component, velocity, desired_velocity, delta)
		else:
			if has_input:
				velocity.x = move_toward(velocity.x, desired_velocity.x, component.acceleration * delta)
				velocity.z = move_toward(velocity.z, desired_velocity.z, component.acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, component.deceleration * delta)
				velocity.z = move_toward(velocity.z, 0.0, component.deceleration * delta)
			component.reset_dynamics_state()

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

func _apply_second_order_dynamics(component: MovementComponent, velocity: Vector3, desired_velocity: Vector3, delta: float) -> Vector3:
	var frequency: float = max(component.response_frequency, 0.0)
	if frequency <= 0.0:
		component.reset_dynamics_state()
		return velocity

	var damping: float = max(component.damping_ratio, 0.0)
	var omega: float = TAU * frequency
	if omega <= 0.0:
		component.reset_dynamics_state()
		return velocity

	var current_horizontal := Vector2(velocity.x, velocity.z)
	var target_horizontal := Vector2(desired_velocity.x, desired_velocity.z)
	var dynamics_velocity: Vector2 = component.get_horizontal_dynamics_velocity()
	var error: Vector2 = target_horizontal - current_horizontal
	var accel: Vector2 = error * (omega * omega) - dynamics_velocity * (2.0 * damping * omega)
	dynamics_velocity += accel * delta
	current_horizontal += dynamics_velocity * delta
	component.set_horizontal_dynamics_velocity(dynamics_velocity)
	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.y
	return velocity
