extends RefCounted
class_name U_AIRenderProbe

const U_NODE_FIND := preload("res://scripts/core/utils/ecs/u_node_find.gd")


static func build_probe_string(
	entity: Node,
	body: CharacterBody3D,
	movement_component: C_MovementComponent
) -> String:
	var entity_path: String = "<null>"
	if entity != null and is_instance_valid(entity):
		if entity.is_inside_tree():
			entity_path = str(entity.get_path())
		else:
			entity_path = "<detached:%s>" % entity.name

	var resolved_body: CharacterBody3D = body
	if resolved_body == null and movement_component != null:
		resolved_body = movement_component.get_character_body()
	if resolved_body == null:
		resolved_body = U_NODE_FIND.find_character_body_recursive(entity)

	var body_visible: bool = false
	var body_visible_in_tree: bool = false
	var body_position: Vector3 = Vector3.ZERO
	if resolved_body != null and is_instance_valid(resolved_body):
		body_visible = resolved_body.visible
		body_visible_in_tree = resolved_body.is_visible_in_tree()
		if resolved_body.is_inside_tree():
			body_position = resolved_body.global_position
		else:
			body_position = resolved_body.position

	var visual_node: Node3D = _resolve_visual_node(entity, resolved_body)
	var visual_path: String = "<null>"
	var visual_type: String = "null"
	var visual_visible: bool = false
	var visual_visible_in_tree: bool = false
	var visual_transparency: Variant = "n/a"
	var visual_layers: Variant = "n/a"
	if visual_node != null and is_instance_valid(visual_node):
		if visual_node.is_inside_tree():
			visual_path = str(visual_node.get_path())
		else:
			visual_path = "<detached:%s>" % visual_node.name
		visual_type = visual_node.get_class()
		visual_visible = visual_node.visible
		visual_visible_in_tree = visual_node.is_visible_in_tree()
		if visual_node is GeometryInstance3D:
			var geometry: GeometryInstance3D = visual_node as GeometryInstance3D
			visual_transparency = geometry.transparency
			visual_layers = geometry.layers

	return (
		" probe(entity_path=%s body_visible=%s body_visible_tree=%s body_pos=%s visual_path=%s visual_type=%s visual_visible=%s visual_visible_tree=%s visual_transparency=%s visual_layers=%s)"
		% [
			entity_path,
			str(body_visible),
			str(body_visible_in_tree),
			str(body_position),
			visual_path,
			visual_type,
			str(visual_visible),
			str(visual_visible_in_tree),
			str(visual_transparency),
			str(visual_layers),
		]
	)


static func find_character_body_recursive(root: Node) -> CharacterBody3D:
	return U_NODE_FIND.find_character_body_recursive(root)


static func _resolve_visual_node(entity: Node, body: CharacterBody3D) -> Node3D:
	var search_root: Node = body
	if search_root == null:
		search_root = entity
	if search_root == null:
		return null

	var named_visual: Node = search_root.get_node_or_null("Visual")
	if named_visual is Node3D:
		return named_visual as Node3D
	return _find_first_geometry_recursive(search_root)


static func _find_first_geometry_recursive(node: Node) -> Node3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	if node is CSGShape3D:
		return node as CSGShape3D
	for child_variant in node.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue
		var found: Node3D = _find_first_geometry_recursive(child)
		if found != null:
			return found
	return null
