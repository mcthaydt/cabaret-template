@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_AIScorer

func score(_context: Dictionary) -> float:
	push_error("RS_AIScorer.score: not implemented by subclass %s" % str(resource_name))
	return 0.0
