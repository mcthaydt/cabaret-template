extends Node

class_name ECSManager

signal component_added(component_type, component)
signal component_removed(component_type, component)

var _components: Dictionary = {}
var _systems: Array = []

func _ready() -> void:
    add_to_group("ecs_manager")

func _exit_tree() -> void:
    if is_in_group("ecs_manager"):
        remove_from_group("ecs_manager")

func register_component(component) -> void:
    if component == null:
        push_warning("Attempted to register a null component")
        return

    var type_name: StringName = component.get_component_type()
    if not _components.has(type_name):
        _components[type_name] = []

    var existing: Array = _components[type_name]
    if existing.has(component):
        return

    existing.append(component)

    component.on_registered(self)
    component_added.emit(type_name, component)

func unregister_component(component) -> void:
    if component == null:
        return

    var type_name: StringName = component.get_component_type()
    if not _components.has(type_name):
        return

    var existing: Array = _components[type_name]
    if not existing.has(component):
        return

    existing.erase(component)
    component_removed.emit(type_name, component)

    if existing.is_empty():
        _components.erase(type_name)

func get_components(component_type: StringName) -> Array:
    if not _components.has(component_type):
        return []
    return _components[component_type].duplicate()

func get_systems() -> Array:
    return _systems.duplicate()

func register_system(system) -> void:
    if system == null:
        push_warning("Attempted to register a null system")
        return

    if _systems.has(system):
        return

    _systems.append(system)
    system.configure(self)
