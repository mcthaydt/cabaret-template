@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_MoveTargetComponent

const COMPONENT_TYPE := StringName("C_MoveTargetComponent")

@export var target_position: Vector3 = Vector3.ZERO
@export_range(0.0, 10.0, 0.01) var arrival_threshold: float = 0.5
@export var is_active: bool = false

func _init() -> void:
	component_type = COMPONENT_TYPE
