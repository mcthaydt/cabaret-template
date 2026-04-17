@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/bt/rs_bt_node.gd"
class_name RS_BTComposite

var _children: Array[RS_BTNode] = []

@export var children: Array[RS_BTNode] = []:
	get:
		return _children
	set(value):
		_children = _coerce_children(value)

func _coerce_children(value: Variant) -> Array[RS_BTNode]:
	var coerced: Array[RS_BTNode] = []
	if not (value is Array):
		return coerced
	for child_variant in value as Array:
		if child_variant is RS_BTNode:
			coerced.append(child_variant as RS_BTNode)
	return coerced
