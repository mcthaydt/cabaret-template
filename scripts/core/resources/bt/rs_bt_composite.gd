@icon("res://assets/core/editor_icons/icn_resource.svg")
extends "res://scripts/core/resources/bt/rs_bt_node.gd"
class_name RS_BTComposite

const BT_NODE_SCRIPT_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"

var _children: Array[RS_BTNode] = []

@export var children: Array[RS_BTNode] = []:
	get:
		return _children
	set(value):
		_children = _sanitize_children(value)

func _sanitize_children(value: Variant) -> Array[RS_BTNode]:
	var sanitized: Array[RS_BTNode] = []
	if not (value is Array):
		return sanitized
	for child_variant in value as Array:
		if child_variant is RS_BTNode or _is_bt_node_script_instance(child_variant):
			sanitized.append(child_variant)
	return sanitized

func _is_bt_node_script_instance(value: Variant) -> bool:
	if not (value is Object):
		return false
	var obj: Object = value as Object
	var script_variant: Variant = obj.get_script()
	while script_variant is Script:
		var script: Script = script_variant as Script
		if script.resource_path == BT_NODE_SCRIPT_PATH:
			return true
		script_variant = script.get_base_script()
	return false
