extends RefCounted
class_name U_HTNPlannerContext

var evaluation_context: Dictionary = {}
var reusable_rule: RS_Rule = null
var recursion_stack: Dictionary = {}
var result: Array[Resource] = []
var max_depth: int = 0
var depth: int = 0

func _init(in_evaluation_context: Dictionary, in_reusable_rule: RS_Rule, in_max_depth: int) -> void:
	evaluation_context = in_evaluation_context
	reusable_rule = in_reusable_rule
	max_depth = in_max_depth
