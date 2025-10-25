@icon("res://resources/editor_icons/system.svg")
extends ECSSystem
class_name S_JumpSystem

const JUMP_TYPE := StringName("C_JumpComponent")
const INPUT_TYPE := StringName("C_InputComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")
const EVENT_ENTITY_JUMPED := StringName("entity_jumped")
const EVENT_ENTITY_LANDED := StringName("entity_landed")

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

		# Check for landing transition (airborne -> grounded)
		# Use recent support to avoid flicker-induced false landings on ramps.
		if component.check_landing_transition(support_recent, now):
			# Guard against ramp flicker: require a minimal downward speed unless
			# we were clearly airborne for a bit (e.g., real fall landing).
			var vy: float = body.velocity.y
			var min_down_v: float = -1.5
			var allow_by_duration: bool = false
			var airborne_dur: float = 0.0
			if component.has_method("get_airborne_duration"):
				airborne_dur = component.get_airborne_duration(now)
				allow_by_duration = airborne_dur >= 0.1
			# If we're not moving downward fast enough and didn't spend meaningful time in air, skip.
			if vy > min_down_v and not allow_by_duration:
				if OS.is_debug_build():
					var on_floor_dbg: bool = body.is_on_floor()
					print("[land-skip] vy_gate t=", String.num(now, 3), " vy=", String.num(vy, 2), " air=", String.num(airborne_dur, 3), " on_floor=", on_floor_dbg, " float=", floating_supported_now)
				continue

			if OS.is_debug_build():
				var on_floor_dbg2: bool = body.is_on_floor()
				var slope_deg: float = -1.0
				if on_floor_dbg2 and body.has_method("get_floor_normal"):
					var floor_n_v: Variant = body.call("get_floor_normal")
					if floor_n_v is Vector3:
						var up_dir: Vector3 = body.up_direction
						if up_dir.length() == 0.0:
							up_dir = Vector3.UP
						var dot_up: float = clamp((floor_n_v as Vector3).normalized().dot(up_dir.normalized()), -1.0, 1.0)
						slope_deg = rad_to_deg(acos(dot_up))
				print("[land] t=", String.num(now, 3), " vy=", String.num(vy, 2), " air=", String.num(airborne_dur, 3), " on_floor=", on_floor_dbg2, " float=", floating_supported_now, " slope=", String.num(slope_deg, 1))

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
