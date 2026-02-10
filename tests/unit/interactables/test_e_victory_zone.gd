extends BaseTest

const RS_VICTORY_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_victory_interaction_config.gd")
const RS_HAZARD_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_hazard_interaction_config.gd")
const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/resources/ecs/rs_scene_trigger_settings.gd")

class TestVictoryComponent:
	extends C_VictoryTriggerComponent

	var resolve_called: bool = false

	func _resolve_area() -> void:
		resolve_called = true
		super._resolve_area()

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_controller() -> Inter_VictoryZone:
	var controller := Inter_VictoryZone.new()
	controller.component_factory = Callable(self, "_create_victory_stub")
	controller.objective_id = StringName("objective_test")
	controller.area_id = "area_test"
	controller.victory_type = C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE
	controller.trigger_once = false
	add_child(controller)
	autofree(controller)
	await _pump_frames(3)
	return controller

func _create_victory_stub() -> TestVictoryComponent:
	return TestVictoryComponent.new()

func test_victory_component_configured() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller) as TestVictoryComponent
	assert_not_null(component, "Victory controller should create component.")

	assert_eq(component.objective_id, StringName("objective_test"))
	assert_eq(component.area_id, "area_test")
	assert_eq(component.victory_type, C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE)
	assert_false(component.trigger_once, "Trigger once flag should reflect controller export.")
	assert_true(component.resolve_called, "Component should resolve area using controller volume.")

	var area := controller.get_trigger_area()
	assert_not_null(area)
	assert_true(component.get_trigger_area() == area, "Component should reuse controller area.")

func test_config_resource_overrides_export_values() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)
	assert_not_null(component, "Victory component should exist before config assignment.")

	var config := RS_VICTORY_INTERACTION_CONFIG.new()
	config.objective_id = StringName("objective_cfg")
	config.area_id = "area_cfg"
	config.victory_type = C_VictoryTriggerComponent.VictoryType.LEVEL_COMPLETE
	config.trigger_once = true
	var trigger_settings := RS_SCENE_TRIGGER_SETTINGS.new()
	trigger_settings.ignore_initial_overlap = true
	config.trigger_settings = trigger_settings

	controller.config = config
	await _pump_frames(1)

	assert_eq(component.objective_id, StringName("objective_cfg"))
	assert_eq(component.area_id, "area_cfg")
	assert_eq(component.victory_type, C_VictoryTriggerComponent.VictoryType.LEVEL_COMPLETE)
	assert_true(component.trigger_once)
	assert_true(controller.settings == trigger_settings, "Victory should use config trigger settings when provided.")
	assert_false(trigger_settings.ignore_initial_overlap, "Victory should force passive overlap semantics.")

func test_non_matching_config_uses_export_fallback() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)
	assert_not_null(component, "Victory component should exist before fallback check.")

	var wrong_config := RS_HAZARD_INTERACTION_CONFIG.new()
	controller.config = wrong_config
	await _pump_frames(1)

	assert_eq(component.objective_id, StringName("objective_test"))
	assert_eq(component.area_id, "area_test")
	assert_eq(component.victory_type, C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE)
	assert_false(component.trigger_once)

func _find_component(controller: Node) -> C_VictoryTriggerComponent:
	for child in controller.get_children():
		if child is C_VictoryTriggerComponent:
			return child as C_VictoryTriggerComponent
	return null
