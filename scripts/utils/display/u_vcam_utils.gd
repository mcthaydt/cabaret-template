class_name U_VCamUtils
## Shared vCam utility functions extracted from decomposed helpers.


static func get_node_instance_id(node: Node) -> int:
	if node == null:
		return 0
	if not is_instance_valid(node):
		return 0
	return node.get_instance_id()


static func call_apply_position_offset(apply_position_offset: Callable, result: Dictionary, offset: Vector3) -> Dictionary:
	if not apply_position_offset.is_valid():
		return result
	var offset_result_variant: Variant = apply_position_offset.call(result, offset)
	if offset_result_variant is Dictionary:
		return (offset_result_variant as Dictionary).duplicate(true)
	return result