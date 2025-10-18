extends ECSSystem

class_name S_LandingIndicatorSystem

const COMPONENT_TYPE := StringName("C_LandingIndicatorComponent")
const UP_VECTOR: Vector3 = Vector3.UP

func process_tick(_delta: float) -> void:
	for base_component in get_components(COMPONENT_TYPE):
		if base_component == null:
			continue

		var component: C_LandingIndicatorComponent = base_component as C_LandingIndicatorComponent
		if component == null:
			continue

		var body: CharacterBody3D = component.get_character_body()
		if body == null:
			component.set_landing_data(Vector3.ZERO, UP_VECTOR, false)
			continue

		var origin_position: Vector3 = body.global_transform.origin
		component.set_origin_position(origin_position)

		var result: Dictionary = _project_to_ground(component, body, origin_position)
		var is_visible: bool = result["visible"] as bool
		if is_visible:
			var landing_point: Vector3 = result["point"] as Vector3
			var landing_normal: Vector3 = result["normal"] as Vector3
			component.set_landing_data(landing_point, landing_normal, true)
		else:
			component.set_landing_data(Vector3.ZERO, UP_VECTOR, false)

func _project_to_ground(component: C_LandingIndicatorComponent, body: CharacterBody3D, origin_position: Vector3) -> Dictionary:
	var max_distance: float = max(component.settings.max_projection_distance, 0.0)
	if max_distance <= 0.0:
		return _build_projection_result(false, Vector3.ZERO, UP_VECTOR)

	var space_state: Object = _extract_space_state(body)
	if space_state != null and space_state.has_method("intersect_ray"):
		var hit: Dictionary = _cast_down_ray(space_state, body, origin_position, max_distance)
		if not hit.is_empty():
			return _build_projection_result(true, hit["point"], hit["normal"])

	var plane_hit: Dictionary = _project_to_plane(origin_position, component.settings.ground_plane_height, max_distance)
	if not plane_hit.is_empty():
		return _build_projection_result(true, plane_hit["point"], plane_hit["normal"])

	return _build_projection_result(false, Vector3.ZERO, UP_VECTOR)

func _cast_down_ray(space_state: Object, body: CharacterBody3D, origin_position: Vector3, max_distance: float) -> Dictionary:
	var target_position: Vector3 = origin_position + Vector3.DOWN * max_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin_position, target_position)
	var exclude: Array = []
	exclude.append(body.get_rid())
	query.exclude = exclude
	var result_variant: Variant = space_state.call("intersect_ray", query)
	if not (result_variant is Dictionary):
		return {}
	var result: Dictionary = result_variant
	if not result.has("position"):
		return {}
	var point: Vector3 = result["position"] as Vector3
	var normal: Vector3 = UP_VECTOR
	if result.has("normal"):
		var candidate_normal: Vector3 = result["normal"] as Vector3
		if candidate_normal.length() > 0.0:
			normal = candidate_normal.normalized()
	return {
		"point": point,
		"normal": normal,
	}

func _project_to_plane(origin_position: Vector3, plane_height: float, max_distance: float) -> Dictionary:
	var distance_to_plane: float = origin_position.y - plane_height
	if distance_to_plane < 0.0:
		return {}
	if distance_to_plane > max_distance:
		return {}
	return {
		"point": Vector3(origin_position.x, plane_height, origin_position.z),
		"normal": UP_VECTOR,
	}

func _extract_space_state(body: CharacterBody3D) -> Object:
	var world_object: Object = body.get_world_3d()
	if world_object == null:
		return null
	if world_object is World3D:
		var world: World3D = world_object
		return world.direct_space_state
	if world_object.has_method("get"):
		var candidate_variant: Variant = world_object.call("get", "direct_space_state")
		if candidate_variant is Object:
			return candidate_variant
	return null

func _build_projection_result(visible: bool, point: Vector3, normal: Vector3) -> Dictionary:
	return {
		"visible": visible,
		"point": point,
		"normal": normal,
	}
