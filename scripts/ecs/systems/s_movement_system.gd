@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_MovementSystem

## Phase 16: Dispatches velocity to state store

const MOVEMENT_TYPE := StringName("C_MovementComponent")
const INPUT_TYPE := StringName("C_InputComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")
const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const CHARACTER_STATE_TYPE := C_CHARACTER_STATE_COMPONENT.COMPONENT_TYPE
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const AI_BRAIN_TYPE := C_AI_BRAIN_COMPONENT.COMPONENT_TYPE
const C_SPAWN_STATE_COMPONENT := preload("res://scripts/ecs/components/c_spawn_state_component.gd")
const SPAWN_STATE_TYPE := C_SPAWN_STATE_COMPONENT.COMPONENT_TYPE
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_PERF_PROBE := preload("res://scripts/utils/debug/u_perf_probe.gd")
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/utils/debug/u_debug_log_throttle.gd")

const MOBILE_DISPATCH_INTERVAL := 3

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null
@export var debug_ai_movement_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.25
@export var debug_entity_id: StringName = StringName("patrol_drone")
## DIAG: logs every frame (not throttled) to capture bounce oscillation
@export var debug_bounce_diag: bool = false

# State stability tracking to prevent flickering in state store
const MIN_STABLE_FRAMES := 10  # Frames state must be stable before dispatching (~0.167s @ 60fps)
var _floor_state_stable_frames: Dictionary = {}  # entity_id -> frames_stable
var _debug_log_throttle: Variant = U_DEBUG_LOG_THROTTLE.new()
var _diag_frame_counter: int = 0
var _is_mobile: bool = false
var _dispatch_counter: int = 0
var _perf_probe: U_PerfProbe = null

func _init() -> void:
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	_perf_probe = U_PerfProbe.create("S_MovementSystem", _is_mobile)

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.PHYSICS_SOLVE

func process_tick(delta: float) -> void:
	_perf_probe.start()
	_diag_frame_counter += 1
	_dispatch_counter += 1
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

	var body_state := {}
	var bodies := []
	var current_time := ECS_UTILS.get_current_time()
	var current_physics_frame: int = Engine.get_physics_frames()
	var spawn_state_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, SPAWN_STATE_TYPE)
	var character_state_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, CHARACTER_STATE_TYPE)

	# Pull every entity that has movement + input; floating is optional for support checks.
	var entities: Array = manager.query_entities(
		[
			MOVEMENT_TYPE,
			INPUT_TYPE,
		],
		[
			FLOATING_TYPE,
			CHARACTER_STATE_TYPE,
			AI_BRAIN_TYPE,
		]
	)

	for entity_query in entities:
		var entity_id: StringName = _resolve_entity_id_from_query(entity_query)
		var movement_component: C_MovementComponent = entity_query.get_component(MOVEMENT_TYPE)
		var input_component: C_InputComponent = entity_query.get_component(INPUT_TYPE)
		if movement_component == null or input_component == null:
			_debug_log_for_entity(entity_id, "skip: missing movement/input component")
			continue

		var body: CharacterBody3D = movement_component.get_character_body()
		if body == null:
			_debug_log_for_entity(entity_id, "skip: movement body is null")
			continue

		var spawn_state: C_SpawnStateComponent = spawn_state_by_body.get(body, null) as C_SpawnStateComponent
		var character_state: C_CharacterStateComponent = entity_query.get_component(CHARACTER_STATE_TYPE)
		if character_state == null:
			character_state = character_state_by_body.get(body, null) as C_CharacterStateComponent
		if character_state != null and not character_state.is_gameplay_active:
			_debug_log_for_entity(entity_id, "skip: character_state.is_gameplay_active=false")
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

		var is_spawn_frozen: bool = false
		if character_state != null:
			is_spawn_frozen = character_state.is_spawn_frozen
		elif spawn_state != null:
			is_spawn_frozen = spawn_state.is_physics_frozen

		if is_spawn_frozen:
			_debug_log_for_entity(entity_id, "skip: movement blocked by spawn freeze")
			_maybe_schedule_spawn_unfreeze(body, spawn_state, current_physics_frame)
			state.velocity = Vector3.ZERO
			movement_component.reset_dynamics_state()
			movement_component.update_debug_snapshot({
				"spawn_frozen": true,
				"supported": false,
				"has_input": false,
				"is_sprinting": false,
				"desired_velocity": Vector2.ZERO,
				"current_velocity": Vector2.ZERO,
				"dynamics_velocity": Vector2.ZERO,
			})
			continue

		var input_vector: Vector2 = input_component.move_vector
		var settings: RS_MovementSettings = movement_component.settings
		if settings == null:
			_debug_log_for_entity(entity_id, "skip: movement settings are null")
			continue
		var is_sprinting := input_component.is_sprinting()
		var current_max_speed: float = settings.max_speed
		if is_sprinting:
			var sprint_multiplier: float = settings.sprint_speed_multiplier
			if sprint_multiplier <= 0.0:
				sprint_multiplier = 1.0
			current_max_speed = current_max_speed * sprint_multiplier

		var has_input: bool = input_vector.length() > 0.0
		var desired_velocity: Vector3 = Vector3.ZERO
		if has_input:
			var uses_ai_world_space_input: bool = entity_query.get_component(AI_BRAIN_TYPE) != null
			if uses_ai_world_space_input:
				desired_velocity = _get_desired_velocity(input_vector, current_max_speed)
			else:
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
			support_active = floating_component.has_recent_support(current_time, settings.support_grace_time)

		var accel_scale: float = 1.0
		if floating_component != null and not support_active:
			accel_scale *= max(settings.air_control_scale, 0.0)

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

		if effective_normal.length() > 0.0 and settings.slope_limit_degrees > 0.0:
			var dot_up: float = clamp(effective_normal.dot(up_dir2), -1.0, 1.0)
			var angle_deg: float = rad_to_deg(acos(dot_up))
			if angle_deg > settings.slope_limit_degrees:
				accel_scale *= clamp(dot_up, 0.0, 1.0)

		var wants_second_order: bool = settings.use_second_order_dynamics and settings.response_frequency > 0.0
		if wants_second_order and has_input:
			var desired_adjusted := desired_velocity * accel_scale
			velocity = _apply_second_order_dynamics(movement_component, settings, velocity, desired_adjusted, delta, support_active)
			velocity = _clamp_horizontal_speed(velocity, current_max_speed)
		else:
			if has_input:
				velocity.x = move_toward(velocity.x, desired_velocity.x, settings.acceleration * accel_scale * delta)
				velocity.z = move_toward(velocity.z, desired_velocity.z, settings.acceleration * accel_scale * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, settings.deceleration * delta)
				velocity.z = move_toward(velocity.z, 0.0, settings.deceleration * delta)
			movement_component.reset_dynamics_state()

		if not has_input:
			velocity = _apply_horizontal_friction(settings, velocity, support_active, delta)

		velocity = _clamp_horizontal_speed(velocity, current_max_speed)

		state.velocity = velocity
		_debug_log_for_entity(
			entity_id,
			"input=%s has_input=%s desired_velocity=%s final_velocity=%s supported=%s"
			% [
				str(input_vector),
				str(has_input),
				str(desired_velocity),
				str(velocity),
				str(support_active),
			]
		)

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

		# DIAG: capture pre-move_and_slide state
		var _diag_pre_pos_y: float = body.global_position.y
		var _diag_pre_vel_y: float = final_velocity.y

		body.velocity = final_velocity
		if body.has_method("move_and_slide"):
			body.move_and_slide()

			# DIAG: per-frame move_and_slide delta for bounce diagnosis
			if debug_bounce_diag:
				var _diag_entity_id: StringName = StringName(_get_entity_id(body))
				if debug_entity_id == StringName() or _diag_entity_id == debug_entity_id:
					var _diag_post_vel_y: float = body.velocity.y
					var _diag_post_pos_y: float = body.global_position.y
					var _diag_vel_delta: float = _diag_post_vel_y - _diag_pre_vel_y
					var _diag_pos_delta: float = _diag_post_pos_y - _diag_pre_pos_y
					print(
						"DIAG_MOVE[f=%d] pre_pos_y=%.4f post_pos_y=%.4f pos_delta=%.4f pre_vel_y=%.4f post_vel_y=%.4f vel_delta=%.4f is_on_floor=%s slide_count=%d"
						% [
							_diag_frame_counter,
							_diag_pre_pos_y,
							_diag_post_pos_y,
							_diag_pos_delta,
							_diag_pre_vel_y,
							_diag_post_vel_y,
							_diag_vel_delta,
							str(body.is_on_floor()),
							body.get_slide_collision_count(),
						]
					)

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
	# Batch all entity snapshots into a single dispatch to avoid N deep copies
	if store and bodies.size() > 0 and (not _is_mobile or (_dispatch_counter % MOBILE_DISPATCH_INTERVAL) == 0):
		var batched_snapshots: Dictionary = {}
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
				_floor_state_stable_frames[entity_id] = 0
			else:
				if stable_frames < MIN_STABLE_FRAMES:
					_floor_state_stable_frames[entity_id] = stable_frames + 1

			var should_update_floor_state: bool = _floor_state_stable_frames.get(entity_id, 0) >= MIN_STABLE_FRAMES

			var snapshot: Dictionary = {
				"position": body.global_position,
				"velocity": body.velocity,
				"rotation": body.rotation,
				"is_moving": is_moving,
				"entity_type": _get_entity_type(body)
			}

			if should_update_floor_state:
				snapshot["is_on_floor"] = current_on_floor

			batched_snapshots[entity_id] = snapshot

		if not batched_snapshots.is_empty():
			store.dispatch(U_EntityActions.update_entity_snapshots(batched_snapshots))

		# Prune stale entries from floor state tracking
		if _floor_state_stable_frames.size() > batched_snapshots.size():
			for key in _floor_state_stable_frames.keys():
				if not batched_snapshots.has(key):
					_floor_state_stable_frames.erase(key)
	_perf_probe.stop()

func _maybe_schedule_spawn_unfreeze(body: CharacterBody3D, spawn_state: C_SpawnStateComponent, current_physics_frame: int) -> void:
	if body == null or spawn_state == null:
		return

	var unfreeze_frame: int = spawn_state.unfreeze_at_frame
	if unfreeze_frame < 0 or current_physics_frame < unfreeze_frame:
		return

	spawn_state.clear_spawn_state()
	body.call_deferred("set_physics_process", true)

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

func _apply_second_order_dynamics(component: C_MovementComponent, settings: RS_MovementSettings, velocity: Vector3, desired_velocity: Vector3, delta: float, support_active: bool) -> Vector3:
	var frequency: float = max(settings.response_frequency, 0.0)
	if frequency <= 0.0:
		component.reset_dynamics_state()
		return velocity

	var damping_base: float = max(settings.damping_ratio, 0.0)
	var damping_multiplier: float = settings.grounded_damping_multiplier if support_active else settings.air_damping_multiplier
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

func _apply_horizontal_friction(settings: RS_MovementSettings, velocity: Vector3, support_active: bool, delta: float) -> Vector3:
	var base_friction: float = settings.grounded_friction if support_active else settings.air_friction
	if base_friction <= 0.0:
		return velocity

	var strafe_friction: float = max(base_friction * settings.strafe_friction_scale, 0.0)
	var forward_friction: float = max(base_friction * settings.forward_friction_scale, 0.0)

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
	if body == null:
		return ""
	var entity_root: Node = ECS_UTILS.find_entity_root(body, true)
	if entity_root != null:
		return String(ECS_UTILS.get_entity_id(entity_root))
	return ""

## Get entity type from body (C10: tag-based primary, name-inference fallback)
##
## Lookup order:
##   1. Entity tags — "player", "enemy", or "npc" tag on the entity node
##   2. Name inference — substring match on the entity root node name
func _get_entity_type(body: Node) -> String:
	var source_node: Node = ECS_UTILS.find_entity_root(body, true)
	if source_node == null:
		source_node = body

	var tags: Array[StringName] = ECS_UTILS.get_entity_tags(source_node)
	for tag in tags:
		var tag_str: String = String(tag)
		if tag_str == "player" or tag_str == "enemy" or tag_str == "npc":
			return tag_str

	return _infer_entity_type_from_name(String(source_node.name))

func _infer_entity_type_from_name(name_text: String) -> String:
	var name_lower: String = name_text.to_lower()
	if "player" in name_lower:
		return "player"
	if "enemy" in name_lower:
		return "enemy"
	if "npc" in name_lower:
		return "npc"
	return "unknown"

func _resolve_entity_id_from_query(entity_query: Variant) -> StringName:
	if entity_query == null or not (entity_query is Object):
		return StringName()
	var query_object: Object = entity_query as Object
	if query_object.has_method("get_entity_id"):
		var id_variant: Variant = query_object.call("get_entity_id")
		if id_variant is StringName:
			return id_variant as StringName
		if id_variant is String:
			var text: String = id_variant
			if not text.is_empty():
				return StringName(text)
	var entity_variant: Variant = query_object.get("entity")
	if entity_variant is Node:
		return ECS_UTILS.get_entity_id(entity_variant as Node)
	return StringName()

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_ai_movement_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false
	return _debug_log_throttle.consume_budget(entity_id, maxf(debug_log_interval_sec, 0.05))

func _debug_log_for_entity(entity_id: StringName, message: String) -> void:
	if not _consume_debug_log_budget(entity_id):
		return
	print("S_MovementSystem[entity=%s] %s" % [str(entity_id), message])
