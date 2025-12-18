extends RefCounted
class_name U_SpawnRegistry

## Static registry for spawn metadata.
##
## In production, metadata is provided by scene-attached RS_SpawnMetadata
## resources on SP_SpawnPoint nodes. Tests can still inject metadata
## directly via reload_registry([...]).

static var _spawns_by_id: Dictionary = {}  # StringName -> RS_SpawnMetadata

## Static initializer - start from a clean state.
static func _static_init() -> void:
	_spawns_by_id.clear()

## Reload registry entries from a provided list (tests).
##
## When `spawn_resources` is non-empty, the registry will be populated
## exclusively from that list. When empty, the registry is simply cleared.
static func reload_registry(spawn_resources: Array = []) -> void:
	_spawns_by_id.clear()

	if spawn_resources.is_empty():
		return

	for resource in spawn_resources:
		_register_spawn_resource(resource)

## Reload registry entries from the current scene's spawn point nodes.
##
## This scans for `SP_SpawnPoint` children under the `SP_SpawnPoints`
## container and registers any attached RS_SpawnMetadata resources.
static func reload_from_scene(scene: Node) -> void:
	_spawns_by_id.clear()

	if scene == null:
		return

	# Convention: spawn points live under Entities/SP_SpawnPoints
	var spawn_points_root: Node = scene.get_node_or_null("Entities/SP_SpawnPoints")
	if spawn_points_root == null:
		return

	for child in spawn_points_root.get_children():
		if child is SP_SpawnPoint:
			var spawn_point: SP_SpawnPoint = child
			var metadata: RS_SpawnMetadata = spawn_point.get_spawn_metadata()
			if metadata != null:
				_register_spawn_resource(metadata)

## Get spawn metadata by id (defensive copy).
##
## Returns a dictionary with keys:
## - "spawn_id": StringName
## - "tags": Array[StringName]
## - "priority": int
## - "condition": int (RS_SpawnMetadata.SpawnCondition)
##
## Returns {} when no metadata is registered for the given id.
static func get_spawn(spawn_id: StringName) -> Dictionary:
	if _spawns_by_id.has(spawn_id):
		var metadata: RS_SpawnMetadata = _spawns_by_id[spawn_id]
		return metadata.to_dictionary()
	return {}

## Get all spawn metadata entries that contain the given tag.
##
## Returns an Array of dictionaries in the same shape as get_spawn().
static func get_spawns_by_tag(tag: StringName) -> Array:
	var result: Array = []
	for metadata in _spawns_by_id.values():
		var typed_metadata: RS_SpawnMetadata = metadata
		if typed_metadata.has_tag(tag):
			result.append(typed_metadata.to_dictionary())
	return result

## Internal: load RS_SpawnMetadata resources from a directory.
static func _load_metadata_from_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# Directory doesn't exist; not an error.
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path: String = dir_path + file_name
			var resource: Resource = load(resource_path)
			_register_spawn_resource(resource)

		file_name = dir.get_next()
	dir.list_dir_end()

## Internal: register a single spawn metadata resource.
static func _register_spawn_resource(resource: Resource) -> void:
	if resource == null:
		return

	if not (resource is RS_SpawnMetadata):
		push_warning("U_SpawnRegistry: Resource %s is not RS_SpawnMetadata (found %s), skipping" % [resource, resource.get_class()])
		return

	var metadata := resource as RS_SpawnMetadata
	if not metadata.is_valid():
		push_warning("U_SpawnRegistry: RS_SpawnMetadata has empty spawn_id, skipping")
		return

	var spawn_id: StringName = metadata.spawn_id

	if _spawns_by_id.has(spawn_id):
		var existing: RS_SpawnMetadata = _spawns_by_id[spawn_id]
		# Prefer higher priority entries when duplicates exist.
		if metadata.priority > existing.priority:
			_spawns_by_id[spawn_id] = metadata
		return

	_spawns_by_id[spawn_id] = metadata
