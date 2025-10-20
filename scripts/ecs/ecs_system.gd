extends Node

class_name ECSSystem

const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

var _manager: M_ECSManager

func _ready() -> void:
	call_deferred("_register_with_manager")

func configure(manager: M_ECSManager) -> void:
	_manager = manager
	on_configured()

func on_configured() -> void:
	pass

func get_manager() -> M_ECSManager:
	return _manager

func get_components(component_type: StringName) -> Array:
	if _manager == null:
		return []
	if not _manager.has_method("get_components"):
		return []
	var components: Array = _manager.get_components(component_type)
	return components.duplicate()

func query_entities(required: Array[StringName], optional: Array[StringName] = []) -> Array:
	if _manager == null:
		return []
	if not _manager.has_method("query_entities"):
		return []
	return _manager.query_entities(required, optional)

func process_tick(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	process_tick(delta)

func _register_with_manager() -> void:
	var manager := ECS_UTILS.get_manager(self) as M_ECSManager
	if manager == null:
		return
	manager.register_system(self)
