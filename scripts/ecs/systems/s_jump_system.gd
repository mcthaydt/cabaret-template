@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_JumpSystem

## Phase 16: Dispatches floor state to state store

const JUMP_TYPE := StringName("C_JumpComponent")
const INPUT_TYPE := StringName("C_InputComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")
const EVENT_ENTITY_JUMPED := StringName("entity_jumped")
const EVENT_ENTITY_LANDED := StringName("entity_landed")

@export var debug_logs_enabled: bool = false

func process_tick(_delta: float) -> void:
	# Skip processing if game is paused
	var store: M_StateStore = U_StateUtils.get_store(self)
	if store:
		var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
		if U_GameplaySelectors.get_is_paused(gameplay_state):
			return
	
	var manager := get_manager()
	if manager == null:
		return

	var now: float = ECS_UTILS.get_current_time()
	# Jump requires input; floating is optional to extend support windows.
	var entities: Array = manager.query_entities(
		[
			JUMP_TYPE,
			INPUT_TYPE,
		],
		[
			FLOATING_TYPE,
		]
	)
	var floating_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, FLOATING_TYPE)

	for entity_query in entities:
		var component: C_JumpComponent = entity_query.get_component(JUMP_TYPE)
		var input_component: C_InputComponent = entity_query.get_component(INPUT_TYPE)
		if component == null or input_component == null:
			continue

		var body = component.get_character_body()
		if body == null:
			continue

		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		if floating_component == null:
			floating_component = floating_by_body.get(body, null) as C_FloatingComponent
		var floating_supported_now: bool = false
		var floating_stable_grounded: bool = false
		var has_floating_support: bool = false
		if floating_component != null:
			floating_supported_now = floating_component.is_supported
			floating_stable_grounded = floating_component.grounded_stable
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
			var landing_payload: Dictionary = {
				"entity": body,
				"jump_component": component,
				"floating_component": floating_component,
				"velocity": body.velocity,
				"position": body.global_position,
				"landing_time": now,
				"vertical_velocity": body.velocity.y,
			}
			ECSEventBus.publish(EVENT_ENTITY_LANDED, landing_payload)
			if debug_logs_enabled:
				print("[Jump] %s landed vY=%.3f supported_now=%s" % [str(body.name), float(body.velocity.y), str(supported_now)])
			
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
			component.mark_on_floor(now)

		var jump_requested: bool = input_component.has_jump_request(component.settings.jump_buffer_time, now)
		if not jump_requested:
			component.update_debug_snapshot({
				"supported": supported_now,
				"support_recent": support_recent,
				"requested": false,
				"performed": false,
				"has_air_jumps": component.has_air_jumps_remaining(),
				"recent_apex": component.has_recent_apex(now),
			})
			if debug_logs_enabled and Input.is_action_just_pressed(StringName("jump")):
				print("[Jump] %s request missed: buffered?=%s buffer=%.2fs supported_now=%s support_recent=%s" % [
					str(body.name),
					"no",  # we only log when request not registered via buffer
					float(component.settings.jump_buffer_time),
					str(supported_now),
					str(support_recent)
				])
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
			if debug_logs_enabled:
				var reason := ""
				if not support_recent and not component.has_air_jumps_remaining():
					reason = "no support, coyote expired, no air jumps"
				elif not support_recent and component.has_air_jumps_remaining():
					reason = "no support, coyote expired, using air jumps later"
				else:
					reason = "unknown gating"
				print("[Jump] %s suppressed: %s (on_floor=%s float_now=%s float_recent=%s)" % [
					str(body.name), reason, str(is_on_floor_raw), str(floating_supported_now), str(has_floating_support)
				])
			continue

		if not input_component.consume_jump_request():
			continue

		component.on_jump_performed(now, supported_now)
		var velocity = body.velocity
		velocity.y = component.settings.jump_force
		body.velocity = velocity
		if floating_component != null:
			floating_component.reset_recent_support(now, component.settings.coyote_time)
		if debug_logs_enabled:
			print("[Jump] %s JUMP performed force=%.2f supported_now=%s support_recent=%s" % [
				str(body.name), float(component.settings.jump_force), str(supported_now), str(support_recent)
			])
		
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
		ECSEventBus.publish(EVENT_ENTITY_JUMPED, event_payload)

## Phase 16: Get entity ID from body for state coordination
func _get_entity_id(body: Node) -> String:
	if body.has_meta("entity_id"):
		return body.get_meta("entity_id")
	return body.name
