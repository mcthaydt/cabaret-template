extends BaseTest

const E_VictoryZone := preload("res://scripts/gameplay/e_victory_zone.gd")
const C_VictoryTriggerComponent := preload("res://scripts/ecs/components/c_victory_trigger_component.gd")

class TestVictoryComponent:
	extends C_VictoryTriggerComponent

	var resolve_called: bool = false

	func _resolve_area() -> void:
		resolve_called = true
		super._resolve_area()

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_controller() -> E_VictoryZone:
	var controller := E_VictoryZone.new()
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

func _find_component(controller: Node) -> C_VictoryTriggerComponent:
	for child in controller.get_children():
		if child is C_VictoryTriggerComponent:
			return child as C_VictoryTriggerComponent
	return null
