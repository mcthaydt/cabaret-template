extends Node

class_name ECSComponent

signal registered(manager: M_ECSManager, component: ECSComponent)

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
    var manager := _locate_manager()
    if manager == null:
        return
    manager.register_component(self)

func _locate_manager() -> M_ECSManager:
    var current := get_parent()
    while current != null:
        if current.has_method("register_component") and current.has_method("register_system"):
            return current as M_ECSManager
        current = current.get_parent()

    var tree := get_tree()
    if tree == null:
        return null

    var managers := tree.get_nodes_in_group("ecs_manager")
    if managers.is_empty():
        return null

    return managers[0] as M_ECSManager
