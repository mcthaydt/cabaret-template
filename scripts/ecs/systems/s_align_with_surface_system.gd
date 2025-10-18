extends ECSSystem

class_name S_AlignWithSurfaceSystem

const ALIGN_TYPE := StringName("C_AlignWithSurfaceComponent")

func process_tick(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	for component in get_components(ALIGN_TYPE):
		if component == null:
			continue

		var align_component: C_AlignWithSurfaceComponent = component as C_AlignWithSurfaceComponent
		if align_component == null:
			continue

		var body: CharacterBody3D = align_component.get_character_body()
		var visual: Node3D = align_component.get_visual_node()
		if body == null or visual == null:
			continue

		var visual_scale: Vector3 = visual.scale

		if align_component.settings.align_only_when_supported:
			var tolerance := align_component.settings.recent_support_tolerance
			if not align_component.has_recent_support(now, tolerance):
				continue

		var target_up := body.up_direction.normalized()
		if target_up.length() == 0.0:
			target_up = align_component.settings.fallback_up_direction.normalized()
		if target_up.length() == 0.0:
			target_up = Vector3.UP

		var body_forward := _project_onto_plane(-body.global_transform.basis.z, target_up)
		if body_forward.length() == 0.0:
			body_forward = _project_onto_plane(-visual.global_transform.basis.z, target_up)
		if body_forward.length() == 0.0:
			body_forward = _project_onto_plane(Vector3.FORWARD, target_up)

		if body_forward.length() == 0.0:
			continue

		body_forward = body_forward.normalized()

		var target_right := body_forward.cross(target_up)
		if target_right.length() == 0.0:
			continue
		target_right = target_right.normalized()

		var target_forward := target_up.cross(target_right).normalized()

		var target_basis := Basis(target_right, target_up, -target_forward).orthonormalized()
		var current_basis := visual.global_transform.basis.orthonormalized()

		var smoothing: float = max(align_component.settings.smoothing_speed, 0.0)
		var new_basis: Basis
		if smoothing <= 0.0:
			new_basis = target_basis
		else:
			var t: float = clamp(smoothing * delta, 0.0, 1.0)
			var current_quat := current_basis.get_rotation_quaternion()
			var target_quat := target_basis.get_rotation_quaternion()
			var result_quat := current_quat.slerp(target_quat, t)
			new_basis = Basis(result_quat)

		var origin := visual.global_transform.origin
		visual.global_transform = Transform3D(new_basis, origin)
		visual.scale = visual_scale

func _project_onto_plane(vector: Vector3, plane_normal: Vector3) -> Vector3:
	var normal := plane_normal.normalized()
	if normal.length() == 0.0:
		return Vector3.ZERO
	return vector - normal * vector.dot(normal)
