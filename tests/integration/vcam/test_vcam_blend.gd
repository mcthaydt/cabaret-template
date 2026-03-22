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
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

const M_VCAM_MANAGER := preload("res://scripts/managers/m_vcam_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_BLEND_HINT := preload("res://scripts/resources/display/vcam/rs_vcam_blend_hint.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_STATE_HANDOFF.clear_all()
	super.after_each()

func test_moving_to_moving_blend_stays_live_instead_of_frozen() -> void:
	var fixture := await _create_blend_fixture()
	autofree_context(fixture)
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var camera_manager: MockCameraManager = fixture["camera_manager"] as MockCameraManager

	_create_registered_vcam(manager, StringName("cam_a"), 20, 0.0)
	_create_registered_vcam(manager, StringName("cam_b"), 10, 1.0)
	manager.set_active_vcam(StringName("cam_a"))
	manager.set_active_vcam(StringName("cam_b"))

	_submit_result(manager, StringName("cam_a"), Vector3(0.0, 2.0, 8.0))
	_submit_result(manager, StringName("cam_b"), Vector3(10.0, 2.0, 8.0))
	manager._physics_process(0.25)
	var first_sample_x: float = camera_manager.last_main_transform.origin.x

	_submit_result(manager, StringName("cam_a"), Vector3(5.0, 2.0, 8.0))
	_submit_result(manager, StringName("cam_b"), Vector3(15.0, 2.0, 8.0))
	manager._physics_process(0.25)
	var second_sample_x: float = camera_manager.last_main_transform.origin.x

	assert_true(second_sample_x > first_sample_x, "Live blend should keep advancing with updated source/target submissions")
	assert_true(second_sample_x > 7.5, "Second sample should reflect live moving endpoints, not frozen initial transforms")

func test_cut_on_distance_threshold_forces_immediate_cut() -> void:
	var fixture := await _create_blend_fixture()
	autofree_context(fixture)
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var camera_manager: MockCameraManager = fixture["camera_manager"] as MockCameraManager

	_create_registered_vcam(manager, StringName("cam_from"), 20, 0.0)
	_create_registered_vcam(
		manager,
		StringName("cam_to"),
		10,
		1.0,
		int(Tween.TRANS_LINEAR),
		int(Tween.EASE_IN_OUT),
		1.0
	)
	manager.set_active_vcam(StringName("cam_from"))
	manager.set_active_vcam(StringName("cam_to"))

	_submit_result(manager, StringName("cam_from"), Vector3(0.0, 2.0, 8.0))
	_submit_result(manager, StringName("cam_to"), Vector3(20.0, 2.0, 8.0))
	manager._physics_process(0.05)

	assert_false(manager.is_blending(), "Distance threshold should force an immediate cut")
	assert_almost_eq(camera_manager.last_main_transform.origin.x, 20.0, 0.001,
		"Immediate cut should snap to destination transform")

func test_blend_respects_authored_ease_type() -> void:
	var fixture := await _create_blend_fixture()
	autofree_context(fixture)
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager

	_create_registered_vcam(manager, StringName("cam_source"), 30, 0.0)
	_create_registered_vcam(
		manager,
		StringName("cam_ease_in"),
		20,
		1.0,
		int(Tween.TRANS_CUBIC),
		int(Tween.EASE_IN)
	)
	_create_registered_vcam(
		manager,
		StringName("cam_ease_out"),
		10,
		1.0,
		int(Tween.TRANS_CUBIC),
		int(Tween.EASE_OUT)
	)

	manager.set_active_vcam(StringName("cam_source"))
	manager.set_active_vcam(StringName("cam_ease_in"))
	assert_true(manager.is_blending(), "Switch to authored blend camera should start a live blend")
	assert_eq(int(manager.get("_blend_trans_type")), int(Tween.TRANS_CUBIC))
	assert_eq(int(manager.get("_blend_ease_type")), int(Tween.EASE_IN))

	manager.set_active_vcam(StringName("cam_ease_out"))
	assert_true(manager.is_blending(), "Switching again should keep live blending active")
	assert_eq(int(manager.get("_blend_trans_type")), int(Tween.TRANS_CUBIC))
	assert_eq(int(manager.get("_blend_ease_type")), int(Tween.EASE_OUT))

func test_vcam_suspends_writes_while_camera_manager_transition_blend_is_active() -> void:
	var fixture := await _create_blend_fixture()
	autofree_context(fixture)
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var camera_manager: MockCameraManager = fixture["camera_manager"] as MockCameraManager

	_create_registered_vcam(manager, StringName("cam_blocked"), 10, 0.0)
	manager.set_active_vcam(StringName("cam_blocked"))
	camera_manager.blend_active = true

	_submit_result(manager, StringName("cam_blocked"), Vector3(1.0, 2.0, 3.0))
	manager._physics_process(0.016)

	assert_eq(camera_manager.apply_main_transform_calls, 0,
		"vCam manager should not apply gameplay transforms while camera-manager transition blend is active")

func test_vcam_resumes_writes_after_camera_manager_transition_blend_completes() -> void:
	var fixture := await _create_blend_fixture()
	autofree_context(fixture)
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var camera_manager: MockCameraManager = fixture["camera_manager"] as MockCameraManager

	_create_registered_vcam(manager, StringName("cam_resume"), 10, 0.0)
	manager.set_active_vcam(StringName("cam_resume"))
	camera_manager.blend_active = true
	_submit_result(manager, StringName("cam_resume"), Vector3(1.0, 2.0, 3.0))
	manager._physics_process(0.016)
	assert_eq(camera_manager.apply_main_transform_calls, 0)

	camera_manager.blend_active = false
	_submit_result(manager, StringName("cam_resume"), Vector3(4.0, 5.0, 6.0))
	manager._physics_process(0.016)

	assert_true(camera_manager.apply_main_transform_calls > 0,
		"vCam manager should resume applying gameplay transforms once transition blend ends")
	assert_almost_eq(
		camera_manager.last_main_transform.origin,
		Vector3(4.0, 5.0, 6.0),
		Vector3(0.001, 0.001, 0.001)
	)

func _create_blend_fixture() -> Dictionary:
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

	return {
		"store": store,
		"camera_manager": camera_manager,
		"manager": manager,
	}

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

func _create_registered_vcam(
	manager: M_VCamManager,
	vcam_id: StringName,
	priority: int,
	blend_duration: float,
	trans_type: int = int(Tween.TRANS_LINEAR),
	ease_type: int = int(Tween.EASE_IN_OUT),
	cut_on_distance_threshold: float = 0.0
) -> C_VCamComponent:
	var host := Node3D.new()
	host.name = "Host_%s" % String(vcam_id)
	add_child_autofree(host)

	var component := C_VCAM_COMPONENT.new()
	component.vcam_id = vcam_id
	component.priority = priority
	var mode := RS_VCAM_MODE_ORBIT.new()
	mode.allow_player_rotation = false
	component.mode = mode
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = blend_duration
	hint.trans_type = trans_type
	hint.ease_type = ease_type
	hint.cut_on_distance_threshold = cut_on_distance_threshold
	component.blend_hint = hint
	host.add_child(component)
	autofree(component)

	manager.register_vcam(component)
	return component

func _submit_result(manager: M_VCamManager, vcam_id: StringName, origin: Vector3) -> void:
	manager.submit_evaluated_camera(vcam_id, {
		"transform": Transform3D(Basis.IDENTITY, origin),
		"fov": 70.0,
		"mode_name": "orbit",
	})
