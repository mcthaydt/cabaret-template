@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_GravitySystem

## Phase 16: Reads gravity_scale from state for zone-based modifiers

@export var gravity: float = 30.0

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null
@export var debug_ai_gravity_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.25
@export var debug_entity_id: StringName = StringName("patrol_drone")

const MOVEMENT_TYPE := StringName("C_MovementComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")
const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const CHARACTER_STATE_TYPE := C_CHARACTER_STATE_COMPONENT.COMPONENT_TYPE
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/utils/debug/u_debug_log_throttle.gd")

var _debug_log_throttle: Variant = U_DEBUG_LOG_THROTTLE.new()

func process_tick(delta: float) -> void:
	_debug_log_throttle.tick(delta)
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
		var entity_id: StringName = _resolve_entity_id_from_query(entity_query)
		var movement_component: C_MovementComponent = entity_query.get_component(MOVEMENT_TYPE)
		if movement_component == null:
			_debug_log(entity_id, "skip: missing C_MovementComponent")
			continue

		var body := movement_component.get_character_body()
		if body == null:
			_debug_log(entity_id, "skip: movement body is null")
			continue

		if processed.has(body):
			continue
		processed[body] = true

		var character_state: C_CharacterStateComponent = entity_query.get_component(CHARACTER_STATE_TYPE)
		if character_state == null:
			character_state = character_state_by_body.get(body, null) as C_CharacterStateComponent
		if character_state != null and not character_state.is_gameplay_active:
			_debug_log(
				entity_id,
				"skip: character_state inactive body_pos=%s vel=%s"
				% [str(body.global_position), str(body.velocity)]
			)
			continue

		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		if floating_component == null and floating_by_body.has(body):
			floating_component = floating_by_body[body] as C_FloatingComponent
		if floating_component != null:
			_debug_log(
				entity_id,
				"skip: floating present is_supported=%s grounded_stable=%s body_pos=%s vel=%s"
				% [
					str(floating_component.is_supported),
					str(floating_component.grounded_stable),
					str(body.global_position),
					str(body.velocity),
				]
			)
			continue

		if body.is_on_floor():
			_debug_log(
				entity_id,
				"skip: is_on_floor=true body_pos=%s vel=%s"
				% [str(body.global_position), str(body.velocity)]
			)
			continue

		# Phase 16: Apply gravity_scale from state (for low-gravity zones, etc.)
		var gravity_scale: float = 1.0
		if store:
			gravity_scale = U_PhysicsSelectors.get_gravity_scale(store.get_state())

		var velocity := body.velocity
		var before_y: float = velocity.y
		velocity.y -= gravity * gravity_scale * delta
		body.velocity = velocity
		_debug_log(
			entity_id,
			"apply: gravity=%.3f gravity_scale=%.3f before_y=%.3f after_y=%.3f body_pos=%s"
			% [
				gravity,
				gravity_scale,
				before_y,
				velocity.y,
				str(body.global_position),
			]
		)

func _resolve_entity_id_from_query(entity_query: Object) -> StringName:
	if entity_query == null:
		return StringName()
	if entity_query.has_method("get_entity_id"):
		var id_variant: Variant = entity_query.call("get_entity_id")
		if id_variant is StringName:
			return id_variant as StringName
		if id_variant is String:
			var id_text: String = id_variant
			if not id_text.is_empty():
				return StringName(id_text)

	var entity_variant: Variant = entity_query.get("entity")
	if entity_variant is Node:
		return ECS_UTILS.get_entity_id(entity_variant as Node)
	return StringName()

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_ai_gravity_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false
	return _debug_log_throttle.consume_budget(entity_id, maxf(debug_log_interval_sec, 0.05))

func _debug_log(entity_id: StringName, message: String) -> void:
	if not _consume_debug_log_budget(entity_id):
		return
	print("S_GravitySystem[entity=%s] %s" % [str(entity_id), message])
