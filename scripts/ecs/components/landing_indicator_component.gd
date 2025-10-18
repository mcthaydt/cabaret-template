extends ECSComponent

class_name LandingIndicatorComponent

const COMPONENT_TYPE := StringName('LandingIndicatorComponent')

@export var settings: LandingIndicatorSettings
@export_node_path('CharacterBody3D') var character_body_path: NodePath
@export_node_path('Node3D') var origin_marker_path: NodePath
@export_node_path('Node3D') var landing_marker_path: NodePath

var _indicator_visible: bool = false
var _landing_point: Vector3 = Vector3.ZERO
var _landing_normal: Vector3 = Vector3.UP

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	if settings == null:
		push_error("LandingIndicatorComponent missing settings; assign a LandingIndicatorSettings resource.")
		set_process(false)
		set_physics_process(false)
		return
	super._ready()

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
	_set_marker_global_position(landing_marker, point + final_normal * height_offset)

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
		marker.set_deferred('global_position', position)

func _set_marker_visibility(marker: Node3D, visible: bool) -> void:
	if marker == null:
		return
	if marker.is_inside_tree():
		marker.visible = visible
	else:
		marker.set_deferred('visible', visible)
