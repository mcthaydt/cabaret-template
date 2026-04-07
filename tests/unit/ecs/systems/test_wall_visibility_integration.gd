extends BaseTest

const WALL_VISIBILITY_SYSTEM_PATH := "res://scripts/ecs/systems/s_wall_visibility_system.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_ROOM_FADE_GROUP_COMPONENT := preload("res://scripts/ecs/components/c_room_fade_group_component.gd")
const U_WALL_VISIBILITY_MATERIAL_APPLIER := preload("res://scripts/utils/lighting/u_wall_visibility_material_applier.gd")
const RS_ROOM_FADE_SETTINGS := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")


func _wall_visibility_system_script() -> Script:
	var script_obj := load(WALL_VISIBILITY_SYSTEM_PATH) as Script
	assert_not_null(script_obj, "Wall visibility system should load: %s" % WALL_VISIBILITY_SYSTEM_PATH)
	return script_obj


# --- Integration tests with real material applier ---

func test_orbit_mode_applies_shader_material_to_mesh_target() -> void:
	var system_script := _wall_visibility_system_script()
	if system_script == null:
		return

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
	state_store.set_slice("vcam", {"active_mode": "orbit"})

	var applier := U_WALL_VISIBILITY_MATERIAL_APPLIER.new()

	var system: Variant = system_script.new()
	autofree(system)
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.state_store = state_store
	system.material_applier = applier
	add_child(system)
	system.configure(ecs_manager)

	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_WallVisIntegration"
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	entity.add_child(mesh_instance)
	autofree(mesh_instance)

	var original_override: Material = mesh_instance.material_override

	system.process_tick(0.1)

	assert_not_null(mesh_instance.material_override,
		"Shader material should be applied to mesh target.")
	if mesh_instance.material_override != null:
		assert_ne(mesh_instance.material_override, original_override,
			"Material should be replaced with shader material.")
		assert_true(applier.is_applied(mesh_instance),
			"Target should be tracked by applier.")


func test_orbit_mode_applies_shader_to_csg_target() -> void:
	var system_script := _wall_visibility_system_script()
	if system_script == null:
		return

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
	state_store.set_slice("vcam", {"active_mode": "orbit"})

	var applier := U_WALL_VISIBILITY_MATERIAL_APPLIER.new()

	var system: Variant = system_script.new()
	autofree(system)
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.state_store = state_store
	system.material_applier = applier
	add_child(system)
	system.configure(ecs_manager)

	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_WallVisCSGIntegration"
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var csg_shape := CSGBox3D.new()
	entity.add_child(csg_shape)
	autofree(csg_shape)

	var original_material: Material = csg_shape.material

	system.process_tick(0.1)

	assert_not_null(csg_shape.material,
		"Shader material should be applied to CSG target.")
	if csg_shape.material != null:
		assert_ne(csg_shape.material, original_material,
			"CSG material should be replaced with shader material.")


func test_non_orbit_mode_restores_original_materials() -> void:
	var system_script := _wall_visibility_system_script()
	if system_script == null:
		return

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
	state_store.set_slice("vcam", {"active_mode": "orbit"})

	var applier := U_WALL_VISIBILITY_MATERIAL_APPLIER.new()

	var system: Variant = system_script.new()
	autofree(system)
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.state_store = state_store
	system.material_applier = applier
	add_child(system)
	system.configure(ecs_manager)

	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_WallVisRestore"
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var original := StandardMaterial3D.new()
	mesh_instance.material_override = original
	entity.add_child(mesh_instance)
	autofree(mesh_instance)

	system.process_tick(0.1)
	assert_ne(mesh_instance.material_override, original, "Should have shader material in orbit mode.")

	state_store.set_slice("vcam", {"active_mode": "custom"})
	system.process_tick(0.1)

	assert_eq(mesh_instance.material_override, original,
		"Should restore original material when leaving orbit mode.")


func test_mesh_and_csg_materials_restored_on_exit() -> void:
	var system_script := _wall_visibility_system_script()
	if system_script == null:
		return

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
	state_store.set_slice("vcam", {"active_mode": "orbit"})

	var applier := U_WALL_VISIBILITY_MATERIAL_APPLIER.new()

	var system: Variant = system_script.new()
	autofree(system)
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.state_store = state_store
	system.material_applier = applier
	add_child(system)
	system.configure(ecs_manager)

	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_WallVisMixedTargets"
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var mesh_original := StandardMaterial3D.new()
	mesh_instance.material_override = mesh_original
	entity.add_child(mesh_instance)
	autofree(mesh_instance)

	var csg_shape := CSGBox3D.new()
	var csg_original := StandardMaterial3D.new()
	csg_shape.material = csg_original
	entity.add_child(csg_shape)
	autofree(csg_shape)

	system.process_tick(0.1)

	assert_ne(mesh_instance.material_override, mesh_original, "Mesh should have shader material.")
	assert_ne(csg_shape.material, csg_original, "CSG should have shader material.")

	state_store.set_slice("vcam", {"active_mode": "custom"})
	system.process_tick(0.1)

	assert_eq(mesh_instance.material_override, mesh_original,
		"Mesh original material should be restored.")
	assert_eq(csg_shape.material, csg_original,
		"CSG original material should be restored.")