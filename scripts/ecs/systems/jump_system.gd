extends ECSSystem

class_name JumpSystem

const JUMP_TYPE := StringName("JumpComponent")
const FLOATING_TYPE := StringName("FloatingComponent")

func process_tick(delta: float) -> void:
    var now: float = Time.get_ticks_msec() / 1000.0
    var floating_by_body: Dictionary = {}

    for floating in get_components(FLOATING_TYPE):
        if floating == null:
            continue
        var floating_body = floating.get_character_body()
        if floating_body == null:
            continue
        floating_by_body[floating_body] = floating

    for component in get_components(JUMP_TYPE):
        if component == null:
            continue

        var body = component.get_character_body()
        if body == null:
            continue

        var input_component = component.get_input_component()
        if input_component == null:
            continue

        var floating_component = floating_by_body.get(body, null)
        var has_floating_support := false
        if floating_component != null:
            has_floating_support = floating_component.has_recent_support(now, component.coyote_time)

        if body.is_on_floor() or has_floating_support:
            component.mark_on_floor()

        if not input_component.consume_jump():
            continue

        if component.can_jump(now):
            var velocity = body.velocity
            velocity.y = component.jump_force
            body.velocity = velocity
