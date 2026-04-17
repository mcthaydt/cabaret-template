extends BaseTest

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BOOT_INITIAL_STATE := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MENU_INITIAL_STATE := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const RS_SETTINGS_INITIAL_STATE := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_DEBUG_INITIAL_STATE := preload("res://scripts/resources/state/rs_debug_initial_state.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/resources/state/rs_audio_initial_state.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_display_initial_state.gd")

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_VCAM_SELECTORS := preload("res://scripts/state/selectors/u_vcam_selectors.gd")
const U_VCAM_SILHOUETTE_HELPER := preload("res://scripts/managers/helpers/u_vcam_silhouette_helper.gd")

const M_VCAM_MANAGER := preload("res://scripts/managers/m_vcam_manager.gd")
const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()

func after_each() -> void:
	U_STATE_HANDOFF.clear_all()
	super.after_each()

func test_mesh_occluder_receives_runtime_silhouette_update() -> void:
	var fixture := await _create_occlusion_fixture()
	autofree_context(fixture)
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var vfx_manager: M_VFXManager = fixture["vfx_manager"] as M_VFXManager
	var follow_target: Node3D = fixture["follow_target"] as Node3D
	var mesh: MeshInstance3D = fixture["occluder_mesh"] as MeshInstance3D
	var store: M_StateStore = fixture["store"] as M_StateStore

	_tick_occlusion_frame(manager, vfx_manager, follow_target, Vector3(0.0, 1.0, 5.0))
	_tick_occlusion_frame(manager, vfx_manager, follow_target, Vector3(0.0, 1.0, 5.0))

	assert_almost_eq(
		mesh.transparency,
		U_VCAM_SILHOUETTE_HELPER.DEFAULT_SILHOUETTE_TRANSPARENCY,
		0.001,
		"Second stable frame should apply silhouette transparency to occluding mesh"
	)
	assert_eq(
		U_VCAM_SELECTORS.get_silhouette_active_count(store.get_state()),
		1,
		"Rendered silhouette count should be reflected in vcam observability slice"
	)

func test_silhouette_clears_after_scene_swap_style_vcam_teardown() -> void:
	var fixture := await _create_occlusion_fixture()
	autofree_context(fixture)
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var vfx_manager: M_VFXManager = fixture["vfx_manager"] as M_VFXManager
	var follow_target: Node3D = fixture["follow_target"] as Node3D
	var component: C_VCamComponent = fixture["vcam_component"] as C_VCamComponent
	var mesh: MeshInstance3D = fixture["occluder_mesh"] as MeshInstance3D
	var store: M_StateStore = fixture["store"] as M_StateStore

	_tick_occlusion_frame(manager, vfx_manager, follow_target, Vector3(0.0, 1.0, 5.0))
	_tick_occlusion_frame(manager, vfx_manager, follow_target, Vector3(0.0, 1.0, 5.0))
	assert_almost_eq(mesh.transparency, U_VCAM_SILHOUETTE_HELPER.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001)

	manager.unregister_vcam(component)
	manager._physics_process(0.016)
	vfx_manager._physics_process(0.016)

	assert_almost_eq(mesh.transparency, 0.0, 0.001,
		"Silhouette should clear when active vcam is removed (scene swap teardown path)")
	assert_eq(U_VCAM_SELECTORS.get_silhouette_active_count(store.get_state()), 0)

func _create_occlusion_fixture() -> Dictionary:
	var store := _create_store()
	add_child_autofree(store)
	await _await_store_ready(store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child_autofree(camera_manager)
	U_SERVICE_LOCATOR.register(StringName("camera_manager"), camera_manager)

	var manager := M_VCAM_MANAGER.new()
	manager.state_store = store
	manager.camera_manager = camera_manager
	add_child_autofree(manager)
	await get_tree().process_frame
	U_SERVICE_LOCATOR.register(StringName("vcam_manager"), manager)

	var vfx_manager := M_VFX_MANAGER.new()
	vfx_manager.state_store = store
	vfx_manager.camera_manager = camera_manager
	add_child_autofree(vfx_manager)
	await get_tree().process_frame

	var follow_target := Node3D.new()
	follow_target.name = "FollowTarget"
	follow_target.position = Vector3(0.0, 1.0, 0.0)
	add_child_autofree(follow_target)

	var vcam_host := Node3D.new()
	vcam_host.name = "VCamHost"
	add_child_autofree(vcam_host)
	var component := C_VCAM_COMPONENT.new()
	component.vcam_id = StringName("cam_occlusion")
	component.priority = 20
	component.follow_target_path = follow_target.get_path()
	component.follow_target_entity_id = StringName("player")
	var orbit_mode := RS_VCAM_MODE_ORBIT.new()
	orbit_mode.allow_player_rotation = false
	orbit_mode.distance = 5.0
	component.mode = orbit_mode
	vcam_host.add_child(component)
	autofree(component)
	manager.register_vcam(component)
	manager.set_active_vcam(StringName("cam_occlusion"))

	var occluder_body := StaticBody3D.new()
	occluder_body.name = "OccluderBody"
	occluder_body.collision_layer = 1 << 5
	occluder_body.position = Vector3(0.0, 1.0, 2.5)
	add_child_autofree(occluder_body)

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 0.5)
	collision_shape.shape = shape
	occluder_body.add_child(collision_shape)
	autofree(collision_shape)

	var occluder_mesh := MeshInstance3D.new()
	occluder_mesh.mesh = BoxMesh.new()
	occluder_mesh.position = Vector3.ZERO
	occluder_body.add_child(occluder_mesh)
	autofree(occluder_mesh)

	return {
		"store": store,
		"camera_manager": camera_manager,
		"manager": manager,
		"vfx_manager": vfx_manager,
		"follow_target": follow_target,
		"vcam_component": component,
		"occluder_mesh": occluder_mesh,
	}

func _tick_occlusion_frame(
	manager: M_VCamManager,
	vfx_manager: M_VFXManager,
	follow_target: Node3D,
	camera_origin: Vector3
) -> void:
	var target_position: Vector3 = follow_target.global_position
	var transform := Transform3D(Basis.IDENTITY, camera_origin).looking_at(target_position, Vector3.UP)
	manager.submit_evaluated_camera(StringName("cam_occlusion"), {
		"transform": transform,
		"fov": 70.0,
		"mode_name": "orbit",
	})
	manager._physics_process(0.016)
	vfx_manager._physics_process(0.016)

func _create_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.boot_initial_state = RS_BOOT_INITIAL_STATE.new()
	store.menu_initial_state = RS_MENU_INITIAL_STATE.new()
	var navigation_initial := RS_NAVIGATION_INITIAL_STATE.new()
	navigation_initial.shell = StringName("gameplay")
	navigation_initial.base_scene_id = StringName("alleyway")
	store.navigation_initial_state = navigation_initial
	var gameplay_initial := RS_GAMEPLAY_INITIAL_STATE.new()
	gameplay_initial.player_entity_id = "player"
	store.gameplay_initial_state = gameplay_initial
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.settings_initial_state = RS_SETTINGS_INITIAL_STATE.new()
	store.debug_initial_state = RS_DEBUG_INITIAL_STATE.new()
	store.vfx_initial_state = RS_VFX_INITIAL_STATE.new()
	store.audio_initial_state = RS_AUDIO_INITIAL_STATE.new()
	store.display_initial_state = RS_DISPLAY_INITIAL_STATE.new()
	return store

func _await_store_ready(store: M_StateStore) -> void:
	if store != null and not store.is_ready():
		await store.store_ready
