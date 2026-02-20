@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_JumpSystem

## Phase 16: Dispatches floor state to state store

const JUMP_TYPE := StringName("C_JumpComponent")
const INPUT_TYPE := StringName("C_InputComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")
const EVENT_ENTITY_JUMPED := StringName("entity_jumped")
const EVENT_ENTITY_LANDED := StringName("entity_landed")
const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const CHARACTER_STATE_TYPE := C_CHARACTER_STATE_COMPONENT.COMPONENT_TYPE
const C_SPAWN_STATE_COMPONENT := preload("res://scripts/ecs/components/c_spawn_state_component.gd")
const SPAWN_STATE_TYPE := C_SPAWN_STATE_COMPONENT.COMPONENT_TYPE

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null


func process_tick(__delta: float) -> void:
	# Use injected store if available (Phase 10B-8)
	var store: I_StateStore = null
	if state_store != null:
		store = state_store
	else:
		store = U_StateUtils.get_store(self)

	var accessibility_jump_buffer: float = -1.0
	if store:
		var state: Dictionary = store.get_state()
		var settings_variant: Variant = state.get("settings", {})
		if settings_variant is Dictionary:
			var settings_dict := settings_variant as Dictionary
			var input_settings_variant: Variant = settings_dict.get("input_settings", {})
			if input_settings_variant is Dictionary:
				var input_settings := input_settings_variant as Dictionary
				var accessibility_variant: Variant = input_settings.get("accessibility", {})
				if accessibility_variant is Dictionary:
					var accessibility := accessibility_variant as Dictionary
					accessibility_jump_buffer = float(accessibility.get("jump_buffer_time", accessibility_jump_buffer))
		
	var manager := get_manager()
	if manager == null:
		return
	
	var now: float = ECS_UTILS.get_current_time()
	var current_physics_frame: int = Engine.get_physics_frames()
	# Jump requires input; floating is optional to extend support windows.
	var entities: Array = manager.query_entities(
		[
			JUMP_TYPE,
			INPUT_TYPE,
		],
		[
			FLOATING_TYPE,
			CHARACTER_STATE_TYPE,
		]
	)
	var floating_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, FLOATING_TYPE)
	var spawn_state_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, SPAWN_STATE_TYPE)
	var character_state_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, CHARACTER_STATE_TYPE)

	for entity_query in entities:
		var component: C_JumpComponent = entity_query.get_component(JUMP_TYPE)
		var input_component: C_InputComponent = entity_query.get_component(INPUT_TYPE)
		if component == null or input_component == null:
			continue

		var body = component.get_character_body()
		if body == null:
			continue

		var character_state: C_CharacterStateComponent = entity_query.get_component(CHARACTER_STATE_TYPE)
		if character_state == null:
			character_state = character_state_by_body.get(body, null) as C_CharacterStateComponent
		if character_state != null and not character_state.is_gameplay_active:
			continue

		var spawn_state: C_SpawnStateComponent = spawn_state_by_body.get(body, null) as C_SpawnStateComponent
		var is_spawn_frozen: bool = false
		if character_state != null:
			is_spawn_frozen = character_state.is_spawn_frozen
		elif spawn_state != null:
			is_spawn_frozen = spawn_state.is_physics_frozen
		if is_spawn_frozen:
			component.update_debug_snapshot({
				"spawn_frozen": true,
			})
			continue
		
		var suppress_landing_event: bool = _is_spawn_landing_event_suppressed(spawn_state, current_physics_frame)

		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		if floating_component == null:
			floating_component = floating_by_body.get(body, null) as C_FloatingComponent
		var floating_supported_now: bool = false
		var _floating_stable_grounded: bool = false
		var has_floating_support: bool = false
		if floating_component != null:
			floating_supported_now = floating_component.is_supported
			_floating_stable_grounded = floating_component.grounded_stable
			has_floating_support = floating_component.has_recent_support(now, component.settings.coyote_time)

		component.update_vertical_state(body.velocity.y, now)

		# Lenient support for jump detection (includes coyote time for better feel)
		var is_on_floor_raw: bool = body.is_on_floor()
		var supported_now: bool = is_on_floor_raw or floating_supported_now
		var support_recent: bool = supported_now or has_floating_support

		# Check for landing transition (airborne -> grounded)
		# Use immediate support with fall distance filter (no hysteresis delay)
		var current_height: float = body.global_position.y
		if component.check_landing_transition(supported_now, now, current_height):
			if not suppress_landing_event:
				var landing_payload: Dictionary = {
					"entity": body,
					"jump_component": component,
					"floating_component": floating_component,
					"velocity": body.velocity,
					"position": body.global_position,
					"landing_time": now,
					"vertical_velocity": body.velocity.y,
				}
				U_ECSEventBus.publish(EVENT_ENTITY_LANDED, landing_payload)

			# Phase 16: Update entity snapshot with floor state (Entity Coordination Pattern)
			if store:
				var entity_id: String = _get_entity_id(body)
				if not entity_id.is_empty():
					store.dispatch(U_EntityActions.update_entity_snapshot(entity_id, {
						"is_on_floor": true
					}))
		
		# Mark on floor AFTER landing event to avoid race condition:
		# Landing event may trigger position resets that temporarily invalidate is_on_floor()
		# By marking after the event, we ensure jump checks use correct post-reset floor state
		if supported_now:
			component.record_ground_height(current_height)
			component.mark_on_floor(now)

		var buffer_time := component.settings.jump_buffer_time
		if accessibility_jump_buffer >= 0.0:
			buffer_time = max(buffer_time, accessibility_jump_buffer)
		var jump_requested: bool = input_component.has_jump_request(buffer_time, now)
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
		velocity.y = component.settings.jump_force
		body.velocity = velocity
		if floating_component != null:
			floating_component.reset_recent_support(now, component.settings.coyote_time)

		# Phase 16: Update entity snapshot with floor state (Entity Coordination Pattern)
		if store:
			var entity_id: String = _get_entity_id(body)
			if not entity_id.is_empty():
				store.dispatch(U_EntityActions.update_entity_snapshot(entity_id, {
					"is_on_floor": false
				}))

		component.update_debug_snapshot({
			"supported": supported_now,
			"support_recent": support_recent,
			"requested": true,
			"performed": true,
			"has_air_jumps": component.has_air_jumps_remaining(),
			"recent_apex": component.has_recent_apex(now),
		})

		var event_payload: Dictionary = {
			"entity": body,
			"jump_component": component,
			"input_component": input_component,
			"floating_component": floating_component,
			"velocity": body.velocity,
			"position": body.global_position,
			"jump_time": now,
			"supported": supported_now,
			"support_recent": support_recent,
			"air_jumps_remaining": component.has_air_jumps_remaining(),
			"jump_force": component.settings.jump_force if component.settings != null else 0.0,
		}
		U_ECSEventBus.publish(EVENT_ENTITY_JUMPED, event_payload)

## Phase 16: Get entity ID from body for state coordination
func _get_entity_id(body: Node) -> String:
	if body == null:
		return ""
	var entity_root: Node = ECS_UTILS.find_entity_root(body, true)
	if entity_root != null:
		return String(ECS_UTILS.get_entity_id(entity_root))
	return ""

func _is_spawn_landing_event_suppressed(spawn_state: C_SpawnStateComponent, current_physics_frame: int) -> bool:
	if spawn_state == null:
		return false

	var until_frame: int = spawn_state.suppress_landing_until_frame
	if until_frame < 0 or current_physics_frame > until_frame:
		if until_frame >= 0:
			spawn_state.suppress_landing_until_frame = -1
		return false

	return true
