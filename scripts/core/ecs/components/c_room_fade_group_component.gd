@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_RoomFadeGroupComponent

const COMPONENT_TYPE := StringName("RoomFadeGroup")
const U_ECS_UTILS := preload("res://scripts/core/utils/ecs/u_ecs_utils.gd")
const RS_ROOM_FADE_SETTINGS_SCRIPT := preload(
	"res://scripts/core/resources/display/vcam/rs_room_fade_settings.gd"
)

@export var group_tag: StringName = StringName("")
@export var fade_normal: Vector3 = Vector3(0.0, 0.0, -1.0)
@export var clip_height_offset: float = 1.5
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RS_RoomFadeSettings") var settings: Resource:
	set(value):
		if value == null:
			_settings = null
			return
		if value.get_script() == RS_ROOM_FADE_SETTINGS_SCRIPT:
			_settings = value
			return
		push_warning("C_RoomFadeGroupComponent.settings expects RS_RoomFadeSettings")
	get:
		return _settings

var current_alpha: float = 1.0

var _settings: Resource = null
var _cached_targets: Array = []
var _cache_valid: bool = false

func _init() -> void:
	component_type = COMPONENT_TYPE

func collect_mesh_targets() -> Array:
	if _cache_valid:
		return _cached_targets
	var targets: Array = []
	var entity_root := U_ECS_UTILS.find_entity_root(self)
	var search_root: Node = entity_root
	if search_root == null:
		search_root = get_parent()
	if search_root == null:
		return targets
	_collect_mesh_targets_recursive(search_root, targets)
	_cached_targets = targets
	_cache_valid = true
	return _cached_targets

func invalidate_target_cache() -> void:
	_cache_valid = false

func is_target_cache_valid() -> bool:
	return _cache_valid

func get_fade_normal_world() -> Vector3:
	var world_normal := fade_normal
	var parent_node := get_parent() as Node3D
	if parent_node != null:
		world_normal = parent_node.global_basis * world_normal
	if world_normal.length_squared() <= 0.000001:
		return Vector3.FORWARD
	return world_normal.normalized()

func get_snapshot() -> Dictionary:
	return {
		"group_tag": group_tag,
		"fade_normal": fade_normal,
		"current_alpha": current_alpha,
	}

func _collect_mesh_targets_recursive(node: Node, targets: Array) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			targets.append(mesh_instance)
	elif node is CSGShape3D:
		targets.append(node as CSGShape3D)
	var children: Array = node.get_children()
	for child_variant in children:
		if child_variant is Node:
			_collect_mesh_targets_recursive(child_variant as Node, targets)
