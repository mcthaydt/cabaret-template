extends RefCounted

class_name U_ECSUtils

const META_ENTITY_ROOT := StringName("_ecs_entity_root")
const ENTITY_GROUP := StringName("ecs_entity")
const MANAGER_GROUP := StringName("ecs_manager")
const ECS_ENTITY_SCRIPT := preload("res://scripts/ecs/base_ecs_entity.gd")

static var _warning_handler: Callable = Callable()
static var _manager_method_warnings: Dictionary = {}

## Get the M_ECSManager from injection, parent traversal, or groups
##
## Lookup order (Phase 10B-8):
##   1. Check if node has 'ecs_manager' @export (for test injection)
##   2. Parent traversal (existing pattern)
##   3. Group lookup (existing fallback)
static func get_manager(from_node: Node) -> Node:
	if from_node == null:
		return null

	# Priority 1: Check for injected manager (test pattern, Phase 10B-8)
	if from_node.has_method("get") and from_node.has("ecs_manager"):
		var injected: Variant = from_node.get("ecs_manager")
		if injected != null and is_instance_valid(injected):
			return injected as Node

	# Priority 2: Parent traversal (existing pattern)
	var current: Node = from_node.get_parent()
	while current != null:
		if _node_has_manager_methods(current):
			return current
		_warn_missing_manager_methods(current)
		current = current.get_parent()

	# Priority 3: Group lookup (existing fallback)
	var manager: Node = get_singleton_from_group(from_node, MANAGER_GROUP, false)
	if manager != null:
		if _node_has_manager_methods(manager):
			return manager
		_warn_missing_manager_methods(manager)

	return null

static func find_entity_root(from_node: Node, warn_on_missing: bool = false) -> Node:
	if from_node == null:
		return null

	var visited: Array[Node] = []
	var current: Node = from_node
	while current != null:
		visited.append(current)
		if current.has_meta(META_ENTITY_ROOT):
			var stored_value: Variant = current.get_meta(META_ENTITY_ROOT)
			var stored_node: Node = stored_value as Node
			if stored_node != null and is_instance_valid(stored_node):
				return _cache_entity_root(stored_node, visited)

		var current_script: Script = current.get_script()
		if current_script == ECS_ENTITY_SCRIPT:
			return _cache_entity_root(current, visited)

		if current.is_in_group(ENTITY_GROUP):
			return _cache_entity_root(current, visited)

		if String(current.name).begins_with("E_"):
			return _cache_entity_root(current, visited)

		current = current.get_parent()

	if warn_on_missing:
		_emit_warning("U_ECSUtils: Node %s has no ECS entity root." % _describe_node(from_node))
	return null

static func get_current_time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

static func map_components_by_body(manager: M_ECSManager, component_type: StringName) -> Dictionary:
	var result: Dictionary = {}
	if manager == null:
		return result

	var components: Array = manager.get_components(component_type)
	for entry in components:
		var ecs_component: BaseECSComponent = entry as BaseECSComponent
		if ecs_component == null:
			continue
		if not ecs_component.has_method("get_character_body"):
			continue

		var body: Node = ecs_component.get_character_body()
		if body == null:
			continue

		result[body] = ecs_component

	return result

static func get_singleton_from_group(from_node: Node, group_name: StringName, warn_on_missing: bool = true) -> Node:
	if from_node == null:
		return null

	var tree: SceneTree = from_node.get_tree()
	if tree == null:
		return null

	var nodes: Array = tree.get_nodes_in_group(group_name)
	if not nodes.is_empty():
		return nodes[0]

	if warn_on_missing:
		_emit_warning("U_ECSUtils: No node found in group '%s'" % String(group_name))
	return null

static func get_nodes_from_group(from_node: Node, group_name: StringName) -> Array:
	if from_node == null:
		return []

	var tree: SceneTree = from_node.get_tree()
	if tree == null:
		return []

	var nodes: Array = tree.get_nodes_in_group(group_name)
	return nodes.duplicate()

static func get_active_camera(from_node: Node) -> Camera3D:
	if from_node == null:
		return null

	var viewport: Viewport = from_node.get_viewport()
	if viewport != null:
		var viewport_camera: Camera3D = viewport.get_camera_3d()
		if viewport_camera != null:
			return viewport_camera

	return get_singleton_from_group(from_node, StringName("main_camera"), false) as Camera3D

## Returns the entity ID for the given entity node.
## Calls entity.get_entity_id() if available, otherwise generates from name.
static func get_entity_id(entity: Node) -> StringName:
	if entity == null:
		return StringName("")
	if entity.has_method("get_entity_id"):
		return entity.get_entity_id()

	# Fallback: generate ID from node name
	var node_name := String(entity.name)
	if node_name.begins_with("E_"):
		node_name = node_name.substr(2)
	return StringName(node_name.to_lower())

## Returns the tags for the given entity node.
## Calls entity.get_tags() if available, otherwise returns empty array.
static func get_entity_tags(entity: Node) -> Array[StringName]:
	if entity == null:
		return []
	if entity.has_method("get_tags"):
		var tags_variant: Variant = entity.get_tags()
		if tags_variant is Array:
			var result: Array[StringName] = []
			for tag in tags_variant:
				result.append(StringName(tag))
			return result
	return []

## Builds a snapshot dictionary for an entity node.
## Includes entity_id, tags, and physics data (position, rotation, velocity, etc.)
## Used for syncing entity state to the Redux store.
static func build_entity_snapshot(entity: Node) -> Dictionary:
	if entity == null:
		return {}

	var snapshot: Dictionary = {}

	# Entity ID (as String for dictionary keys)
	var entity_id := get_entity_id(entity)
	snapshot["entity_id"] = String(entity_id)

	# Tags (as Array[String] for serialization)
	var tags := get_entity_tags(entity)
	var tags_array: Array[String] = []
	for tag in tags:
		tags_array.append(String(tag))
	snapshot["tags"] = tags_array

	# Physics data (if Node3D)
	if entity is Node3D:
		var node3d := entity as Node3D
		snapshot["position"] = node3d.global_position
		snapshot["rotation"] = node3d.rotation

		# Velocity and floor status (if CharacterBody3D)
		if entity is CharacterBody3D:
			var body := entity as CharacterBody3D
			snapshot["velocity"] = body.velocity
			snapshot["is_on_floor"] = body.is_on_floor()

	return snapshot

static func set_warning_handler(handler: Callable) -> void:
	_warning_handler = handler

static func reset_warning_handler() -> void:
	_warning_handler = Callable()

static func _node_has_manager_methods(candidate: Node) -> bool:
	if candidate == null:
		return false
	return candidate.has_method("register_component") and candidate.has_method("register_system")

static func _cache_entity_root(entity: Node, visited: Array[Node]) -> Node:
	if entity == null:
		return null
	entity.set_meta(META_ENTITY_ROOT, entity)
	for node in visited:
		if node == null:
			continue
		node.set_meta(META_ENTITY_ROOT, entity)
	return entity

static func _warn_missing_manager_methods(candidate: Node) -> void:
	if candidate == null:
		return
	if not _should_emit_debug_warning():
		return
	if not _is_potential_manager(candidate):
		return

	var key: String = "missing_manager_methods:%d" % candidate.get_instance_id()
	if _manager_method_warnings.has(key):
		return
	_manager_method_warnings[key] = true

	var identifier: String = String(candidate.name)
	if candidate.is_inside_tree():
		identifier = String(candidate.get_path())

	_emit_warning("U_ECSUtils: Node '%s' looks like an ECS manager but is missing required methods." % String(identifier))

static func _is_potential_manager(candidate: Node) -> bool:
	if candidate == null:
		return false
	if candidate is M_ECSManager:
		return true
	if candidate.is_in_group(MANAGER_GROUP):
		return true
	return String(candidate.name).begins_with("M_")

static func _should_emit_debug_warning() -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint()

static func _describe_node(node: Node) -> String:
	if node == null:
		return "<null>"
	if node.is_inside_tree():
		return String(node.get_path())
	return "%s(%d)" % [String(node.name), node.get_instance_id()]

static func _emit_warning(message: String) -> void:
	if _warning_handler != Callable() and _warning_handler.is_valid():
		_warning_handler.call(message)
	else:
		push_warning(message)
