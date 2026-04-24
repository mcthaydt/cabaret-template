@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_BTNode

enum Status {
	RUNNING = 0,
	SUCCESS = 1,
	FAILURE = 2,
}

var node_id: int:
	get:
		return get_instance_id()

func tick(_context: Dictionary, _state_bag: Dictionary) -> Status:
	push_error("RS_BTNode.tick: not implemented by subclass %s" % str(resource_name))
	return Status.FAILURE
