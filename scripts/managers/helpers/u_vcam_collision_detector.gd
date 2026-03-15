extends RefCounted
class_name U_VCamCollisionDetector

const MAX_RAYCAST_HITS: int = 32

static func detect_occluders(
	space_state: Object,
	from: Vector3,
	to: Vector3,
	collision_mask: int
) -> Array:
	var occluders: Array = []
	if space_state == null:
		return occluders
	if collision_mask <= 0:
		return occluders
	if from.is_equal_approx(to):
		return occluders
	if not space_state.has_method("intersect_ray"):
		return occluders

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
			break
		var hit: Dictionary = hit_variant as Dictionary
		if hit.is_empty():
			break

		_append_hit_rid_to_exclude(hit, exclude_rids)

		var collider_variant: Variant = hit.get("collider", null)
		if not _is_live_object(collider_variant):
			hit_count += 1
			continue
		var collider: Object = collider_variant as Object

		var collision_layer: int = _resolve_collision_layer(collider)
		if collision_layer >= 0 and (collision_layer & collision_mask) == 0:
			hit_count += 1
			continue

		var occluder: GeometryInstance3D = _resolve_occluder_geometry(collider)
		if occluder != null and is_instance_valid(occluder) and not occluders.has(occluder):
			occluders.append(occluder)

		hit_count += 1
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
	return _find_geometry_descendant(collider_node)

static func _find_geometry_descendant(node: Node) -> GeometryInstance3D:
	if node == null or not is_instance_valid(node):
		return null
	var geometry := node as GeometryInstance3D
	if geometry != null:
		return geometry

	for child_variant in node.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		var found: GeometryInstance3D = _find_geometry_descendant(child)
		if found != null:
			return found
	return null

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
