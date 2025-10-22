@icon("res://resources/editor_icons/system.svg")
extends ECSSystem
class_name S_RotateToInputSystem

const ROTATE_TYPE := StringName("C_RotateToInputComponent")
const INPUT_TYPE := StringName("C_InputComponent")

func process_tick(delta: float) -> void:
	var manager := get_manager()
	if manager == null:
		return

	var entities := manager.query_entities(
		[
			ROTATE_TYPE,
			INPUT_TYPE,
		]
	)

	for entity_query in entities:
		var component: C_RotateToInputComponent = entity_query.get_component(ROTATE_TYPE)
		if component == null:
			continue

		var target := component.get_target_node()
		if target == null:
			continue

		var input_component: C_InputComponent = entity_query.get_component(INPUT_TYPE)
		if input_component == null:
			continue

		var move_vector := input_component.move_vector
		if move_vector.length() == 0.0:
			component.reset_rotation_state()
			continue

		var desired_direction := Vector3(move_vector.x, 0.0, move_vector.y)
		if desired_direction.length() == 0.0:
			continue
		desired_direction = desired_direction.normalized()

		var desired_yaw := atan2(-desired_direction.x, -desired_direction.z)
		var current_rotation := target.rotation
		var max_turn: float = component.settings.max_turn_speed_degrees
		if max_turn <= 0.0:
			max_turn = component.settings.turn_speed_degrees
		var max_delta := deg_to_rad(max_turn) * delta

		if component.settings.use_second_order and component.settings.rotation_frequency > 0.0:
			_apply_second_order_rotation(component, target, desired_yaw, delta, max_delta)
		else:
			current_rotation.y = _move_toward_angle(current_rotation.y, desired_yaw, max_delta)
			target.rotation = current_rotation
			component.reset_rotation_state()

func _move_toward_angle(current: float, target: float, max_delta: float) -> float:
	var difference = wrapf(target - current, -PI, PI)
	if abs(difference) <= max_delta:
		return target
	return current + clamp(difference, -max_delta, max_delta)

func _apply_second_order_rotation(component: C_RotateToInputComponent, target: Node3D, desired_yaw: float, delta: float, max_delta: float) -> void:
	var current_rotation := target.rotation
	var current_yaw := current_rotation.y
	var error := wrapf(desired_yaw - current_yaw, -PI, PI)
	var omega: float = TAU * component.settings.rotation_frequency
	if omega <= 0.0:
		component.reset_rotation_state()
		return

	var damping: float = max(component.settings.rotation_damping, 0.0)
	var velocity: float = component.get_rotation_velocity()
	var accel: float = (omega * omega * error) - (2.0 * damping * omega * velocity)
	velocity += accel * delta
	var max_speed := INF
	if max_delta > 0.0 and delta > 0.0:
		max_speed = max_delta / delta
	if max_speed != INF:
		velocity = clamp(velocity, -max_speed, max_speed)
	var delta_yaw := velocity * delta
	if sign(delta_yaw) == sign(error) and abs(delta_yaw) > abs(error) and delta > 0.0:
		delta_yaw = error
		velocity = delta_yaw / delta
	current_yaw += delta_yaw
	component.set_rotation_velocity(velocity)
	current_rotation.y = wrapf(current_yaw, -PI, PI)
	target.rotation = current_rotation
