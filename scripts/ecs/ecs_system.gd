extends Node

class_name ECSSystem

var _manager: Node

func _ready() -> void:
    call_deferred("_register_with_manager")

func configure(manager: Node) -> void:
    _manager = manager
    on_configured()

func on_configured() -> void:
    pass

func get_manager() -> Node:
    return _manager

func get_components(component_type: StringName) -> Array:
    if _manager == null:
        return []
    if not _manager.has_method("get_components"):
        return []
    var components: Array = _manager.get_components(component_type)
    return components.duplicate()

func process_tick(_delta: float) -> void:
    pass

func _physics_process(delta: float) -> void:
    process_tick(delta)

func _register_with_manager() -> void:
    var manager := _locate_manager()
    if manager == null:
        return
    manager.register_system(self)

func _locate_manager() -> Node:
    var current := get_parent()
    while current != null:
        if current.has_method("register_component") and current.has_method("register_system"):
            return current
        current = current.get_parent()

    var tree := get_tree()
    if tree == null:
        return null

    var managers := tree.get_nodes_in_group("ecs_manager")
    if managers.is_empty():
        return null

    return managers[0]
