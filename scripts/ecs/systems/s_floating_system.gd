@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_FloatingSystem

const FLOATING_TYPE := StringName("C_FloatingComponent")
## Number of consecutive frames required to transition stable ground state
## 4 frames ≈ 67ms at 60fps, filters spring oscillations (~50ms) while staying responsive
const STABLE_GROUND_FRAMES_REQUIRED := 4

@export var debug_logs_enabled: bool = false

var _last_support_state: Dictionary = {}
var _reported_ray_sets: Dictionary = {}

class SupportInfo:
	var has_hit: bool = false
	var distance: float = 0.0
	var normal: Vector3 = Vector3.ZERO
	var hit_count: int = 0
	var total_rays: int = 0
	var hit_ray_names: Array = []
	var miss_ray_names: Array = []

func process_tick(delta: float) -> void:
	var manager := get_manager()
	if manager == null:
		return

	var processed: Dictionary = {}
	var now: float = ECS_UTILS.get_current_time()
	var entities := manager.query_entities([FLOATING_TYPE])

	for entity_query in entities:
		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		if floating_component == null:
			continue

		var body: CharacterBody3D = floating_component.get_character_body()
		if body == null:
			continue

		if processed.has(body):
			continue
		processed[body] = true

		var rays: Array = floating_component.get_raycast_nodes()
		if debug_logs_enabled and not _reported_ray_sets.has(body):
			var names: Array = []
			for r in rays:
				if r is Node3D:
					names.append((r as Node3D).name)
			print("[Floating] %s rays=%d [%s]" % [str(body.name), rays.size(), ", ".join(PackedStringArray(names))])
			_reported_ray_sets[body] = true
		if rays.is_empty():
			floating_component.update_support_state(false, now)
			floating_component.update_stable_ground_state(false, STABLE_GROUND_FRAMES_REQUIRED)
			continue

		var support: SupportInfo = _collect_support_data(rays)
		var velocity: Vector3 = body.velocity

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
				if frequency > 0.0:
					var omega: float = TAU * frequency
					var accel_along_normal: float = (omega * omega * height_error) - (2.0 * damping_ratio * omega * vel_along_normal)
					if height_error >= 0.0 and accel_along_normal < 0.0:
						accel_along_normal = 0.0
					velocity += normal * accel_along_normal * delta
				else:
					velocity -= normal * vel_along_normal

			velocity = _clamp_velocity_along_normal(velocity, normal, floating_component.settings.max_down_speed, floating_component.settings.max_up_speed)

			if floating_component.settings.align_to_normal and support.hit_count >= max(floating_component.settings.min_hits_for_alignment, 1):
				body.up_direction = normal


			if debug_logs_enabled:
				var prev: Variant = _last_support_state.get(body, null)
				var reason := "ok"
				if not support_active:
					if vel_along_normal > floating_component.settings.settle_speed_tolerance:
						reason = "vel_along_normal_exceeds_tolerance"
					elif height_error < -floating_component.settings.height_tolerance:
						reason = "below_min_height"
					else:
						reason = "other"
				if prev == null or (prev as bool) != support_active or support.hit_count < support.total_rays:
					var info := "[Floating] %s support=%s reason=%s dist=%.3f velN=%.3f height_err=%.3f hits=%d/%d hit=[%s] miss=[%s]" % [
						str(body.name),
						str(support_active),
						reason,
						support.distance,
						vel_along_normal,
						height_error,
						support.hit_count,
						support.total_rays,
						", ".join(PackedStringArray(support.hit_ray_names)),
						", ".join(PackedStringArray(support.miss_ray_names))
					]
					print(info)
					_last_support_state[body] = support_active

			floating_component.update_support_state(support_active, now)
			floating_component.update_stable_ground_state(support_active, STABLE_GROUND_FRAMES_REQUIRED)
		else:
			velocity.y -= floating_component.settings.fall_gravity * delta
			velocity.y = clamp(velocity.y, -floating_component.settings.max_down_speed, floating_component.settings.max_up_speed)
			if debug_logs_enabled:
				var prev2: Variant = _last_support_state.get(body, null)
				if prev2 == null or (prev2 as bool) != false:
					print("[Floating] %s support=false (no ray hits)" % str(body.name))
					_last_support_state[body] = false

			floating_component.update_support_state(false, now)
			floating_component.update_stable_ground_state(false, STABLE_GROUND_FRAMES_REQUIRED)

		body.velocity = velocity

func _collect_support_data(rays: Array) -> SupportInfo:
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

func _clamp_velocity_along_normal(velocity: Vector3, normal: Vector3, max_down_speed: float, max_up_speed: float) -> Vector3:
	var vel_along_normal: float = velocity.dot(normal)
	var clamped: float = clamp(vel_along_normal, -max_down_speed, max_up_speed)
	return velocity + normal * (clamped - vel_along_normal)
