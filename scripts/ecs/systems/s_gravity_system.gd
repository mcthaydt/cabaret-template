extends ECSSystem

class_name S_GravitySystem

@export var gravity: float = 30.0
const MOVEMENT_TYPE := StringName("C_MovementComponent")

func process_tick(delta: float) -> void:
    var processed := {}
    for component in get_components(MOVEMENT_TYPE):
        if component == null:
            continue

        var body = component.get_character_body()
        if body == null:
            continue

        if processed.has(body):
            continue
        processed[body] = true

        if body.is_on_floor():
            continue

        var velocity = body.velocity
        velocity.y -= gravity * delta
        body.velocity = velocity
