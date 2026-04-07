extends BaseTest

const ROOM_FADE_SYSTEM_PATH := "res://scripts/ecs/systems/s_room_fade_system.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_ROOM_FADE_GROUP_COMPONENT := preload("res://scripts/ecs/components/c_room_fade_group_component.gd")
const RS_ROOM_FADE_SETTINGS := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")

func _room_fade_system_script() -> Script:
	var script_obj := load(ROOM_FADE_SYSTEM_PATH) as Script
	assert_not_null(script_obj, "Room fade system should load: %s" % ROOM_FADE_SYSTEM_PATH)
	return script_obj

func test_orbit_only_gating_enables_room_fade_only_in_orbit_mode() -> void:
	var fixture := _create_fixture("custom_mode")
	var system = fixture.get("system")
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(store)
	assert_not_null(ecs_manager)

	var setup := _register_mesh_group(ecs_manager, "E_RoomFadeOrbitGate", Vector3(0.0, 0.0, -1.0))
	var component = setup.get("component")
	var target: MeshInstance3D = setup.get("target") as MeshInstance3D
	assert_not_null(component)
	assert_not_null(target)

	component.current_alpha = 0.35
	system.process_tick(0.1)
	assert_eq(component.current_alpha, 1.0, "first-person mode should keep room fade disabled.")
	assert_false(target.material_override is ShaderMaterial, "Non-orbit mode should not apply room-fade shader.")

	store.set_slice("vcam", {"active_mode": "fixed"})
	component.current_alpha = 0.65
	system.process_tick(0.1)
	assert_eq(component.current_alpha, 1.0, "fixed mode should keep room fade disabled.")
	assert_false(target.material_override is ShaderMaterial, "Fixed mode should not apply room-fade shader.")

	store.set_slice("vcam", {"active_mode": "orbit"})
	component.current_alpha = 1.0
	system.process_tick(0.1)
	assert_lt(component.current_alpha, 1.0, "Orbit mode should apply room fade when threshold is met.")
	var fade_material := target.material_override as ShaderMaterial
	assert_not_null(fade_material, "Orbit mode should apply a room-fade shader material override.")

func test_multi_group_independence_fades_each_group_from_its_own_normal() -> void:
	var fixture := _create_fixture("orbit")
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(ecs_manager)

	var settings := _make_settings(0.2, 100.0, 0.05)
	var front_setup := _register_mesh_group(
		ecs_manager,
		"E_RoomFadeFront",
		Vector3(0.0, 0.0, -1.0),
		settings
	)
	# Perpendicular normal: abs(dot) ≈ 0 < threshold → stays opaque.
	var side_setup := _register_mesh_group(
		ecs_manager,
		"E_RoomFadeSide",
		Vector3(1.0, 0.0, 0.0),
		settings
	)
	var front_component = front_setup.get("component")
	var side_component = side_setup.get("component")
	assert_not_null(front_component)
	assert_not_null(side_component)

	system.process_tick(0.1)

	assert_almost_eq(float(front_component.current_alpha), 0.05, 0.0001)
	assert_almost_eq(float(side_component.current_alpha), 1.0, 0.0001)

func test_ceiling_group_with_downward_normal_fades_when_camera_forward_points_downward() -> void:
	var fixture := _create_fixture("orbit")
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var camera: Camera3D = fixture.get("main_camera") as Camera3D
	assert_not_null(system)
	assert_not_null(ecs_manager)
	assert_not_null(camera)

	_set_camera_forward(camera, Vector3(0.0, -1.0, 0.0), Vector3.FORWARD)

	var settings := _make_settings(0.2, 100.0, 0.1)
	var setup := _register_mesh_group(
		ecs_manager,
		"E_RoomFadeCeiling",
		Vector3(0.0, -1.0, 0.0),
		settings
	)
	var component = setup.get("component")
	assert_not_null(component)

	system.process_tick(0.1)

	assert_almost_eq(float(component.current_alpha), 0.1, 0.0001)

func test_mode_switch_cleanup_restores_all_groups_to_opaque_within_one_tick() -> void:
	var fixture := _create_fixture("orbit")
	var system = fixture.get("system")
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(store)
	assert_not_null(ecs_manager)

	var settings := _make_settings(0.2, 100.0, 0.05)
	var setup_a := _register_mesh_group(ecs_manager, "E_RoomFadeModeSwitchA", Vector3(0.0, 0.0, -1.0), settings)
	var setup_b := _register_mesh_group(ecs_manager, "E_RoomFadeModeSwitchB", Vector3(0.0, 0.0, -1.0), settings)
	var component_a = setup_a.get("component")
	var component_b = setup_b.get("component")
	var target_a: MeshInstance3D = setup_a.get("target") as MeshInstance3D
	var target_b: MeshInstance3D = setup_b.get("target") as MeshInstance3D
	assert_not_null(component_a)
	assert_not_null(component_b)
	assert_not_null(target_a)
	assert_not_null(target_b)

	system.process_tick(0.1)
	assert_lt(float(component_a.current_alpha), 1.0)
	assert_lt(float(component_b.current_alpha), 1.0)
	assert_true(target_a.material_override is ShaderMaterial)
	assert_true(target_b.material_override is ShaderMaterial)

	store.set_slice("vcam", {"active_mode": "custom_mode"})
	system.process_tick(0.1)

	assert_eq(component_a.current_alpha, 1.0)
	assert_eq(component_b.current_alpha, 1.0)
	assert_null(target_a.material_override)
	assert_null(target_b.material_override)

func test_room_fade_restores_existing_silhouette_like_shader_override_without_conflict() -> void:
	var fixture := _create_fixture("orbit")
	var system = fixture.get("system")
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(store)
	assert_not_null(ecs_manager)

	var silhouette_shader := Shader.new()
	silhouette_shader.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment(){ ALBEDO = vec3(1.0, 0.0, 1.0); }\n"
	var silhouette_material := ShaderMaterial.new()
	silhouette_material.shader = silhouette_shader

	var settings := _make_settings(0.2, 100.0, 0.05)
	var setup := _register_mesh_group(
		ecs_manager,
		"E_RoomFadeSilhouetteCoexist",
		Vector3(0.0, 0.0, -1.0),
		settings,
		silhouette_material
	)
	var target: MeshInstance3D = setup.get("target") as MeshInstance3D
	assert_not_null(target)
	assert_eq(target.material_override, silhouette_material)

	system.process_tick(0.1)
	assert_true(target.material_override is ShaderMaterial)
	assert_ne(target.material_override, silhouette_material, "Room fade should temporarily replace the silhouette override.")

	store.set_slice("vcam", {"active_mode": "custom_mode"})
	system.process_tick(0.1)
	assert_eq(target.material_override, silhouette_material, "Mode switch restore should recover the original silhouette material.")

func test_per_group_settings_override_and_default_settings_are_applied_independently() -> void:
	var fixture := _create_fixture("orbit")
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(ecs_manager)

	var custom_settings := _make_settings(0.2, 8.0, 0.1)
	var custom_setup := _register_mesh_group(
		ecs_manager,
		"E_RoomFadeCustomSettings",
		Vector3(0.0, 0.0, -1.0),
		custom_settings
	)
	var default_setup := _register_mesh_group(
		ecs_manager,
		"E_RoomFadeDefaultSettings",
		Vector3(0.0, 0.0, -1.0),
		null
	)
	var custom_component = custom_setup.get("component")
	var default_component = default_setup.get("component")
	assert_not_null(custom_component)
	assert_not_null(default_component)

	system.process_tick(0.1)

	assert_almost_eq(float(custom_component.current_alpha), 0.2, 0.0001)
	assert_almost_eq(float(default_component.current_alpha), 0.6, 0.0001)

func test_material_restoration_completeness_recovers_mesh_and_csg_original_materials() -> void:
	var fixture := _create_fixture("orbit")
	var system = fixture.get("system")
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(store)
	assert_not_null(ecs_manager)

	var mesh_original_override := StandardMaterial3D.new()
	mesh_original_override.albedo_color = Color(0.1, 0.8, 0.9, 1.0)
	var csg_original_material := StandardMaterial3D.new()
	csg_original_material.albedo_color = Color(0.8, 0.4, 0.2, 1.0)

	var settings := _make_settings(0.2, 100.0, 0.05)
	var mesh_setup := _register_mesh_group(
		ecs_manager,
		"E_RoomFadeRestoreMesh",
		Vector3(0.0, 0.0, -1.0),
		settings,
		mesh_original_override
	)
	var csg_setup := _register_csg_group(
		ecs_manager,
		"E_RoomFadeRestoreCSG",
		Vector3(0.0, 0.0, -1.0),
		settings,
		csg_original_material
	)
	var mesh_component = mesh_setup.get("component")
	var csg_component = csg_setup.get("component")
	var mesh_target: MeshInstance3D = mesh_setup.get("target") as MeshInstance3D
	var csg_target: CSGBox3D = csg_setup.get("target") as CSGBox3D
	assert_not_null(mesh_component)
	assert_not_null(csg_component)
	assert_not_null(mesh_target)
	assert_not_null(csg_target)

	system.process_tick(0.1)
	assert_true(mesh_target.material_override is ShaderMaterial)
	assert_true(csg_target.material is ShaderMaterial)
	assert_lt(float(mesh_component.current_alpha), 1.0)
	assert_lt(float(csg_component.current_alpha), 1.0)

	store.set_slice("vcam", {"active_mode": "custom_mode"})
	system.process_tick(0.1)

	assert_eq(mesh_component.current_alpha, 1.0)
	assert_eq(csg_component.current_alpha, 1.0)
	assert_eq(mesh_target.material_override, mesh_original_override)
	assert_eq(csg_target.material, csg_original_material)

func _create_fixture(active_mode: String) -> Dictionary:
	var room_fade_system_script := _room_fade_system_script()
	if room_fade_system_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	autofree(camera_manager)
	var main_camera := Camera3D.new()
	main_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	main_camera.current = true
	add_child(main_camera)
	autofree(main_camera)
	camera_manager.main_camera = main_camera

	var state_store := MOCK_STATE_STORE.new()
	autofree(state_store)
	state_store.set_slice("vcam", {"active_mode": active_mode})

	var system: Variant = room_fade_system_script.new()
	autofree(system)
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.state_store = state_store
	add_child(system)
	system.configure(ecs_manager)

	return {
		"system": system,
		"ecs_manager": ecs_manager,
		"camera_manager": camera_manager,
		"main_camera": main_camera,
		"state_store": state_store,
	}

func _register_mesh_group(
	ecs_manager: MockECSManager,
	entity_name: String,
	fade_normal: Vector3,
	settings: Resource = null,
	override_material: Material = null
) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	component.fade_normal = fade_normal
	component.settings = settings
	component.current_alpha = 1.0
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var mesh := BoxMesh.new()
	var mesh_target := MeshInstance3D.new()
	mesh_target.mesh = mesh
	mesh_target.material_override = override_material
	entity.add_child(mesh_target)
	autofree(mesh_target)

	return {
		"entity": entity,
		"component": component,
		"target": mesh_target,
	}

func _register_csg_group(
	ecs_manager: MockECSManager,
	entity_name: String,
	fade_normal: Vector3,
	settings: Resource = null,
	target_material: Material = null
) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	component.fade_normal = fade_normal
	component.settings = settings
	component.current_alpha = 1.0
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var csg_target := CSGBox3D.new()
	csg_target.material = target_material
	entity.add_child(csg_target)
	autofree(csg_target)

	return {
		"entity": entity,
		"component": component,
		"target": csg_target,
	}

func _make_settings(threshold: float, fade_speed: float, min_alpha: float) -> RS_RoomFadeSettings:
	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = threshold
	settings.fade_speed = fade_speed
	settings.min_alpha = min_alpha
	return settings

func _set_camera_forward(camera: Camera3D, forward: Vector3, up: Vector3) -> void:
	var normalized_forward := forward.normalized()
	var origin: Vector3 = camera.global_transform.origin
	var target: Vector3 = origin + normalized_forward
	var base_transform := Transform3D(Basis.IDENTITY, origin)
	camera.global_transform = base_transform.looking_at(target, up.normalized())
