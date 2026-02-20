@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_GravitySystem

## Phase 16: Reads gravity_scale from state for zone-based modifiers

@export var gravity: float = 30.0

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null

const MOVEMENT_TYPE := StringName("C_MovementComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")
const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const CHARACTER_STATE_TYPE := C_CHARACTER_STATE_COMPONENT.COMPONENT_TYPE

func process_tick(delta: float) -> void:
	# Use injected store if available (Phase 10B-8)
	var store: I_StateStore = null
	if state_store != null:
		store = state_store
	else:
		store = U_StateUtils.get_store(self)
	
	var manager := get_manager()
	if manager == null:
		return

	var processed := {}
	var floating_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, FLOATING_TYPE)
	var character_state_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, CHARACTER_STATE_TYPE)

	var entities := manager.query_entities(
		[
			MOVEMENT_TYPE,
		],
		[
			FLOATING_TYPE,
			CHARACTER_STATE_TYPE,
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

		var character_state: C_CharacterStateComponent = entity_query.get_component(CHARACTER_STATE_TYPE)
		if character_state == null:
			character_state = character_state_by_body.get(body, null) as C_CharacterStateComponent
		if character_state != null and not character_state.is_gameplay_active:
			continue

		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		if floating_component == null and floating_by_body.has(body):
			floating_component = floating_by_body[body] as C_FloatingComponent
		if floating_component != null:
			continue

		if body.is_on_floor():
			continue

		# Phase 16: Apply gravity_scale from state (for low-gravity zones, etc.)
		var gravity_scale: float = 1.0
		if store:
			gravity_scale = U_PhysicsSelectors.get_gravity_scale(store.get_state())
			
			var velocity := body.velocity
			velocity.y -= gravity * gravity_scale * delta
			body.velocity = velocity
