extends "res://scripts/core/resources/bt/rs_bt_node.gd"
class_name TestBTStatusNode

var fixed_status: int = 0
var tick_count: int = 0

func _init(status: int = 0) -> void:
	fixed_status = status

func tick(_context: Dictionary, _state_bag: Dictionary) -> int:
	tick_count += 1
	return fixed_status
