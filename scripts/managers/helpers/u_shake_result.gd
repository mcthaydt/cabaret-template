class_name U_ShakeResult
extends RefCounted

var offset: Vector2
var rotation: float


func _init(p_offset: Vector2 = Vector2.ZERO, p_rotation: float = 0.0) -> void:
	offset = p_offset
	rotation = p_rotation
