extends BaseTest

const C_INVENTORY_COMPONENT := preload("res://scripts/ecs/components/c_inventory_component.gd")
const RS_INVENTORY_SETTINGS := preload("res://scripts/resources/ai/world/rs_inventory_settings.gd")

func _instantiate(capacity: int = 4, allowed_types: Array[StringName] = []) -> Variant:
	var settings: RS_InventorySettings = RS_INVENTORY_SETTINGS.new()
	settings.capacity = capacity
	settings.allowed_types = allowed_types
	var component := C_INVENTORY_COMPONENT.new()
	component.settings = settings
	add_child_autofree(component)
	return component

func test_component_type_constant() -> void:
	assert_eq(C_INVENTORY_COMPONENT.COMPONENT_TYPE, StringName("C_InventoryComponent"))

func test_init_sets_component_type() -> void:
	var component: Variant = _instantiate()
	assert_eq(component.get_component_type(), C_INVENTORY_COMPONENT.COMPONENT_TYPE)

func test_add_increases_item_count() -> void:
	var component: Variant = _instantiate(4)
	var added: int = component.add(&"wood", 2)
	assert_eq(added, 2)
	assert_eq(component.items.get(&"wood", 0), 2)
	assert_eq(component.total(), 2)

func test_add_respects_capacity() -> void:
	var component: Variant = _instantiate(3)
	var added: int = component.add(&"wood", 5)
	assert_eq(added, 3)
	assert_eq(component.total(), 3)

func test_add_respects_allowed_types() -> void:
	var component: Variant = _instantiate(10, [&"wood"])
	var added: int = component.add(&"stone", 1)
	assert_eq(added, 0)
	added = component.add(&"wood", 1)
	assert_eq(added, 1)

func test_remove_decreases_item_count() -> void:
	var component: Variant = _instantiate(4)
	component.add(&"wood", 3)
	var removed: int = component.remove(&"wood", 2)
	assert_eq(removed, 2)
	assert_eq(component.items.get(&"wood", 0), 1)

func test_remove_clamps_to_available() -> void:
	var component: Variant = _instantiate(4)
	component.add(&"wood", 2)
	var removed: int = component.remove(&"wood", 5)
	assert_eq(removed, 2)
	assert_false(component.items.has(&"wood"))

func test_total_sums_all_types() -> void:
	var component: Variant = _instantiate(10)
	component.add(&"wood", 3)
	component.add(&"stone", 2)
	assert_eq(component.total(), 5)

func test_is_full() -> void:
	var component: Variant = _instantiate(2)
	assert_false(component.is_full())
	component.add(&"wood", 2)
	assert_true(component.is_full())

func test_has_type() -> void:
	var component: Variant = _instantiate(4)
	assert_false(component.has_type(&"wood"))
	component.add(&"wood", 1)
	assert_true(component.has_type(&"wood"))

func test_add_returns_zero_when_no_settings() -> void:
	var component := C_INVENTORY_COMPONENT.new()
	autofree(component)
	var added: int = component.add(&"wood", 1)
	assert_eq(added, 0)