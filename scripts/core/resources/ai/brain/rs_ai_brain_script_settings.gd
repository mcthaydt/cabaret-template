@icon("res://assets/core/editor_icons/icn_resource.svg")
extends RS_AIBrainSettings
class_name RS_AIBrainScriptSettings

@export var builder_script: Script = null

func get_root() -> RS_BTNode:
	if root != null:
		return root
	if builder_script == null:
		return null
	var builder: Object = builder_script.new()
	if builder == null or not builder.has_method("build"):
		return null
	var result: Variant = builder.call("build")
	if result == null or not (result is RS_BTNode):
		return null
	root = result as RS_BTNode
	return root
