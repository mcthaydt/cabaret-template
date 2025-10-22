@icon("res://resources/editor_icons/system.svg")
extends ECSSystem
class_name S_JumpSystem

const JUMP_TYPE := StringName("C_JumpComponent")
const INPUT_TYPE := StringName("C_InputComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")
const EVENT_ENTITY_JUMPED := StringName("entity_jumped")

func process_tick(_delta: float) -> void:
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
		var has_floating_support: bool = false
		if floating_component != null:
			floating_supported_now = floating_component.is_supported
			has_floating_support = floating_component.has_recent_support(now, component.settings.coyote_time)

		component.update_vertical_state(body.velocity.y, now)

		var supported_now: bool = body.is_on_floor() or floating_supported_now
		if supported_now:
			component.mark_on_floor(now)
		var support_recent: bool = supported_now or has_floating_support

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
