extends BaseTest

const RS_CHECKPOINT_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_checkpoint_interaction_config.gd")
const RS_DOOR_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_door_interaction_config.gd")
const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/resources/ecs/rs_scene_trigger_settings.gd")

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

func test_config_resource_overrides_export_values() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)
	assert_not_null(component, "Checkpoint component should exist before config assignment.")

	var config := RS_CHECKPOINT_INTERACTION_CONFIG.new()
	config.checkpoint_id = StringName("cp_cfg")
	config.spawn_point_id = StringName("sp_cfg")
	var trigger_settings := RS_SCENE_TRIGGER_SETTINGS.new()
	trigger_settings.player_mask = 4
	trigger_settings.ignore_initial_overlap = true
	config.trigger_settings = trigger_settings

	controller.config = config
	await _pump_frames(1)

	assert_eq(component.checkpoint_id, StringName("cp_cfg"))
	assert_eq(component.spawn_point_id, StringName("sp_cfg"))
	assert_true(component.settings == trigger_settings, "Checkpoint should use config trigger settings when provided.")
	assert_false(component.settings.ignore_initial_overlap, "Checkpoint should force passive overlap semantics.")

func test_non_matching_config_uses_export_fallback() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)
	assert_not_null(component, "Checkpoint component should exist before fallback check.")

	var wrong_config := RS_DOOR_INTERACTION_CONFIG.new()
	controller.config = wrong_config
	await _pump_frames(1)

	assert_eq(component.checkpoint_id, StringName("cp_test"))
	assert_eq(component.spawn_point_id, StringName("sp_test"))

func _find_component(controller: Node) -> C_CheckpointComponent:
	for child in controller.get_children():
		if child is C_CheckpointComponent:
			return child as C_CheckpointComponent
	return null
