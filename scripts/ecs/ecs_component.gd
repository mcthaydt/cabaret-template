extends Node

class_name BaseECSComponent

const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

signal registered(manager: M_ECSManager, component: BaseECSComponent)

var _manager: M_ECSManager
var _component_type: StringName = &""

@export var component_type: StringName:
	set(value):
		_component_type = value
	get:
		return _component_type

func _ready() -> void:
	if _component_type == &"":
		_component_type = StringName(get_name())
	if not _validate_required_settings():
		_on_required_settings_missing()
		return
	_on_required_settings_ready()
	call_deferred("_register_with_manager")

func get_component_type() -> StringName:
	return _component_type

func get_snapshot() -> Dictionary:
	return {}

func on_registered(manager: M_ECSManager) -> void:
	_manager = manager
	emit_signal("registered", manager, self)

func get_manager() -> M_ECSManager:
	return _manager

func _register_with_manager() -> void:
	var manager := ECS_UTILS.get_manager(self) as M_ECSManager
	if manager == null:
		return
	manager.register_component(self)

func _validate_required_settings() -> bool:
	return true

func _on_required_settings_ready() -> void:
	pass

func _on_required_settings_missing() -> void:
	set_process(false)
	set_physics_process(false)
