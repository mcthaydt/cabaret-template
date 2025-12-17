@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_MovementSystem

## Phase 16: Dispatches velocity to state store

const MOVEMENT_TYPE := StringName("C_MovementComponent")
const INPUT_TYPE := StringName("C_InputComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null

# State stability tracking to prevent flickering in state store
const MIN_STABLE_FRAMES := 10  # Frames state must be stable before dispatching (~0.167s @ 60fps)
var _floor_state_stable_frames: Dictionary = {}  # entity_id -> frames_stable

func process_tick(delta: float) -> void:
	# Skip processing if game is paused
	# Use injected store if available (Phase 10B-8)
	var store: M_StateStore = null
	if state_store != null:
		store = state_store as M_StateStore
	else:
		store = U_StateUtils.get_store(self)

	if store:
		var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
		if U_GameplaySelectors.get_is_paused(gameplay_state):
			return
	
	var manager := get_manager()
	if manager == null:
		return

	var body_state := {}
	var bodies := []
	var current_time := ECS_UTILS.get_current_time()

	# Pull every entity that has movement + input; floating is optional for support checks.
	var entities: Array = manager.query_entities(
		[
			MOVEMENT_TYPE,
			INPUT_TYPE,
		],
		[
			FLOATING_TYPE,
		]
	)

	for entity_query in entities:
		var movement_component: C_MovementComponent = entity_query.get_component(MOVEMENT_TYPE)
		var input_component: C_InputComponent = entity_query.get_component(INPUT_TYPE)
		if movement_component == null or input_component == null:
			continue

		var body: CharacterBody3D = movement_component.get_character_body()
		if body == null:
			continue

		var state = body_state.get(body, null)
		if state == null:
			state = {
				"velocity": body.velocity,
				"previous_is_on_floor": body.is_on_floor(),  # Track for change detection
			}
			body_state[body] = state
			bodies.append(body)

		var velocity: Vector3 = state.velocity

		var input_vector: Vector2 = input_component.move_vector
		var is_sprinting := input_component.is_sprinting()
		var current_max_speed: float = movement_component.settings.max_speed
		if is_sprinting:
			var sprint_multiplier: float = movement_component.settings.sprint_speed_multiplier
			if sprint_multiplier <= 0.0:
				sprint_multiplier = 1.0
			current_max_speed = movement_component.settings.max_speed * sprint_multiplier

		var has_input: bool = input_vector.length() > 0.0
		var desired_velocity: Vector3 = Vector3.ZERO
		if has_input:
			var camera: Camera3D = ECS_UTILS.get_active_camera(self)
			if camera != null:
				var up_dir: Vector3 = (body.up_direction if body != null else Vector3.UP)
				if up_dir.length() == 0.0:
					up_dir = Vector3.UP
				var cam_forward: Vector3 = -camera.global_transform.basis.z
				cam_forward = _project_onto_plane(cam_forward, up_dir)
				if cam_forward.length() == 0.0:
					cam_forward = _project_onto_plane(Vector3.FORWARD, up_dir)
				cam_forward = cam_forward.normalized()
				var cam_right: Vector3 = camera.global_transform.basis.x
				cam_right = _project_onto_plane(cam_right, up_dir)
				if cam_right.length() == 0.0:
					cam_right = cam_forward.cross(up_dir)
				cam_right = cam_right.normalized()
				var forward_input: float = -input_vector.y
				var desired_dir: Vector3 = (cam_right * input_vector.x) + (cam_forward * forward_input)
				# Preserve analog magnitude from input_vector when using camera-relative movement.
				# Scale speed by stick magnitude (0.0 - 1.0) instead of normalizing to unit length.
				var analog_scale: float = clampf(input_vector.length(), 0.0, 1.0)
				if desired_dir.length() > 0.0:
					desired_dir = desired_dir.normalized()
				desired_velocity = desired_dir * (current_max_speed * analog_scale)
			else:
				desired_velocity = _get_desired_velocity(input_vector, current_max_speed)

		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)

		var support_active: bool = false
		if floating_component != null:
			support_active = floating_component.has_recent_support(current_time, movement_component.settings.support_grace_time)

		var accel_scale: float = 1.0
		if floating_component != null and not support_active:
			accel_scale *= max(movement_component.settings.air_control_scale, 0.0)

		var up_dir2: Vector3 = body.up_direction
		if up_dir2.length() == 0.0:
			up_dir2 = Vector3.UP
		var effective_normal: Vector3 = Vector3.ZERO
		if body.is_on_floor():
			if body.has_method("get_floor_normal"):
				var floor_n: Variant = body.call("get_floor_normal")
				if floor_n is Vector3 and (floor_n as Vector3).length() > 0.0:
					effective_normal = (floor_n as Vector3).normalized()
		elif floating_component != null:
			var recent_n: Vector3 = floating_component.get_recent_support_normal(current_time, movement_component.settings.support_grace_time)
			if recent_n.length() > 0.0:
				effective_normal = recent_n.normalized()

		if effective_normal.length() > 0.0 and movement_component.settings.slope_limit_degrees > 0.0:
			var dot_up: float = clamp(effective_normal.dot(up_dir2), -1.0, 1.0)
			var angle_deg: float = rad_to_deg(acos(dot_up))
			if angle_deg > movement_component.settings.slope_limit_degrees:
				accel_scale *= clamp(dot_up, 0.0, 1.0)

		var wants_second_order: bool = movement_component.settings.use_second_order_dynamics and movement_component.settings.response_frequency > 0.0
		if wants_second_order and has_input:
			var desired_adjusted := desired_velocity * accel_scale
			velocity = _apply_second_order_dynamics(movement_component, velocity, desired_adjusted, delta, support_active)
			velocity = _clamp_horizontal_speed(velocity, current_max_speed)
		else:
			if has_input:
				velocity.x = move_toward(velocity.x, desired_velocity.x, movement_component.settings.acceleration * accel_scale * delta)
				velocity.z = move_toward(velocity.z, desired_velocity.z, movement_component.settings.acceleration * accel_scale * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, movement_component.settings.deceleration * delta)
				velocity.z = move_toward(velocity.z, 0.0, movement_component.settings.deceleration * delta)
			movement_component.reset_dynamics_state()

		if not has_input:
			velocity = _apply_horizontal_friction(movement_component, velocity, support_active, delta)

		velocity = _clamp_horizontal_speed(velocity, current_max_speed)

		state.velocity = velocity

		movement_component.update_debug_snapshot({
			"supported": support_active,
			"has_input": has_input,
			"is_sprinting": is_sprinting,
			"desired_velocity": Vector2(desired_velocity.x, desired_velocity.z),
			"current_velocity": Vector2(velocity.x, velocity.z),
			"dynamics_velocity": movement_component.get_horizontal_dynamics_velocity(),
		})

	# Build floating component map for floor detection
	var floating_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, FLOATING_TYPE)

	for body in bodies:
		var final_velocity: Vector3 = body_state[body].velocity
		body.velocity = final_velocity
		if body.has_method("move_and_slide"):
			body.move_and_slide()

			# Track floor state for stability check
			var is_on_floor_raw: bool = body.is_on_floor()
			var floating_supported: bool = false
			var floating_component: C_FloatingComponent = floating_by_body.get(body, null) as C_FloatingComponent
			if floating_component != null:
				floating_supported = floating_component.is_supported
			var current_on_floor: bool = is_on_floor_raw or floating_supported

			# Update for next frame
			body_state[body].previous_is_on_floor = current_on_floor

	# Phase 16: Dispatch entity snapshots to state store (Entity Coordination Pattern)
	# Reuse floating_by_body map created earlier
	if store and bodies.size() > 0:
		for body in bodies:
			var entity_id: String = _get_entity_id(body)
			if entity_id.is_empty():
				continue

			var is_moving: bool = Vector2(body.velocity.x, body.velocity.z).length() > 0.1

			# Check BOTH is_on_floor() and floating support (matching JumpSystem logic)
			var is_on_floor_raw: bool = body.is_on_floor()
			var floating_supported: bool = false
			var floating_component: C_FloatingComponent = floating_by_body.get(body, null) as C_FloatingComponent
			if floating_component != null:
				floating_supported = floating_component.is_supported
			var current_on_floor: bool = is_on_floor_raw or floating_supported

			# Stability check: Only dispatch if floor state has been stable for MIN_STABLE_FRAMES
			# This prevents flickering from floating capsule jitter
			var previous_on_floor: bool = body_state[body].previous_is_on_floor
			var stable_frames: int = _floor_state_stable_frames.get(entity_id, 0)

			if current_on_floor != previous_on_floor:
				# State changed - reset stability counter
				_floor_state_stable_frames[entity_id] = 0
			else:
				# State unchanged - increment stability counter
				if stable_frames < MIN_STABLE_FRAMES:
					_floor_state_stable_frames[entity_id] = stable_frames + 1

			# Only include is_on_floor in snapshot if state is stable
			var should_update_floor_state: bool = _floor_state_stable_frames.get(entity_id, 0) >= MIN_STABLE_FRAMES

			var snapshot: Dictionary = {
				"position": body.global_position,
				"velocity": body.velocity,
				"rotation": body.rotation,
				"is_moving": is_moving,
				"entity_type": _get_entity_type(body)
			}

			# Only add is_on_floor to snapshot if stable
			if should_update_floor_state:
				snapshot["is_on_floor"] = current_on_floor

			store.dispatch(U_EntityActions.update_entity_snapshot(entity_id, snapshot))

func _get_desired_velocity(input_vector: Vector2, max_speed: float) -> Vector3:
	var normalized = input_vector
	if normalized.length() > 1.0:
		normalized = normalized.normalized()
	return Vector3(normalized.x, 0.0, normalized.y) * max_speed

func _clamp_horizontal_speed(velocity: Vector3, max_speed: float) -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() > max_speed:
		horizontal = horizontal.normalized() * max_speed
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	return velocity

func _apply_second_order_dynamics(component: C_MovementComponent, velocity: Vector3, desired_velocity: Vector3, delta: float, support_active: bool) -> Vector3:
	var frequency: float = max(component.settings.response_frequency, 0.0)
	if frequency <= 0.0:
		component.reset_dynamics_state()
		return velocity

	var damping_base: float = max(component.settings.damping_ratio, 0.0)
	var damping_multiplier: float = component.settings.grounded_damping_multiplier if support_active else component.settings.air_damping_multiplier
	var damping: float = damping_base * damping_multiplier
	var omega: float = TAU * frequency
	if omega <= 0.0:
		component.reset_dynamics_state()
		return velocity

	var current_horizontal := Vector2(velocity.x, velocity.z)
	var target_horizontal := Vector2(desired_velocity.x, desired_velocity.z)
	var dynamics_velocity: Vector2 = component.get_horizontal_dynamics_velocity()
	var error: Vector2 = target_horizontal - current_horizontal
	var accel: Vector2 = error * (omega * omega) - dynamics_velocity * (2.0 * damping * omega)
	dynamics_velocity += accel * delta
	current_horizontal += dynamics_velocity * delta
	component.set_horizontal_dynamics_velocity(dynamics_velocity)
	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.y
	return velocity

func _apply_horizontal_friction(component: C_MovementComponent, velocity: Vector3, support_active: bool, delta: float) -> Vector3:
	var base_friction: float = component.settings.grounded_friction if support_active else component.settings.air_friction
	if base_friction <= 0.0:
		return velocity

	var strafe_friction: float = max(base_friction * component.settings.strafe_friction_scale, 0.0)
	var forward_friction: float = max(base_friction * component.settings.forward_friction_scale, 0.0)

	velocity.x = move_toward(velocity.x, 0.0, strafe_friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, forward_friction * delta)
	return velocity

func _project_onto_plane(vector: Vector3, plane_normal: Vector3) -> Vector3:
	var n := plane_normal
	if n.length() == 0.0:
		return Vector3.ZERO
	n = n.normalized()
	return vector - n * vector.dot(n)

## Phase 16: Get entity ID from body for state coordination
func _get_entity_id(body: Node) -> String:
	# Use metadata if available
	if body.has_meta("entity_id"):
		return body.get_meta("entity_id")
	# Fallback to node name
	return body.name

## Phase 16: Get entity type from body
func _get_entity_type(body: Node) -> String:
	if body.has_meta("entity_type"):
		return body.get_meta("entity_type")
	# Infer from node name
	var name_lower: String = body.name.to_lower()
	if "player" in name_lower:
		return "player"
	elif "enemy" in name_lower:
		return "enemy"
	elif "npc" in name_lower:
		return "npc"
	return "unknown"
