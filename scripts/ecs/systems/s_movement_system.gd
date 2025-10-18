extends ECSSystem

class_name S_MovementSystem

const MOVEMENT_TYPE := StringName("C_MovementComponent")

func process_tick(delta: float) -> void:
	var body_state := {}
	var bodies := []
	var current_time := Time.get_ticks_msec() / 1000.0

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
		var input_vector: Vector2 = Vector2.ZERO
		var is_sprinting := false
		var current_max_speed: float = component.settings.max_speed
		if input_component != null:
			input_vector = input_component.move_vector
			is_sprinting = input_component.is_sprinting()
			if is_sprinting:
				var sprint_multiplier: float = component.settings.sprint_speed_multiplier
				if sprint_multiplier <= 0.0:
					sprint_multiplier = 1.0
				current_max_speed = component.settings.max_speed * sprint_multiplier

		var has_input: bool = input_vector.length() > 0.0
		var desired_velocity: Vector3 = Vector3.ZERO
		if has_input:
			desired_velocity = _get_desired_velocity(input_vector, current_max_speed)

		var support_component: C_FloatingComponent = component.get_support_component()
		var support_active: bool = false
		if support_component != null:
			support_active = support_component.has_recent_support(current_time, component.settings.support_grace_time)

		var wants_second_order: bool = component.settings.use_second_order_dynamics and component.settings.response_frequency > 0.0
		if wants_second_order and has_input:
			velocity = _apply_second_order_dynamics(component, velocity, desired_velocity, delta, support_active)
			velocity = _clamp_horizontal_speed(velocity, current_max_speed)
		else:
			if has_input:
				velocity.x = move_toward(velocity.x, desired_velocity.x, component.settings.acceleration * delta)
				velocity.z = move_toward(velocity.z, desired_velocity.z, component.settings.acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, component.settings.deceleration * delta)
				velocity.z = move_toward(velocity.z, 0.0, component.settings.deceleration * delta)
			component.reset_dynamics_state()

		if not has_input:
			velocity = _apply_horizontal_friction(component, velocity, support_active, delta)

		velocity = _clamp_horizontal_speed(velocity, current_max_speed)

		state.velocity = velocity

		component.update_debug_snapshot({
			"supported": support_active,
			"has_input": has_input,
			"is_sprinting": is_sprinting,
			"desired_velocity": Vector2(desired_velocity.x, desired_velocity.z),
			"current_velocity": Vector2(velocity.x, velocity.z),
			"dynamics_velocity": component.get_horizontal_dynamics_velocity(),
		})

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

func _apply_second_order_dynamics(component: C_MovementComponent, velocity: Vector3, desired_velocity: Vector3, delta: float, support_active: bool) -> Vector3:
	var frequency: float = max(component.settings.response_frequency, 0.0)
	if frequency <= 0.0:
		component.reset_dynamics_state()
		return velocity

	var damping_base: float = max(component.settings.damping_ratio, 0.0)
	var damping_multiplier: float = component.settings.grounded_damping_multiplier if support_active else component.settings.air_damping_multiplier
	var damping: float = damping_base * damping_multiplier
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

func _apply_horizontal_friction(component: C_MovementComponent, velocity: Vector3, support_active: bool, delta: float) -> Vector3:
	var base_friction: float = component.settings.grounded_friction if support_active else component.settings.air_friction
	if base_friction <= 0.0:
		return velocity

	var strafe_friction: float = max(base_friction * component.settings.strafe_friction_scale, 0.0)
	var forward_friction: float = max(base_friction * component.settings.forward_friction_scale, 0.0)

	velocity.x = move_toward(velocity.x, 0.0, strafe_friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, forward_friction * delta)
	return velocity
