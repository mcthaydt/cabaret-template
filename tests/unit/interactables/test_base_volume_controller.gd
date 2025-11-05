extends BaseTest

const BASE_VOLUME_CONTROLLER := preload("res://scripts/gameplay/base_volume_controller.gd")
const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/ecs/resources/rs_scene_trigger_settings.gd")

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_controller(settings: RS_SceneTriggerSettings = null) -> Node3D:
	var controller := BASE_VOLUME_CONTROLLER.new()
	if settings != null:
		controller.settings = settings
	add_child(controller)
	autofree(controller)
	await _pump_frames(2)
	return controller

func _create_visual(controller: Node) -> Node3D:
	var visual := Node3D.new()
	visual.name = "Visual"
	controller.add_child(visual)
	return visual

func _find_collision_shape(area: Area3D) -> CollisionShape3D:
	for child in area.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null

func test_creates_trigger_area_when_missing() -> void:
	var controller := await _create_controller()
	var area: Area3D = controller.get_trigger_area()

	assert_not_null(area, "BaseVolumeController should create an Area3D when none is provided.")
	assert_true(area.monitoring, "Area3D should default to monitoring so overlaps are detected.")
	assert_true(area.monitorable, "Area3D should default to monitorable so bodies can detect it.")

	var shape: CollisionShape3D = _find_collision_shape(area)
	assert_not_null(shape, "CollisionShape3D should be created under the Area3D.")
	assert_true(shape.shape is CylinderShape3D, "Default settings should create a cylinder trigger volume.")

func test_set_enabled_toggles_area_and_visuals() -> void:
	var controller := BASE_VOLUME_CONTROLLER.new()
	var visual: Node3D = _create_visual(controller)
	controller.visual_paths = [controller.get_path_to(visual)]
	add_child(controller)
	autofree(controller)
	await _pump_frames(2)

	var area: Area3D = controller.get_trigger_area()
	assert_not_null(area, "Area should exist after controller initializes.")

	controller.set_enabled(false)
	await _pump_frames()

	assert_false(area.monitoring, "Disabling should stop monitoring on the Area3D.")
	assert_false(area.monitorable, "Disabling should stop bodies from monitoring the Area3D.")
	assert_false(visual.visible, "Disabling should hide linked visuals by default.")

	controller.set_enabled(true)
	await _pump_frames()

	assert_true(area.monitoring, "Re-enabling should resume monitoring on the Area3D.")
	assert_true(area.monitorable, "Re-enabling should restore monitorable on the Area3D.")
	assert_true(visual.visible, "Re-enabling should show linked visuals again.")

func test_applies_settings_to_collision_geometry() -> void:
	var settings := RS_SCENE_TRIGGER_SETTINGS.new()
	settings.shape_type = RS_SCENE_TRIGGER_SETTINGS.ShapeType.BOX
	settings.box_size = Vector3(4.0, 2.0, 1.0)
	settings.local_offset = Vector3(0.5, 1.0, -0.5)
	settings.player_mask = 4

	var controller := await _create_controller(settings)
	var area: Area3D = controller.get_trigger_area()
	var shape: CollisionShape3D = _find_collision_shape(area)

	assert_not_null(area, "Area should exist when settings are provided.")
	assert_not_null(shape, "CollisionShape3D should be created using provided settings.")
	assert_true(shape.shape is BoxShape3D, "Box mode should create a BoxShape3D.")
	assert_eq((shape.shape as BoxShape3D).size, settings.box_size, "Box size should match settings.")
	assert_eq(shape.position, settings.local_offset, "Collision shape position should use settings offset.")
	assert_eq(area.collision_mask, settings.player_mask, "Area mask should match the configured player mask.")

func test_reuses_existing_area_when_path_provided() -> void:
	var controller := BASE_VOLUME_CONTROLLER.new()
	var area := Area3D.new()
	area.name = "PreauthoredArea"
	controller.add_child(area)
	controller.area_path = controller.get_path_to(area)

	add_child(controller)
	autofree(controller)
	await _pump_frames(2)

	var resolved_area: Area3D = controller.get_trigger_area()
	assert_true(resolved_area == area, "Controller should reuse the authored Area3D when a path is supplied.")

	var shape: CollisionShape3D = _find_collision_shape(resolved_area)
	assert_not_null(shape, "Controller should ensure the authored Area3D has a CollisionShape3D.")
