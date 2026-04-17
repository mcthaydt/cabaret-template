@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/bt/rs_bt_node.gd"
class_name RS_BTDecorator

var _child: RS_BTNode = null

@export var child: RS_BTNode = null:
	get:
		return _child
	set(value):
		_child = value if value is RS_BTNode else null
