extends BaseTest

const INTER_CHARACTER_LIGHT_ZONE := preload("res://scripts/gameplay/inter_character_light_zone.gd")
const RS_CHARACTER_LIGHT_ZONE_CONFIG := preload("res://scripts/resources/lighting/rs_character_light_zone_config.gd")
const RS_CHARACTER_LIGHTING_PROFILE := preload("res://scripts/resources/lighting/rs_character_lighting_profile.gd")

class FakeSceneManager extends "res://scripts/interfaces/i_scene_manager.gd":
	var transitioning: bool = false

	func is_transitioning() -> bool:
		return transitioning

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _find_collision_shape(area: Area3D) -> CollisionShape3D:
	for child in area.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null

func _create_controller(config: RS_CharacterLightZoneConfig, preauthored_area: Area3D = null) -> Inter_CharacterLightZone:
	var controller := INTER_CHARACTER_LIGHT_ZONE.new()
	controller.name = "Inter_TestCharacterLightZone"
	if preauthored_area != null:
		preauthored_area.name = "PreauthoredArea"
		controller.add_child(preauthored_area)
		controller.area_path = controller.get_path_to(preauthored_area)
	controller.config = config
	add_child(controller)
	autofree(controller)
	await _pump_frames(2)
	return controller

func test_applies_config_to_volume_and_computes_position_based_weight() -> void:
	var config := RS_CHARACTER_LIGHT_ZONE_CONFIG.new()
	config.shape_type = RS_CharacterLightZoneConfig.ShapeType.BOX
	config.box_size = Vector3(4.0, 4.0, 4.0)
	config.local_offset = Vector3.ZERO
	config.blend_weight = 0.8
	config.falloff = 0.25

	var controller := await _create_controller(config)
	var area: Area3D = controller.get_trigger_area()
	var shape: CollisionShape3D = _find_collision_shape(area)

	assert_not_null(area, "Controller should create a trigger area from BaseVolumeController.")
	assert_not_null(shape, "Controller should ensure trigger area includes a collision shape.")
	assert_true(shape.shape is BoxShape3D, "BOX config should map to a BoxShape3D.")
	assert_eq((shape.shape as BoxShape3D).size, Vector3(4.0, 4.0, 4.0))

	var center_weight: float = controller.get_influence_weight(Vector3.ZERO)
	var edge_weight: float = controller.get_influence_weight(Vector3(1.9, 0.0, 0.0))
	var outside_weight: float = controller.get_influence_weight(Vector3(2.1, 0.0, 0.0))

	assert_almost_eq(center_weight, 0.8, 0.0001, "Center point should use full blend weight.")
	assert_true(edge_weight > 0.0 and edge_weight < center_weight,
		"Near-edge points should fade based on falloff.")
	assert_almost_eq(outside_weight, 0.0, 0.0001, "Outside the zone should return zero influence.")

func test_adopts_preauthored_area_and_ensures_runtime_settings_are_scene_local() -> void:
	var preauthored_area := Area3D.new()

	var config := RS_CHARACTER_LIGHT_ZONE_CONFIG.new()
	config.shape_type = RS_CharacterLightZoneConfig.ShapeType.CYLINDER
	config.cylinder_radius = 3.0
	config.cylinder_height = 6.0
	config.local_offset = Vector3(0.0, 1.0, 0.0)

	var controller := await _create_controller(config, preauthored_area)
	var resolved_area: Area3D = controller.get_trigger_area()
	var shape: CollisionShape3D = _find_collision_shape(resolved_area)

	assert_true(resolved_area == preauthored_area, "Controller should adopt preauthored area when area_path is set.")
	assert_not_null(controller.settings, "Controller should generate runtime trigger settings from lighting config.")
	assert_true(controller.settings.resource_local_to_scene,
		"Runtime settings should be scene-local to avoid shared mutable resource state.")
	assert_true(shape.shape is CylinderShape3D, "CYLINDER config should map to a CylinderShape3D.")
	assert_almost_eq((shape.shape as CylinderShape3D).radius, 3.0, 0.0001)
	assert_almost_eq((shape.shape as CylinderShape3D).height, 6.0, 0.0001)

func test_transition_blocking_returns_zero_influence_until_transition_ends() -> void:
	var fake_scene_manager := FakeSceneManager.new()
	add_child(fake_scene_manager)
	autofree(fake_scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), fake_scene_manager)

	var config := RS_CHARACTER_LIGHT_ZONE_CONFIG.new()
	config.shape_type = RS_CharacterLightZoneConfig.ShapeType.BOX
	config.box_size = Vector3(4.0, 4.0, 4.0)
	config.blend_weight = 1.0

	var controller := await _create_controller(config)

	fake_scene_manager.transitioning = true
	assert_almost_eq(controller.get_influence_weight(Vector3.ZERO), 0.0, 0.0001,
		"Zone influence should be blocked while scene transitions are active.")

	fake_scene_manager.transitioning = false
	assert_true(controller.get_influence_weight(Vector3.ZERO) > 0.0,
		"Zone influence should resume after transitions complete.")

func test_zone_metadata_returns_stable_deep_copied_profile_snapshot() -> void:
	var profile := RS_CHARACTER_LIGHTING_PROFILE.new()
	profile.tint = Color(0.3, 0.4, 0.5, 1.0)
	profile.intensity = 2.5
	profile.blend_smoothing = 0.2

	var config := RS_CHARACTER_LIGHT_ZONE_CONFIG.new()
	config.zone_id = StringName("zone_test")
	config.priority = 7
	config.profile = profile

	var controller := await _create_controller(config)
	var metadata_first: Dictionary = controller.get_zone_metadata()
	var profile_first: Dictionary = metadata_first.get("profile", {})

	assert_eq(metadata_first.get("zone_id", StringName("")), StringName("zone_test"))
	assert_eq(metadata_first.get("node_name", StringName("")), StringName("Inter_TestCharacterLightZone"))
	assert_eq(int(metadata_first.get("priority", -1)), 7)
	assert_almost_eq(float(profile_first.get("intensity", -1.0)), 2.5, 0.0001)

	profile_first["intensity"] = 0.0
	var metadata_second: Dictionary = controller.get_zone_metadata()
	var profile_second: Dictionary = metadata_second.get("profile", {})

	assert_almost_eq(float(profile_second.get("intensity", -1.0)), 2.5, 0.0001,
		"Metadata profile snapshot should be deep-copied per call.")
	assert_eq(String(metadata_first.get("stable_key", "")), String(metadata_second.get("stable_key", "")),
		"Stable metadata key should remain deterministic across calls.")
