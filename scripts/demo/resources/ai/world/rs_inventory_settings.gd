@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_InventorySettings

@export_range(1, 999, 1, "or_greater") var capacity: int = 4
@export var allowed_types: Array[StringName] = []