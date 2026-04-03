@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_FloatingSystem

const FLOATING_TYPE := StringName("C_FloatingComponent")
## Number of consecutive frames required to transition stable ground state
## 4 frames ≈ 67ms at 60fps, filters spring oscillations (~50ms) while staying responsive
const STABLE_GROUND_FRAMES_REQUIRED := 4

const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const CHARACTER_STATE_TYPE := C_CHARACTER_STATE_COMPONENT.COMPONENT_TYPE
const C_SPAWN_STATE_COMPONENT := preload("res://scripts/ecs/components/c_spawn_state_component.gd")
const SPAWN_STATE_TYPE := C_SPAWN_STATE_COMPONENT.COMPONENT_TYPE

@export var debug_ai_floating_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.25
@export var debug_entity_id: StringName = StringName("patrol_drone")
## DIAG: logs every frame (not throttled) to capture bounce oscillation
@export var debug_bounce_diag: bool = false

var _debug_log_cooldowns: Dictionary = {}
var _diag_frame_counter: int = 0

class SupportInfo:
	var has_hit: bool = false
	var distance: float = 0.0
	var normal: Vector3 = Vector3.ZERO
	var hit_count: int = 0
	var total_rays: int = 0
	var hit_ray_names: Array = []
	var miss_ray_names: Array = []

func process_tick(delta: float) -> void:
	_diag_frame_counter += 1
	_tick_debug_log_cooldowns(delta)
	var manager := get_manager()
	if manager == null:
		return

	var processed: Dictionary = {}
	var now: float = ECS_UTILS.get_current_time()
	var entities := manager.query_entities([FLOATING_TYPE], [CHARACTER_STATE_TYPE])
	var spawn_state_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, SPAWN_STATE_TYPE)
	var character_state_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, CHARACTER_STATE_TYPE)

	for entity_query in entities:
		var entity_id: StringName = _resolve_entity_id_from_query(entity_query)
		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		if floating_component == null:
			_debug_log(entity_id, "skip: missing C_FloatingComponent")
			continue

		var body: CharacterBody3D = floating_component.get_character_body()
		if body == null:
			_debug_log(entity_id, "skip: floating body is null")
			continue

		if processed.has(body):
			continue
		processed[body] = true

		var rays: Array = floating_component.get_raycast_nodes()
		if rays.is_empty():
			floating_component.update_support_state(false, now)
			floating_component.update_stable_ground_state(false, STABLE_GROUND_FRAMES_REQUIRED)
			_debug_log(
				entity_id,
				"support_hit=false reason=no_rays body_pos=%s vel=%s"
				% [str(body.global_position), str(body.velocity)]
			)
			continue

		var entity_root: Node = null
		var entity_variant: Variant = entity_query.get("entity")
		if entity_variant is Node:
			entity_root = entity_variant as Node
		if entity_root == null:
			entity_root = ECS_UTILS.find_entity_root(body)

		var support: SupportInfo = _collect_support_data(rays, body, entity_root)
		var spawn_state: C_SpawnStateComponent = spawn_state_by_body.get(body, null) as C_SpawnStateComponent
		var character_state: C_CharacterStateComponent = entity_query.get_component(CHARACTER_STATE_TYPE)
		if character_state == null:
			character_state = character_state_by_body.get(body, null) as C_CharacterStateComponent
		var is_spawn_frozen: bool = false
		if character_state != null:
			is_spawn_frozen = character_state.is_spawn_frozen
		elif spawn_state != null:
			is_spawn_frozen = spawn_state.is_physics_frozen
		if is_spawn_frozen:
			if support.has_hit:
				var normal_frozen: Vector3 = support.normal
				if normal_frozen.length() == 0.0:
					normal_frozen = Vector3.UP
				normal_frozen = normal_frozen.normalized()
				floating_component.set_last_support_normal(normal_frozen, now)

				floating_component.update_support_state(true, now)
				floating_component.update_stable_ground_state(true, STABLE_GROUND_FRAMES_REQUIRED)
			else:
				floating_component.update_support_state(false, now)
				floating_component.update_stable_ground_state(false, STABLE_GROUND_FRAMES_REQUIRED)
			_debug_log(
				entity_id,
				"spawn_frozen support_hit=%s hits=%d/%d distance=%.3f normal=%s grounded_stable=%s body_pos=%s vel=%s"
				% [
					str(support.has_hit),
					support.hit_count,
					support.total_rays,
					support.distance,
					str(support.normal),
					str(floating_component.grounded_stable),
					str(body.global_position),
					str(body.velocity),
				]
			)
			continue

		var velocity: Vector3 = body.velocity
		var velocity_before_y: float = velocity.y

		if support.has_hit:
			var normal: Vector3 = support.normal
			if normal.length() == 0.0:
				normal = Vector3.UP
			normal = normal.normalized()

			# Record the last support normal for downstream systems (e.g., movement slope checks)
			floating_component.set_last_support_normal(normal, now)

			var distance: float = support.distance
			var height_error: float = floating_component.settings.hover_height - distance
			var vel_along_normal: float = velocity.dot(normal)
			var hit_ratio: float = 0.0
			if support.total_rays > 0:
				hit_ratio = float(support.hit_count) / float(support.total_rays)

			# Dynamic edge-aware tolerances
			var tol_height: float = floating_component.settings.height_tolerance
			var tol_vel: float = floating_component.settings.settle_speed_tolerance
			if floating_component.settings.edge_protection_enabled:
				var edge_scale: float = 1.0 - hit_ratio
				tol_height += floating_component.settings.edge_distance_slop * edge_scale
				tol_vel += floating_component.settings.edge_vel_tolerance_bonus * edge_scale

			var within_height_tolerance: bool = abs(height_error) <= tol_height
			var within_speed_tolerance: bool = abs(vel_along_normal) <= tol_vel

			# Primary gate
			var support_active: bool = (vel_along_normal <= tol_vel and height_error >= -tol_height)

			# Edge-protection fallback: keep support only for small extra upward velocity
			if floating_component.settings.edge_protection_enabled and not support_active and support.hit_count > 0 and height_error >= -tol_height:
				var max_extra: float = max(floating_component.settings.edge_fallback_max_extra_vel, 0.0)
				if vel_along_normal <= tol_vel + max_extra:
					support_active = true

			if vel_along_normal > floating_component.settings.settle_speed_tolerance:
				pass
			elif within_height_tolerance and within_speed_tolerance:
				velocity -= normal * vel_along_normal
			else:
				var frequency: float = max(floating_component.settings.hover_frequency, 0.0)
				var damping_ratio: float = max(floating_component.settings.damping_ratio, 0.0)
				var accel_along_normal: float = 0.0
				if frequency > 0.0:
					accel_along_normal = compute_spring_accel(height_error, vel_along_normal, frequency, damping_ratio)
					velocity += normal * accel_along_normal * delta
				else:
					velocity -= normal * vel_along_normal

			velocity = _clamp_velocity_along_normal(velocity, normal, floating_component.settings.max_down_speed, floating_component.settings.max_up_speed)

			if floating_component.settings.align_to_normal and support.hit_count >= max(floating_component.settings.min_hits_for_alignment, 1):
				body.up_direction = normal

			floating_component.update_support_state(support_active, now)
			floating_component.update_stable_ground_state(support_active, STABLE_GROUND_FRAMES_REQUIRED)
			_debug_log(
				entity_id,
				"support_hit=true hits=%d/%d distance=%.3f normal=%s support_active=%s grounded_stable=%s vel_y_before=%.3f vel_y_after=%.3f body_pos=%s hit_rays=%s miss_rays=%s"
				% [
					support.hit_count,
					support.total_rays,
					support.distance,
					str(support.normal),
					str(support_active),
					str(floating_component.grounded_stable),
					velocity_before_y,
					velocity.y,
					str(body.global_position),
					str(support.hit_ray_names),
					str(support.miss_ray_names),
				]
			)
		else:
			velocity.y -= floating_component.settings.fall_gravity * delta
			velocity.y = clamp(velocity.y, -floating_component.settings.max_down_speed, floating_component.settings.max_up_speed)

			floating_component.update_support_state(false, now)
			floating_component.update_stable_ground_state(false, STABLE_GROUND_FRAMES_REQUIRED)
			_debug_log(
				entity_id,
				"support_hit=false hits=%d/%d vel_y_before=%.3f vel_y_after=%.3f grounded_stable=%s body_pos=%s miss_rays=%s"
				% [
					support.hit_count,
					support.total_rays,
					velocity_before_y,
					velocity.y,
					str(floating_component.grounded_stable),
					str(body.global_position),
					str(support.miss_ray_names),
				]
			)

		# DIAG: per-frame bounce diagnostic (not throttled)
		if debug_bounce_diag and (debug_entity_id == StringName() or entity_id == debug_entity_id):
			var _diag_height_error: float = 0.0
			var _diag_spring_accel: float = 0.0
			if support.has_hit:
				_diag_height_error = floating_component.settings.hover_height - support.distance
				var _diag_vel_n: float = velocity_before_y  # pre-spring vel along normal
				_diag_spring_accel = compute_spring_accel(
					_diag_height_error, _diag_vel_n,
					floating_component.settings.hover_frequency,
					floating_component.settings.damping_ratio
				)
			print(
				"DIAG_FLOAT[f=%d] pos_y=%.4f vel_y_in=%.4f vel_y_out=%.4f height_err=%.4f spring_accel=%.4f support=%s is_on_floor=%s distance=%.4f"
				% [
					_diag_frame_counter,
					body.global_position.y,
					velocity_before_y,
					velocity.y,
					_diag_height_error,
					_diag_spring_accel,
					str(support.has_hit),
					str(body.is_on_floor()),
					support.distance if support.has_hit else -1.0,
				]
			)

		body.velocity = velocity

func _collect_support_data(rays: Array, body: CharacterBody3D, entity_root: Node) -> SupportInfo:
	var data: SupportInfo = SupportInfo.new()
	var min_distance: float = INF
	var normal_sum: Vector3 = Vector3.ZERO
	var hit_count: int = 0
	data.total_rays = rays.size()

	for ray in rays:
		if ray == null:
			continue

		if ray.has_method('force_raycast_update'):
			ray.force_raycast_update()

		if not ray.is_colliding():
			data.miss_ray_names.append((ray as Node3D).name)
			continue

		var collider_variant: Variant = null
		if ray.has_method("get_collider"):
			collider_variant = ray.call("get_collider")
		if _is_self_collider(collider_variant, body, entity_root):
			data.miss_ray_names.append((ray as Node3D).name)
			continue

		data.has_hit = true
		hit_count += 1
		data.hit_ray_names.append((ray as Node3D).name)

		var origin: Vector3 = (ray as Node3D).global_transform.origin
		var point: Vector3 = ray.get_collision_point()
		var distance: float = origin.distance_to(point)
		if distance < min_distance:
			min_distance = distance

		normal_sum += ray.get_collision_normal()

	if data.has_hit:
		data.distance = min_distance if min_distance != INF else 0.0
		if hit_count > 0:
			data.normal = normal_sum / hit_count
		data.hit_count = hit_count

	return data

func _is_self_collider(collider_variant: Variant, body: CharacterBody3D, entity_root: Node) -> bool:
	if collider_variant == null:
		return false
	if body != null and collider_variant == body:
		return true
	if not (collider_variant is Node):
		return false

	var collider_node: Node = collider_variant as Node
	if body != null and (collider_node == body or body.is_ancestor_of(collider_node)):
		return true
	if entity_root != null and (collider_node == entity_root or entity_root.is_ancestor_of(collider_node)):
		return true
	return false

func _clamp_velocity_along_normal(velocity: Vector3, normal: Vector3, max_down_speed: float, max_up_speed: float) -> Vector3:
	var vel_along_normal: float = velocity.dot(normal)
	var clamped: float = clamp(vel_along_normal, -max_down_speed, max_up_speed)
	return velocity + normal * (clamped - vel_along_normal)

## Computes the spring-damper acceleration along the support normal.
## height_error > 0: body is below hover target (needs to move up).
## vel_along_normal > 0: body is moving away from the floor (upward).
static func compute_spring_accel(
	height_error: float,
	vel_along_normal: float,
	frequency: float,
	damping_ratio: float
) -> float:
	if frequency <= 0.0:
		return 0.0
	var omega: float = TAU * maxf(frequency, 0.0)
	# Keep spring and damping separate so the clamp on the spring term
	# never accidentally strips the damping contribution.
	var spring_accel: float = omega * omega * height_error
	var damping_accel: float = -(2.0 * maxf(damping_ratio, 0.0) * omega * vel_along_normal)
	# Only prevent the spring from pulling the body DOWN while it is still
	# below the hover target. Never clamp the damping — it must always be
	# able to decelerate the body as it approaches from either direction.
	if height_error >= 0.0 and spring_accel < 0.0:
		spring_accel = 0.0
	return spring_accel + damping_accel

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

func _tick_debug_log_cooldowns(delta: float) -> void:
	if _debug_log_cooldowns.is_empty():
		return
	var step: float = maxf(delta, 0.0)
	for key_variant in _debug_log_cooldowns.keys():
		var cooldown: float = float(_debug_log_cooldowns.get(key_variant, 0.0))
		cooldown = maxf(cooldown - step, 0.0)
		_debug_log_cooldowns[key_variant] = cooldown

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_ai_floating_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false
	var cooldown: float = float(_debug_log_cooldowns.get(entity_id, 0.0))
	if cooldown > 0.0:
		return false
	_debug_log_cooldowns[entity_id] = maxf(debug_log_interval_sec, 0.05)
	return true

func _debug_log(entity_id: StringName, message: String) -> void:
	if not _consume_debug_log_budget(entity_id):
		return
	print("S_FloatingSystem[entity=%s] %s" % [str(entity_id), message])
