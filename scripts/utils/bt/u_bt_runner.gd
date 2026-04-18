extends RefCounted
class_name U_BTRunner

const RS_BT_NODE := preload("res://scripts/resources/bt/rs_bt_node.gd")

func tick(root: RS_BTNode, context: Dictionary, state_bag: Dictionary) -> int:
	if root == null:
		push_error("U_BTRunner.tick: root is null")
		return RS_BT_NODE.Status.FAILURE

	var status_variant: Variant = root.tick(context, state_bag)
	var status: int = _coerce_status(status_variant)
	_sanitize_state_bag_keys(state_bag)
	return status

func _coerce_status(status_variant: Variant) -> int:
	if status_variant is int:
		var status: int = int(status_variant)
		if status == RS_BT_NODE.Status.RUNNING:
			return status
		if status == RS_BT_NODE.Status.SUCCESS:
			return status
		if status == RS_BT_NODE.Status.FAILURE:
			return status
	push_error("U_BTRunner.tick: root returned invalid status %s" % str(status_variant))
	return RS_BT_NODE.Status.FAILURE

func _sanitize_state_bag_keys(state_bag: Dictionary) -> void:
	var keys: Array = state_bag.keys()
	for key_variant in keys:
		if key_variant is int:
			continue
		push_error("U_BTRunner.tick: state_bag key must be int node_id, got %s" % str(key_variant))
		state_bag.erase(key_variant)
