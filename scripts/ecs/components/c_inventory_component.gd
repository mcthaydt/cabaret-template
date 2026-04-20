@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_InventoryComponent

const COMPONENT_TYPE := StringName("C_InventoryComponent")

@export var settings: RS_InventorySettings = null

var items: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_InventoryComponent missing settings; assign an RS_InventorySettings resource.")
		return false
	return true

func add(type: StringName, qty: int) -> int:
	if settings == null:
		return 0
	var space := settings.capacity - total()
	if space <= 0:
		return 0
	if not settings.allowed_types.is_empty() and type not in settings.allowed_types:
		return 0
	var to_add := mini(qty, space)
	items[type] = items.get(type, 0) + to_add
	return to_add

func remove(type: StringName, qty: int) -> int:
	var current: int = items.get(type, 0)
	if current <= 0:
		return 0
	var to_remove := mini(qty, current)
	items[type] = current - to_remove
	if items[type] == 0:
		items.erase(type)
	return to_remove

func total() -> int:
	var sum := 0
	for value in items.values():
		sum += value
	return sum

func is_full() -> bool:
	if settings == null:
		return true
	return total() >= settings.capacity

func has_type(type: StringName) -> bool:
	return items.get(type, 0) > 0