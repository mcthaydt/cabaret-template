extends RefCounted

class_name EntityQuery

var entity: Node = null

var _components: Dictionary = {}

var components: Dictionary:
	set(value):
		if value == null:
			_components = {}
			return
		if value is Dictionary:
			_components = (value as Dictionary).duplicate(true)
			return
		push_warning("EntityQuery.components expects a Dictionary of components.")
		_components = {}
	get:
		return _components.duplicate(true)

func get_component(component_type: StringName) -> ECSComponent:
	return _components.get(component_type) as ECSComponent

func has_component(component_type: StringName) -> bool:
	if not _components.has(component_type):
		return false
	return _components.get(component_type) != null

func get_all_components() -> Dictionary:
	return _components.duplicate(true)
