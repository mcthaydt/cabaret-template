extends RefCounted
class_name U_AIBTTaskLabelResolver

const RS_BT_NODE := preload("res://scripts/core/resources/bt/rs_bt_node.gd")
const RS_BT_ACTION := preload("res://scripts/core/resources/ai/bt/rs_bt_action.gd")
const RS_BT_COMPOSITE := preload("res://scripts/core/resources/bt/rs_bt_composite.gd")
const RS_BT_DECORATOR := preload("res://scripts/core/resources/bt/rs_bt_decorator.gd")

const BT_ACTION_STATE_BAG_KEY := &"bt_action_state_bag"

static func resolve_task_id(brain_settings: RS_AIBrainSettings, bt_state_bag: Dictionary) -> StringName:
	if brain_settings == null:
		return StringName()
	var running_action_node_id: int = _resolve_running_action_node_id(bt_state_bag)
	if running_action_node_id < 0:
		return StringName()
	var root: RS_BTNode = brain_settings.root
	if root == null:
		return StringName()
	var node_by_id: Dictionary = {}
	_collect_bt_nodes(root, node_by_id)
	var node_variant: Variant = node_by_id.get(running_action_node_id, null)
	if not (node_variant is RS_BTAction):
		return StringName()
	var action_node: RS_BTAction = node_variant as RS_BTAction
	return _resolve_task_label_from_action(action_node.action)

static func _resolve_running_action_node_id(bt_state_bag: Dictionary) -> int:
	for node_id_variant in bt_state_bag.keys():
		if not (node_id_variant is int):
			continue
		var node_state_variant: Variant = bt_state_bag.get(node_id_variant, null)
		if not (node_state_variant is Dictionary):
			continue
		var node_state: Dictionary = node_state_variant as Dictionary
		if node_state.has(BT_ACTION_STATE_BAG_KEY) or node_state.has(String(BT_ACTION_STATE_BAG_KEY)):
			return int(node_id_variant)
	return -1

static func _collect_bt_nodes(node: RS_BTNode, node_by_id: Dictionary) -> void:
	if node == null:
		return
	node_by_id[node.node_id] = node
	if node is RS_BTComposite:
		var composite: RS_BTComposite = node as RS_BTComposite
		for child in composite.children:
			_collect_bt_nodes(child, node_by_id)
		return
	if node is RS_BTDecorator:
		var decorator: RS_BTDecorator = node as RS_BTDecorator
		_collect_bt_nodes(decorator.child, node_by_id)

static func _resolve_task_label_from_action(action: I_AIAction) -> StringName:
	if action == null:
		return StringName()
	var script_variant: Variant = action.get_script()
	if script_variant is Script:
		var script: Script = script_variant as Script
		var script_path: String = str(script.resource_path)
		if not script_path.is_empty():
			var file_name: String = script_path.get_file().get_basename()
			if file_name.begins_with("rs_ai_action_"):
				return StringName(file_name.trim_prefix("rs_ai_action_"))
			if file_name.begins_with("rs_ai_action"):
				return StringName(file_name.trim_prefix("rs_ai_action"))
			return StringName(file_name)
	return StringName()
