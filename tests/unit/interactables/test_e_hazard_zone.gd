extends BaseTest

const E_HazardZone := preload("res://scripts/gameplay/e_hazard_zone.gd")
const C_DamageZoneComponent := preload("res://scripts/ecs/components/c_damage_zone_component.gd")

class TestDamageZoneComponent:
	extends C_DamageZoneComponent

	var area_path_set: NodePath = NodePath("")

	func set_area_path(path: NodePath) -> void:
		area_path_set = path
		super.set_area_path(path)

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_controller() -> E_HazardZone:
	var controller := E_HazardZone.new()
	controller.component_factory = Callable(self, "_create_damage_zone_stub")
	controller.damage_amount = 42.0
	controller.is_instant_death = true
	controller.damage_cooldown = 2.5
	add_child(controller)
	autofree(controller)
	await _pump_frames(3)
	return controller

func _create_damage_zone_stub() -> TestDamageZoneComponent:
	return TestDamageZoneComponent.new()

func test_hazard_component_configured() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller) as TestDamageZoneComponent
	assert_not_null(component, "Hazard controller should instantiate C_DamageZoneComponent.")

	assert_eq(component.damage_amount, 42.0)
	assert_true(component.is_instant_death, "Instant death flag should propagate.")
	assert_eq(component.damage_cooldown, 2.5)
	assert_eq(component.collision_layer_mask, 1, "Default settings should map player mask to collision mask.")

	var area := controller.get_trigger_area()
	assert_not_null(area)
	assert_true(component.get_damage_area() == area, "Component should reuse hazard trigger area.")

func _find_component(controller: Node) -> C_DamageZoneComponent:
	for child in controller.get_children():
		if child is C_DamageZoneComponent:
			return child as C_DamageZoneComponent
	return null
