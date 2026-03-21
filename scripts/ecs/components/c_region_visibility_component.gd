@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_RegionVisibilityComponent

const COMPONENT_TYPE := StringName("RegionVisibility")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const RS_REGION_VISIBILITY_SETTINGS_SCRIPT := preload(
	"res://scripts/resources/display/vcam/rs_region_visibility_settings.gd"
)

@export var region_tag: StringName = StringName("")
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RS_RegionVisibilitySettings") var settings: Resource:
	set(value):
		if value == null:
			_settings = null
			return
		if value.get_script() == RS_REGION_VISIBILITY_SETTINGS_SCRIPT:
			_settings = value
			return
		push_warning("C_RegionVisibilityComponent.settings expects RS_RegionVisibilitySettings")
	get:
		return _settings

var current_alpha: float = 1.0
var is_active_region: bool = false
var is_near_region: bool = false

var _settings: Resource = null
var _cached_targets: Array = []
var _cache_valid: bool = false
var _cached_aabb: AABB = AABB()
var _aabb_cache_valid: bool = false

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

func get_region_aabb() -> AABB:
	if _aabb_cache_valid:
		return _cached_aabb
	var targets: Array = collect_mesh_targets()
	if targets.is_empty():
		_cached_aabb = AABB()
		_aabb_cache_valid = true
		return _cached_aabb
	var first_valid: Node3D = null
	for target_variant in targets:
		if target_variant is Node3D:
			first_valid = target_variant as Node3D
			break
	if first_valid == null:
		_cached_aabb = AABB()
		_aabb_cache_valid = true
		return _cached_aabb
	var result: AABB = AABB(first_valid.global_position, Vector3.ZERO)
	for target_variant in targets:
		if target_variant is Node3D:
			var target := target_variant as Node3D
			result = result.expand(target.global_position)
	_cached_aabb = result
	_aabb_cache_valid = true
	return _cached_aabb

func invalidate_target_cache() -> void:
	_cache_valid = false
	_aabb_cache_valid = false

func is_target_cache_valid() -> bool:
	return _cache_valid

func get_snapshot() -> Dictionary:
	return {
		"region_tag": region_tag,
		"current_alpha": current_alpha,
		"is_active_region": is_active_region,
		"is_near_region": is_near_region,
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
