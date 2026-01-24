@icon("res://assets/editor_icons/component.svg")
extends BaseECSComponent
class_name C_LandingIndicatorComponent

const COMPONENT_TYPE := StringName("C_LandingIndicatorComponent")

@export var settings: RS_LandingIndicatorSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node3D") var origin_marker_path: NodePath
@export_node_path("Node3D") var landing_marker_path: NodePath

var _indicator_visible: bool = false
var _landing_point: Vector3 = Vector3.ZERO
var _landing_normal: Vector3 = Vector3.UP

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_LandingIndicatorComponent missing settings; assign an RS_LandingIndicatorSettings resource.")
		return false
	return true

func get_character_body() -> CharacterBody3D:
	if character_body_path.is_empty():
		return null
	return get_node_or_null(character_body_path) as CharacterBody3D

func get_origin_marker() -> Node3D:
	if origin_marker_path.is_empty():
		return null
	return get_node_or_null(origin_marker_path) as Node3D

func get_landing_marker() -> Node3D:
	if landing_marker_path.is_empty():
		return null
	return get_node_or_null(landing_marker_path) as Node3D

func set_origin_position(position: Vector3) -> void:
	var origin_marker: Node3D = get_origin_marker()
	_set_marker_global_position(origin_marker, position)

func set_landing_data(point: Vector3, normal: Vector3, visible: bool) -> void:
	_landing_point = point
	_landing_normal = normal
	_update_visibility(visible)
	if not visible:
		return
	var final_normal: Vector3 = normal
	if final_normal.length() == 0.0:
		final_normal = Vector3.UP
	final_normal = final_normal.normalized()
	var landing_marker: Node3D = get_landing_marker()
	var height_offset: float = settings.indicator_height_offset if settings != null else 0.05
	if landing_marker != null:
		# Optionally align the marker's chosen axis to the hit normal
		if settings != null and settings.align_to_hit_normal:
			var _basis_current: Basis = landing_marker.global_transform.basis.orthonormalized()
			var n: Vector3 = final_normal
			var hint: Vector3 = Vector3.FORWARD
			# Avoid parallel hint
			if abs(n.dot(hint)) > 0.95:
				hint = Vector3.RIGHT
			# Build orthonormal frame around n
			var x_axis: Vector3
			var y_axis: Vector3
			var z_axis: Vector3
			# A tangent perpendicular to n
			var tangent: Vector3 = (hint - n * hint.dot(n))
			if tangent.length() < 1e-3:
				tangent = n.cross(Vector3.UP)
			tangent = tangent.normalized()
			var binormal: Vector3 = n.cross(tangent).normalized()
			# Assign basis columns so that chosen axis aligns to n
			var axis_index: int = settings.normal_axis if settings != null else 2
			var axis_positive: bool = settings.normal_axis_positive if settings != null else false
			match axis_index:
				0:
					# X axis aligns to +/-n
					x_axis = (n if axis_positive else -n)
					# Maintain right-handedness: x × y = z
					y_axis = binormal
					z_axis = x_axis.cross(y_axis).normalized()
				1:
					# Y axis aligns to +/-n
					y_axis = (n if axis_positive else -n)
					x_axis = tangent
					z_axis = x_axis.cross(y_axis).normalized()
				2:
					# Z axis aligns to +/-n
					z_axis = (n if axis_positive else -n)
					x_axis = tangent
					y_axis = z_axis.cross(x_axis).normalized()
			# Orthonormalize to be safe
			var target_basis: Basis = Basis(x_axis.normalized(), y_axis.normalized(), z_axis.normalized()).orthonormalized()
			var origin: Vector3 = landing_marker.global_transform.origin
			var old_scale: Vector3 = landing_marker.scale
			landing_marker.global_transform = Transform3D(target_basis, origin)
			landing_marker.scale = old_scale

		# With alignment, offset along the true surface normal is sufficient
		var required_offset: float = height_offset
		if settings == null or not settings.align_to_hit_normal:
			# Ensure at least height_offset clearance along the marker's own up direction when not aligning
			var marker_up: Vector3 = landing_marker.global_transform.basis.y
			if marker_up.length() > 0.0:
				marker_up = marker_up.normalized()
				var alignment: float = marker_up.dot(final_normal)
				var min_dot: float = 0.3
				var denom: float = clamp(abs(alignment), min_dot, 1.0)
				required_offset = height_offset / denom
		_set_marker_global_position(landing_marker, point + final_normal * required_offset)

func is_indicator_visible() -> bool:
	return _indicator_visible

func get_landing_point() -> Vector3:
	return _landing_point

func get_landing_normal() -> Vector3:
	return _landing_normal

func _update_visibility(visible: bool) -> void:
	_indicator_visible = visible
	var landing_marker: Node3D = get_landing_marker()
	_set_marker_visibility(landing_marker, visible)
	var origin_marker: Node3D = get_origin_marker()
	_set_marker_visibility(origin_marker, visible)

func _set_marker_global_position(marker: Node3D, position: Vector3) -> void:
	if marker == null:
		return
	if marker.is_inside_tree():
		marker.global_position = position
	else:
		marker.set_deferred("global_position", position)

func _set_marker_visibility(marker: Node3D, visible: bool) -> void:
	if marker == null:
		return
	if marker.is_inside_tree():
		marker.visible = visible
	else:
		marker.set_deferred("visible", visible)
