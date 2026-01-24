extends BaseTest

const Inter_CheckpointZone := preload("res://scripts/gameplay/inter_checkpoint_zone.gd")
const C_CheckpointComponent := preload("res://scripts/ecs/components/c_checkpoint_component.gd")

class TestCheckpointComponent:
	extends C_CheckpointComponent

	var resolve_called: bool = false

	func _resolve_or_create_area() -> void:
		resolve_called = true
		super._resolve_or_create_area()

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_controller() -> Inter_CheckpointZone:
	var controller := Inter_CheckpointZone.new()
	controller.component_factory = Callable(self, "_create_checkpoint_stub")
	controller.checkpoint_id = StringName("cp_test")
	controller.spawn_point_id = StringName("sp_test")
	add_child(controller)
	autofree(controller)
	await _pump_frames(3)
	return controller

func _create_checkpoint_stub() -> TestCheckpointComponent:
	return TestCheckpointComponent.new()

func test_checkpoint_component_configured() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller) as TestCheckpointComponent
	assert_not_null(component, "Checkpoint controller should instantiate a component.")

	assert_eq(component.checkpoint_id, StringName("cp_test"))
	assert_eq(component.spawn_point_id, StringName("sp_test"))
	assert_true(component.resolve_called, "Component should resolve area using controller-provided trigger.")

	var area := controller.get_trigger_area()
	assert_not_null(area, "Controller should expose area.")
	assert_true(component.get_trigger_area() == area, "Component should reuse controller area.")

func _find_component(controller: Node) -> C_CheckpointComponent:
	for child in controller.get_children():
		if child is C_CheckpointComponent:
			return child as C_CheckpointComponent
	return null
