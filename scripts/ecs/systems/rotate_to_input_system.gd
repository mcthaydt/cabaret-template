extends ECSSystem

class_name RotateToInputSystem

const ROTATE_TYPE := StringName("RotateToInputComponent")

func process_tick(delta: float) -> void:
    for component in get_components(ROTATE_TYPE):
        if component == null:
            continue

        var target = component.get_target_node()
        if target == null:
            continue

        var input_component = component.get_input_component()
        if input_component == null:
            continue

        var move_vector = input_component.move_vector
        if move_vector.length() == 0.0:
            continue

        var desired_direction = Vector3(move_vector.x, 0.0, move_vector.y)
        if desired_direction.length() == 0.0:
            continue
        desired_direction = desired_direction.normalized()

        var desired_yaw = atan2(-desired_direction.x, -desired_direction.z)
        var current_rotation = target.rotation
        var max_delta = deg_to_rad(component.turn_speed_degrees) * delta
        current_rotation.y = _move_toward_angle(current_rotation.y, desired_yaw, max_delta)
        target.rotation = current_rotation

func _move_toward_angle(current: float, target: float, max_delta: float) -> float:
    var difference = wrapf(target - current, -PI, PI)
    if abs(difference) <= max_delta:
        return target
    return current + clamp(difference, -max_delta, max_delta)
