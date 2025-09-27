extends ECSSystem

class_name JumpSystem

const JUMP_TYPE := StringName("JumpComponent")

func process_tick(delta: float) -> void:
    var now = Time.get_ticks_msec() / 1000.0
    for component in get_components(JUMP_TYPE):
        if component == null:
            continue

        var body = component.get_character_body()
        if body == null:
            continue

        var input_component = component.get_input_component()
        if input_component == null:
            continue

        if body.is_on_floor():
            component.mark_on_floor()

        if not input_component.consume_jump():
            continue

        if component.can_jump(now):
            var velocity = body.velocity
            velocity.y = component.jump_force
            body.velocity = velocity
