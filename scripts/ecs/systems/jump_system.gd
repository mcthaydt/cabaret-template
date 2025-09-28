extends ECSSystem

class_name JumpSystem

const JUMP_TYPE := StringName("JumpComponent")
const FLOATING_TYPE := StringName("FloatingComponent")

func process_tick(_delta: float) -> void:
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

        var floating_component: FloatingComponent = floating_by_body.get(body, null) as FloatingComponent
        var floating_supported_now: bool = false
        var has_floating_support: bool = false
        if floating_component != null:
            floating_supported_now = floating_component.is_supported
            has_floating_support = floating_component.has_recent_support(now, component.coyote_time)

        component.update_vertical_state(body.velocity.y, now)

        var supported_now: bool = body.is_on_floor() or floating_supported_now
        if supported_now:
            component.mark_on_floor(now)
        var support_recent: bool = supported_now or has_floating_support

        var jump_requested: bool = input_component.has_jump_request(component.jump_buffer_time, now)
        if not jump_requested:
            component.update_debug_snapshot({
                "supported": supported_now,
                "support_recent": support_recent,
                "requested": false,
                "performed": false,
                "has_air_jumps": component.has_air_jumps_remaining(),
                "recent_apex": component.has_recent_apex(now),
            })
            continue

        if not component.can_jump(now):
            component.update_debug_snapshot({
                "supported": supported_now,
                "support_recent": support_recent,
                "requested": true,
                "performed": false,
                "has_air_jumps": component.has_air_jumps_remaining(),
                "recent_apex": component.has_recent_apex(now),
            })
            continue

        if not input_component.consume_jump_request():
            continue

        component.on_jump_performed(now, supported_now)
        var velocity = body.velocity
        velocity.y = component.jump_force
        body.velocity = velocity
        component.update_debug_snapshot({
            "supported": supported_now,
            "support_recent": support_recent,
            "requested": true,
            "performed": true,
            "has_air_jumps": component.has_air_jumps_remaining(),
            "recent_apex": component.has_recent_apex(now),
        })
