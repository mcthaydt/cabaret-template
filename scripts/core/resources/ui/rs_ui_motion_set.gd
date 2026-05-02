@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_UIMotionSet

## Collection of motion sequences for a UI surface and its interactions.

@export_group("Lifecycle")
@export var enter: Array[Resource] = []
@export var exit: Array[Resource] = []

@export_group("Interactions")
@export var hover_in: Array[Resource] = []
@export var hover_out: Array[Resource] = []
@export var press: Array[Resource] = []
@export var focus_in: Array[Resource] = []
@export var focus_out: Array[Resource] = []
@export var pulse: Array[Resource] = []
