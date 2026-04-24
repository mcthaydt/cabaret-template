@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_ResourceNodeSettings

@export var resource_type: StringName = &"wood"
@export_range(1, 999, 1, "or_greater") var initial_amount: int = 5
@export_range(0.0, 600.0, 1.0, "or_greater") var regrow_seconds: float = 30.0
@export var harvest_tag: StringName = &"harvest_wood"