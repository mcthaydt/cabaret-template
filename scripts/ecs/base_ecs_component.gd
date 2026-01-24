@icon("res://assets/editor_icons/component.svg")
extends Node

class_name BaseECSComponent

const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const EVENT_COMPONENT_REGISTERED := StringName("component_registered")

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
	_publish_registered_event(manager)

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

func _publish_registered_event(manager: M_ECSManager) -> void:
	var entity_node := ECS_UTILS.find_entity_root(self)
	var payload: Dictionary = {
		"component_type": _component_type,
		"component": self,
		"entity": entity_node,
		"manager": manager,
	}
	if entity_node != null:
		payload["entity_id"] = ECS_UTILS.get_entity_id(entity_node)
	U_ECSEventBus.publish(EVENT_COMPONENT_REGISTERED, payload)
