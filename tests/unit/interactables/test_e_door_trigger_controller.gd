extends BaseTest

const E_DoorTriggerController := preload("res://scripts/gameplay/e_door_trigger_controller.gd")
const C_SceneTriggerComponent := preload("res://scripts/ecs/components/c_scene_trigger_component.gd")

class TestSceneTriggerComponent:
	extends C_SceneTriggerComponent

	var trigger_called: bool = false

	func trigger_interact() -> void:
		trigger_called = true
		super.trigger_interact()

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_controller() -> E_DoorTriggerController:
	var controller := E_DoorTriggerController.new()
	controller.component_factory = Callable(self, "_create_scene_trigger_stub")
	controller.door_id = StringName("door_test")
	controller.target_scene_id = StringName("scene_test")
	controller.target_spawn_point = StringName("spawn_test")
	add_child(controller)
	autofree(controller)
	await _pump_frames(3)
	return controller

func _create_scene_trigger_stub() -> TestSceneTriggerComponent:
	return TestSceneTriggerComponent.new()

func test_creates_component_and_links_area() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)

	assert_not_null(component, "Door controller should instantiate a scene trigger component.")

	assert_eq(component.door_id, StringName("door_test"))
	assert_eq(component.target_scene_id, StringName("scene_test"))
	assert_eq(component.target_spawn_point, StringName("spawn_test"))

	assert_eq(component.trigger_mode, C_SceneTriggerComponent.TriggerMode.INTERACT, "Component should run in INTERACT mode under controller supervision.")

	var area := controller.get_trigger_area()
	assert_not_null(area, "Controller should expose the trigger Area3D.")
	assert_true(component._trigger_area == area, "Component should reuse controller-managed trigger area.")

func test_activation_calls_component_trigger() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller) as TestSceneTriggerComponent
	assert_not_null(component, "Stub component expected for activation test.")

	component.trigger_called = false
	var dummy_player := _make_dummy_player()
	controller._on_activated(dummy_player)
	assert_true(component.trigger_called, "Activated door should delegate to component.trigger_interact().")

func _find_component(controller: Node) -> C_SceneTriggerComponent:
	for child in controller.get_children():
		if child is C_SceneTriggerComponent:
			return child as C_SceneTriggerComponent
	return null

func _make_dummy_player() -> Node3D:
	var node := Node3D.new()
	add_child(node)
	autofree(node)
	return node
