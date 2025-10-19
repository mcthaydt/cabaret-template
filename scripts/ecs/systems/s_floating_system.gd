extends ECSSystem

class_name S_FloatingSystem

const FLOATING_TYPE := StringName("C_FloatingComponent")

class SupportInfo:
	var has_hit: bool = false
	var distance: float = 0.0
	var normal: Vector3 = Vector3.ZERO

func process_tick(delta: float) -> void:
	var processed: Dictionary = {}
	var now: float = Time.get_ticks_msec() / 1000.0

	for component in get_components(FLOATING_TYPE):
		if component == null:
			continue

		var floating_component: C_FloatingComponent = component as C_FloatingComponent
		if floating_component == null:
			continue

		var body: CharacterBody3D = floating_component.get_character_body()
		if body == null:
			continue

		if processed.has(body):
			continue
		processed[body] = true

		var rays: Array = floating_component.get_raycast_nodes()
		if rays.is_empty():
			floating_component.update_support_state(false, now)
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
			var within_height_tolerance: bool = abs(height_error) <= floating_component.settings.height_tolerance
			var within_speed_tolerance: bool = abs(vel_along_normal) <= floating_component.settings.settle_speed_tolerance
			var support_active: bool = vel_along_normal <= floating_component.settings.settle_speed_tolerance and height_error >= -floating_component.settings.height_tolerance

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

			if floating_component.settings.align_to_normal:
				body.up_direction = normal

			floating_component.update_support_state(support_active, now)
		else:
			velocity.y -= floating_component.settings.fall_gravity * delta
			velocity.y = clamp(velocity.y, -floating_component.settings.max_down_speed, floating_component.settings.max_up_speed)
			floating_component.update_support_state(false, now)

		body.velocity = velocity

func _collect_support_data(rays: Array) -> SupportInfo:
	var data: SupportInfo = SupportInfo.new()
	var min_distance: float = INF
	var normal_sum: Vector3 = Vector3.ZERO
	var hit_count: int = 0

	for ray in rays:
		if ray == null:
			continue

		if ray.has_method('force_raycast_update'):
			ray.force_raycast_update()

		if not ray.is_colliding():
			continue

		data.has_hit = true
		hit_count += 1

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

	return data

func _clamp_velocity_along_normal(velocity: Vector3, normal: Vector3, max_down_speed: float, max_up_speed: float) -> Vector3:
	var vel_along_normal: float = velocity.dot(normal)
	var clamped: float = clamp(vel_along_normal, -max_down_speed, max_up_speed)
	return velocity + normal * (clamped - vel_along_normal)
