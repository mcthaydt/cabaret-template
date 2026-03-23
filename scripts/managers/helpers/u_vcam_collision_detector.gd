extends RefCounted
class_name U_VCamCollisionDetector

const MAX_RAYCAST_HITS: int = 8
const MAX_GEOMETRY_SEARCH_DEPTH: int = 3
const DEBUG_MAX_GEOMETRY_PATHS: int = 6

static func detect_occluders(
	space_state: Object,
	from: Vector3,
	to: Vector3,
	collision_mask: int,
	debug_enabled: bool = false,
	debug_context: String = ""
) -> Array:
	var occluders: Array = []
	if space_state == null:
		_debug_log(debug_enabled, debug_context, "detect_occluders skipped: space_state is null")
		return occluders
	if collision_mask <= 0:
		_debug_log(
			debug_enabled,
			debug_context,
			"detect_occluders skipped: invalid collision_mask=%d" % collision_mask
		)
		return occluders
	if from.is_equal_approx(to):
		_debug_log(debug_enabled, debug_context, "detect_occluders skipped: from == to")
		return occluders
	if not space_state.has_method("intersect_ray"):
		_debug_log(debug_enabled, debug_context, "detect_occluders skipped: space_state missing intersect_ray")
		return occluders

	_debug_log(
		debug_enabled,
		debug_context,
		"detect_occluders start from=%s to=%s distance=%.3f mask=%d" % [
			str(from),
			str(to),
			from.distance_to(to),
			collision_mask,
		]
	)

	var exclude_rids: Array[RID] = []
	var hit_count: int = 0
	while hit_count < MAX_RAYCAST_HITS:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = collision_mask
		query.exclude = exclude_rids

		var hit_variant: Variant = space_state.call("intersect_ray", query)
		if not (hit_variant is Dictionary):
			_debug_log(
				debug_enabled,
				debug_context,
				"raycast terminated: intersect_ray returned non-dictionary at iteration=%d" % hit_count
			)
			break
		var hit: Dictionary = hit_variant as Dictionary
		if hit.is_empty():
			_debug_log(debug_enabled, debug_context, "raycast terminated: empty hit at iteration=%d" % hit_count)
			break

		_append_hit_rid_to_exclude(hit, exclude_rids)

		var collider_variant: Variant = hit.get("collider", null)
		if not _is_live_object(collider_variant):
			_debug_log(
				debug_enabled,
				debug_context,
				"hit[%d] skipped: collider is invalid/freed (%s)" % [hit_count, str(collider_variant)]
			)
			hit_count += 1
			continue
		var collider: Object = collider_variant as Object

		var collision_layer: int = _resolve_collision_layer(collider)
		if collision_layer >= 0 and (collision_layer & collision_mask) == 0:
			_debug_log(
				debug_enabled,
				debug_context,
				"hit[%d] skipped: collider=%s layer=%d not in mask=%d" % [
					hit_count,
					_describe_object(collider),
					collision_layer,
					collision_mask,
				]
			)
			hit_count += 1
			continue

		var occluder: GeometryInstance3D = _resolve_occluder_geometry(collider)
		if debug_enabled:
			var collider_node := collider as Node
			if collider_node != null:
				var geometry_count: int = _count_geometry_descendants(collider_node)
				var geometry_paths: Array[String] = []
				_collect_geometry_paths(collider_node, geometry_paths, DEBUG_MAX_GEOMETRY_PATHS)
				_debug_log(
					true,
					debug_context,
					"hit[%d] collider=%s geometry_descendants=%d sample_paths=%s selected_occluder=%s" % [
						hit_count,
						_describe_object(collider),
						geometry_count,
						str(geometry_paths),
						_describe_object(occluder),
					]
				)
			else:
				_debug_log(
					true,
					debug_context,
					"hit[%d] collider=%s selected_occluder=%s" % [
						hit_count,
						_describe_object(collider),
						_describe_object(occluder),
					]
				)
		if occluder != null and is_instance_valid(occluder) and not occluders.has(occluder):
			occluders.append(occluder)
		elif debug_enabled:
			_debug_log(
				true,
				debug_context,
				"hit[%d] did not append occluder (null/duplicate/invalid)" % hit_count
			)

		hit_count += 1
	_debug_log(
		debug_enabled,
		debug_context,
		"detect_occluders complete: hits=%d occluders=%d" % [hit_count, occluders.size()]
	)
	return occluders

static func _append_hit_rid_to_exclude(hit: Dictionary, exclude_rids: Array[RID]) -> void:
	var collider_variant: Variant = hit.get("collider", null)
	if _is_live_object(collider_variant):
		var collider: Object = collider_variant as Object
		var collision_object := collider as CollisionObject3D
		if collision_object != null:
			var collider_rid: RID = collision_object.get_rid()
			if collider_rid.is_valid():
				if not exclude_rids.has(collider_rid):
					exclude_rids.append(collider_rid)
				return

	var hit_rid_variant: Variant = hit.get("rid", RID())
	if hit_rid_variant is RID:
		var hit_rid: RID = hit_rid_variant as RID
		if hit_rid.is_valid() and not exclude_rids.has(hit_rid):
			exclude_rids.append(hit_rid)

static func _resolve_collision_layer(collider: Object) -> int:
	if collider == null or not is_instance_valid(collider):
		return -1
	if not _object_has_property(collider, StringName("collision_layer")):
		return -1
	var collision_layer_variant: Variant = collider.get("collision_layer")
	if collision_layer_variant is int:
		return int(collision_layer_variant)
	if collision_layer_variant is float:
		return int(collision_layer_variant)
	return -1

static func _resolve_occluder_geometry(collider: Object) -> GeometryInstance3D:
	if collider == null or not is_instance_valid(collider):
		return null
	var geometry := collider as GeometryInstance3D
	if geometry != null:
		return geometry
	var collider_node := collider as Node
	if collider_node == null:
		return null
	return find_geometry_descendant(collider_node)

static func find_geometry_descendant(
	node: Node,
	max_depth: int = MAX_GEOMETRY_SEARCH_DEPTH,
	_current_depth: int = 0
) -> GeometryInstance3D:
	if node == null or not is_instance_valid(node):
		return null
	var geometry := node as GeometryInstance3D
	if geometry != null:
		return geometry
	if _current_depth >= max_depth:
		return null

	for child_variant in node.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		var found: GeometryInstance3D = find_geometry_descendant(
			child, max_depth, _current_depth + 1
		)
		if found != null:
			return found
	return null

static func _count_geometry_descendants(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	var count: int = 0
	if node is GeometryInstance3D:
		count += 1
	for child_variant in node.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		count += _count_geometry_descendants(child)
	return count

static func _collect_geometry_paths(node: Node, output: Array[String], limit: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	if output.size() >= limit:
		return
	if node is GeometryInstance3D:
		output.append(str(node.get_path()))
		if output.size() >= limit:
			return
	for child_variant in node.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		_collect_geometry_paths(child, output, limit)
		if output.size() >= limit:
			return

static func _describe_object(value: Variant) -> String:
	if not _is_live_object(value):
		return "<invalid>"
	var obj := value as Object
	if obj == null:
		return "<null>"
	var node := obj as Node
	if node == null:
		return "%s#%d" % [obj.get_class(), obj.get_instance_id()]
	var path_text: String = "<off_tree>"
	if node.is_inside_tree():
		path_text = str(node.get_path())
	return "%s(%s)#%d" % [node.get_class(), path_text, node.get_instance_id()]

static func _debug_log(enabled: bool, context: String, message: String) -> void:
	if not enabled:
		return
	var context_text: String = context if not context.is_empty() else "default"
	print(
		"[VCAM_OCCLUSION][CollisionDetector][%s] %s" % [
			context_text,
			message,
		]
	)

static func _object_has_property(target: Object, property_name: StringName) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var property_list: Array[Dictionary] = target.get_property_list()
	for property_variant in property_list:
		var property_info: Dictionary = property_variant as Dictionary
		var name_variant: Variant = property_info.get("name", "")
		if StringName(str(name_variant)) == property_name:
			return true
	return false

static func _is_live_object(value: Variant) -> bool:
	if typeof(value) != TYPE_OBJECT:
		return false
	if value == null:
		return false
	return is_instance_valid(value)
