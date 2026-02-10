extends BaseTest

const RS_HAZARD_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_hazard_interaction_config.gd")
const RS_CHECKPOINT_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_checkpoint_interaction_config.gd")
const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/resources/ecs/rs_scene_trigger_settings.gd")

class TestDamageZoneComponent:
	extends C_DamageZoneComponent

	var area_path_set: NodePath = NodePath("")

	func set_area_path(path: NodePath) -> void:
		area_path_set = path
		super.set_area_path(path)

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_controller() -> Inter_HazardZone:
	var controller := Inter_HazardZone.new()
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

func test_config_resource_overrides_export_values() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)
	assert_not_null(component, "Hazard component should exist before config assignment.")

	var config := RS_HAZARD_INTERACTION_CONFIG.new()
	config.damage_amount = 7.5
	config.is_instant_death = false
	config.damage_cooldown = 0.4
	var trigger_settings := RS_SCENE_TRIGGER_SETTINGS.new()
	trigger_settings.player_mask = 4
	config.trigger_settings = trigger_settings

	controller.config = config
	await _pump_frames(1)

	assert_eq(component.damage_amount, 7.5)
	assert_false(component.is_instant_death, "Config should override instant death flag.")
	assert_eq(component.damage_cooldown, 0.4)
	assert_eq(component.collision_layer_mask, 4, "Hazard collision mask should follow config trigger settings.")

func test_non_matching_config_uses_export_fallback() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)
	assert_not_null(component, "Hazard component should exist before fallback check.")

	var wrong_config := RS_CHECKPOINT_INTERACTION_CONFIG.new()
	controller.config = wrong_config
	await _pump_frames(1)

	assert_eq(component.damage_amount, 42.0)
	assert_true(component.is_instant_death)
	assert_eq(component.damage_cooldown, 2.5)
	assert_eq(component.collision_layer_mask, 1)

func _find_component(controller: Node) -> C_DamageZoneComponent:
	for child in controller.get_children():
		if child is C_DamageZoneComponent:
			return child as C_DamageZoneComponent
	return null
