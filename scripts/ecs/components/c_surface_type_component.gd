@icon("res://assets/editor_icons/component.svg")
extends BaseECSComponent
class_name C_SurfaceTypeComponent

const COMPONENT_TYPE := StringName("C_SurfaceTypeComponent")
const C_SURFACE_DETECTOR := preload("res://scripts/ecs/components/c_surface_detector_component.gd")

@export var surface_type: int = C_SURFACE_DETECTOR.SurfaceType.DEFAULT

func _init() -> void:
	component_type = COMPONENT_TYPE

func _register_with_manager() -> void:
	var manager := ECS_UTILS.get_manager(self) as M_ECSManager
	if manager == null:
		return
	if ECS_UTILS.find_entity_root(self, false) == null:
		return
	manager.register_component(self)

func get_surface_type() -> int:
	return surface_type
