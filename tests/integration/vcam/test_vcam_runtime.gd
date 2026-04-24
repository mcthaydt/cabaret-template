extends BaseTest

const ROOT_SCENE := preload("res://scenes/root.tscn")

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const RS_BOOT_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_boot_initial_state.gd")
const RS_MENU_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_menu_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_navigation_initial_state.gd")
const RS_SETTINGS_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_settings_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_scene_initial_state.gd")
const RS_DEBUG_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_debug_initial_state.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_vfx_initial_state.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_audio_initial_state.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_display_initial_state.gd")

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_VCAM_SELECTORS := preload("res://scripts/state/selectors/u_vcam_selectors.gd")

const M_ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const S_VCAM_SYSTEM := preload("res://scripts/ecs/systems/s_vcam_system.gd")
const M_VCAM_MANAGER := preload("res://scripts/core/managers/m_vcam_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/core/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_BLEND_HINT := preload("res://scripts/core/resources/display/vcam/rs_vcam_blend_hint.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_STATE_HANDOFF.clear_all()
	super.after_each()

func test_root_scene_registers_vcam_manager_in_service_locator() -> void:
	var root := ROOT_SCENE.instantiate()
	add_child_autofree(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager := U_SERVICE_LOCATOR.try_get_service(StringName("vcam_manager"))
	assert_not_null(manager, "Root bootstrap should register vcam_manager service")
	assert_true(manager is M_VCamManager, "Registered vcam_manager service should be M_VCamManager")

func test_s_vcam_system_resolves_vcam_manager_via_service_locator() -> void:
	var fixture := await _create_runtime_fixture()
	autofree_context(fixture)
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var system: S_VCamSystem = fixture["system"] as S_VCamSystem
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager

	var target := _create_target_entity(ecs_manager, StringName("player"), Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_locator"), _new_orbit_mode(), target, 20, 0.0)
	manager.set_active_vcam(StringName("cam_locator"))
	ecs_manager._physics_process(0.016)

	assert_eq(system.get("_vcam_manager"), manager, "S_VCamSystem should discover M_VCamManager via ServiceLocator")

func test_orbit_vcam_evaluates_and_submits_through_runtime_pipeline() -> void:
	var fixture := await _create_runtime_fixture()
	autofree_context(fixture)
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var camera_manager: MockCameraManager = fixture["camera_manager"] as MockCameraManager

	var target := _create_target_entity(ecs_manager, StringName("player"), Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_orbit_runtime"), _new_orbit_mode(), target, 20, 0.0)
	manager.set_active_vcam(StringName("cam_orbit_runtime"))

	ecs_manager._physics_process(0.016)
	manager._physics_process(0.016)

	var submitted := _get_submitted_result(manager, StringName("cam_orbit_runtime"))
	assert_false(submitted.is_empty(), "Orbit vCam should submit evaluated results")
	assert_eq(String(submitted.get("mode_name", "")), "orbit")
	assert_true(camera_manager.apply_main_transform_calls > 0, "Submitted orbit transform should route through camera manager")

func test_switching_active_vcams_starts_blend_runtime_state() -> void:
	var fixture := await _create_runtime_fixture()
	autofree_context(fixture)
	var store: M_StateStore = fixture["store"] as M_StateStore
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager

	var target := _create_target_entity(ecs_manager, StringName("player"), Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_runtime_a"), _new_orbit_mode(), target, 20, 0.0)
	await _create_vcam_component(ecs_manager, StringName("cam_runtime_b"), _new_orbit_mode(), target, 10, 0.3)

	manager.set_active_vcam(StringName("cam_runtime_a"))
	_submit_result(manager, StringName("cam_runtime_a"), Vector3(0.0, 2.0, 8.0))
	manager.set_active_vcam(StringName("cam_runtime_b"))
	_submit_result(manager, StringName("cam_runtime_a"), Vector3(0.0, 2.0, 8.0))
	_submit_result(manager, StringName("cam_runtime_b"), Vector3(2.0, 2.0, 6.0))
	manager._physics_process(0.05)

	assert_true(manager.is_blending(), "Switching active vCam should start a blend when blend duration is authored")
	assert_true(U_VCAM_SELECTORS.is_blending(store.get_state()), "Redux vcam slice should report active blend")

func test_runtime_blend_completes_and_updates_active_vcam() -> void:
	var fixture := await _create_runtime_fixture()
	autofree_context(fixture)
	var store: M_StateStore = fixture["store"] as M_StateStore
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager

	var target := _create_target_entity(ecs_manager, StringName("player"), Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_runtime_from"), _new_orbit_mode(), target, 20, 0.0)
	await _create_vcam_component(ecs_manager, StringName("cam_runtime_to"), _new_orbit_mode(), target, 10, 0.25)

	manager.set_active_vcam(StringName("cam_runtime_from"))
	_submit_result(manager, StringName("cam_runtime_from"), Vector3(0.0, 2.0, 8.0))
	manager.set_active_vcam(StringName("cam_runtime_to"))

	for _i in range(5):
		_submit_result(manager, StringName("cam_runtime_from"), Vector3(0.0, 2.0, 8.0))
		_submit_result(manager, StringName("cam_runtime_to"), Vector3(3.0, 2.0, 6.0))
		manager._physics_process(0.08)

	var state: Dictionary = store.get_state()
	assert_false(manager.is_blending(), "Blend should complete after duration elapses")
	assert_eq(manager.get_active_vcam_id(), StringName("cam_runtime_to"))
	assert_eq(U_VCAM_SELECTORS.get_active_vcam_id(state), StringName("cam_runtime_to"))
	assert_false(U_VCAM_SELECTORS.is_blending(state))

func _create_runtime_fixture() -> Dictionary:
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

	var ecs_manager := M_ECS_MANAGER.new()
	add_child_autofree(ecs_manager)
	await get_tree().process_frame

	var system := S_VCAM_SYSTEM.new()
	system.execution_priority = 100
	ecs_manager.add_child(system)
	autofree(system)
	await get_tree().process_frame
	await get_tree().process_frame

	return {
		"store": store,
		"camera_manager": camera_manager,
		"manager": manager,
		"ecs_manager": ecs_manager,
		"system": system,
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

func _create_target_entity(
	ecs_manager: M_ECSManager,
	entity_id: StringName,
	position: Vector3
) -> BaseECSEntity:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_%s" % String(entity_id)
	entity.entity_id = entity_id
	ecs_manager.add_child(entity)
	autofree(entity)
	entity.global_position = position
	return entity

func _create_vcam_component(
	ecs_manager: M_ECSManager,
	vcam_id: StringName,
	mode: Resource,
	follow_target: Node3D,
	priority: int,
	blend_duration: float
) -> C_VCamComponent:
	var host := BASE_ECS_ENTITY.new()
	host.name = "E_%sHost" % String(vcam_id)
	ecs_manager.add_child(host)
	autofree(host)

	var component := C_VCAM_COMPONENT.new()
	component.vcam_id = vcam_id
	component.mode = mode
	component.priority = priority
	component.follow_target_path = follow_target.get_path()
	component.follow_target_entity_id = StringName("player")
	if blend_duration > 0.0:
		var hint := RS_VCAM_BLEND_HINT.new()
		hint.blend_duration = blend_duration
		component.blend_hint = hint
	host.add_child(component)
	autofree(component)

	await get_tree().process_frame
	await get_tree().process_frame
	return component

func _new_orbit_mode() -> RS_VCamModeOrbit:
	var mode := RS_VCAM_MODE_ORBIT.new()
	mode.allow_player_rotation = false
	mode.distance = 5.0
	mode.authored_pitch = -20.0
	return mode

func _submit_result(manager: M_VCamManager, vcam_id: StringName, origin: Vector3) -> void:
	manager.submit_evaluated_camera(vcam_id, {
		"transform": Transform3D(Basis.IDENTITY, origin),
		"fov": 70.0,
		"mode_name": "orbit",
	})

func _get_submitted_result(manager: M_VCamManager, vcam_id: StringName) -> Dictionary:
	var submitted: Dictionary = manager.get("_submitted_results") as Dictionary
	var entry_variant: Variant = submitted.get(vcam_id, {})
	if not (entry_variant is Dictionary):
		return {}
	var entry: Dictionary = entry_variant as Dictionary
	var result_variant: Variant = entry.get("result", {})
	if result_variant is Dictionary:
		return (result_variant as Dictionary).duplicate(true)
	return {}
