@icon("res://resources/editor_icons/system.svg")
extends ECSSystem
class_name S_GravitySystem

@export var gravity: float = 30.0
const MOVEMENT_TYPE := StringName("C_MovementComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")

func process_tick(delta: float) -> void:
	var manager := get_manager()
	if manager == null:
		return

	var processed := {}
	var floating_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, FLOATING_TYPE)
	var entities := manager.query_entities(
		[
			MOVEMENT_TYPE,
		],
		[
			FLOATING_TYPE,
		]
	)

	for entity_query in entities:
		var movement_component: C_MovementComponent = entity_query.get_component(MOVEMENT_TYPE)
		if movement_component == null:
			continue

		var body := movement_component.get_character_body()
		if body == null:
			continue

		if processed.has(body):
			continue
		processed[body] = true

		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		if floating_component == null and floating_by_body.has(body):
			floating_component = floating_by_body[body] as C_FloatingComponent
		if floating_component != null:
			continue

		if body.is_on_floor():
			continue

		var velocity := body.velocity
		velocity.y -= gravity * delta
		body.velocity = velocity
