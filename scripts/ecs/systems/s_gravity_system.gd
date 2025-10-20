@icon("res://editor_icons/system.svg")
extends ECSSystem
class_name S_GravitySystem

@export var gravity: float = 30.0
const MOVEMENT_TYPE := StringName("C_MovementComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")

func process_tick(delta: float) -> void:
    var processed := {}
    var floating_by_body: Dictionary = {}

    # Collect bodies that have a floating component so the floating system
    # owns vertical motion (prevents double gravity).
    for floating in get_components(FLOATING_TYPE):
        if floating == null:
            continue
        var floating_body = floating.get_character_body()
        if floating_body == null:
            continue
        floating_by_body[floating_body] = true

    for component in get_components(MOVEMENT_TYPE):
        if component == null:
            continue

        var body = component.get_character_body()
        if body == null:
            continue

        if processed.has(body):
            continue
        processed[body] = true

        # Skip bodies managed by floating to avoid double gravity.
        if floating_by_body.has(body):
            continue

        if body.is_on_floor():
            continue

        var velocity = body.velocity
        velocity.y -= gravity * delta
        body.velocity = velocity
