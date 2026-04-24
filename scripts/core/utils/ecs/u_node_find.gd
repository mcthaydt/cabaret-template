extends RefCounted
class_name U_NodeFind


static func find_character_body_recursive(root: Node) -> CharacterBody3D:
	if root == null:
		return null
	if root is CharacterBody3D:
		return root as CharacterBody3D

	for child_variant in root.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue
		var found: CharacterBody3D = find_character_body_recursive(child)
		if found != null and is_instance_valid(found):
			return found

	return null
