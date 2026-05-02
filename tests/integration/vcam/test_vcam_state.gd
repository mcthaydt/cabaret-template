extends BaseTest

const M_STATE_STORE := preload("res://scripts/core/state/m_state_store.gd")
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
const U_STATE_HANDOFF := preload("res://scripts/core/state/utils/u_state_handoff.gd")
const U_GLOBAL_SETTINGS_SERIALIZATION := preload("res://scripts/core/utils/u_global_settings_serialization.gd")
const U_VCAM_ACTIONS := preload("res://scripts/core/state/actions/u_vcam_actions.gd")
const U_VCAM_SELECTORS := preload("res://scripts/core/state/selectors/u_vcam_selectors.gd")
const U_VFX_ACTIONS := preload("res://scripts/core/state/actions/u_vfx_actions.gd")
const U_INPUT_ACTIONS := preload("res://scripts/core/state/actions/u_input_actions.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")

const M_ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const S_VCAM_SYSTEM := preload("res://scripts/core/ecs/systems/s_vcam_system.gd")
const M_VCAM_MANAGER := preload("res://scripts/core/managers/m_vcam_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const BASE_ECS_ENTITY := preload("res://scripts/core/ecs/base_ecs_entity.gd")
const C_VCAM_COMPONENT := preload("res://scripts/core/ecs/components/c_vcam_component.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/core/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_BLEND_HINT := preload("res://scripts/core/resources/display/vcam/rs_vcam_blend_hint.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	U_ECS_EVENT_BUS.reset()
	_cleanup_global_settings_files()

func after_each() -> void:
	_cleanup_global_settings_files()
	U_ECS_EVENT_BUS.reset()
	U_STATE_HANDOFF.clear_all()
	super.after_each()

func test_vcam_slice_is_transient_in_store_config() -> void:
	var store := _create_store(false)
	add_child_autofree(store)
	await _await_store_ready(store)

	var state: Dictionary = store.get_state()
	assert_true(state.has("vcam"), "Store should include runtime vcam slice")

	var configs: Dictionary = store.get_slice_configs()
	var vcam_config: RS_StateSliceConfig = configs.get(StringName("vcam"))
	assert_not_null(vcam_config, "vcam slice config should be registered")
	assert_true(vcam_config.is_transient, "vcam slice should be transient")

func test_vcam_slice_is_excluded_from_global_settings_payload() -> void:
	var store := _create_store(false)
	add_child_autofree(store)
	await _await_store_ready(store)

	var settings := U_GLOBAL_SETTINGS_SERIALIZATION.build_settings_from_state(store.get_state())
	assert_false(settings.has("vcam"), "Transient vcam slice should not be persisted to global settings")
	assert_true(settings.has("vfx"), "Persisted vfx settings should still be included")

func test_vfx_occlusion_silhouette_setting_persists_to_global_settings() -> void:
	var store := _create_store(true)
	add_child_autofree(store)
	await _await_store_ready(store)

	store.dispatch(U_VFX_ACTIONS.set_occlusion_silhouette_enabled(false))
	await get_tree().process_frame
	await get_tree().process_frame

	var saved_settings: Dictionary = U_GLOBAL_SETTINGS_SERIALIZATION.load_settings()
	var vfx_settings: Dictionary = saved_settings.get("vfx", {})
	assert_false(
		bool(vfx_settings.get("occlusion_silhouette_enabled", true)),
		"VFX occlusion silhouette setting should persist through global settings serialization"
	)

func test_touchscreen_look_settings_persist_to_global_settings() -> void:
	var store := _create_store(true)
	add_child_autofree(store)
	await _await_store_ready(store)

	store.dispatch(U_INPUT_ACTIONS.update_touchscreen_settings({
		"look_drag_sensitivity": 1.75,
	}))
	await get_tree().process_frame
	await get_tree().process_frame

	var saved_settings: Dictionary = U_GLOBAL_SETTINGS_SERIALIZATION.load_settings()
	var input_settings: Dictionary = saved_settings.get("input_settings", {})
	var touchscreen_settings: Dictionary = input_settings.get("touchscreen_settings", {})
	assert_almost_eq(
		float(touchscreen_settings.get("look_drag_sensitivity", 0.0)),
		1.75,
		0.001,
		"Touchscreen look_drag_sensitivity should persist through global settings"
	)

func test_vcam_actions_and_selectors_work_end_to_end() -> void:
	var store := _create_store(false)
	add_child_autofree(store)
	await _await_store_ready(store)

	store.dispatch(U_VCAM_ACTIONS.set_active_runtime(StringName("cam_orbit"), "orbit"))
	store.dispatch(U_VCAM_ACTIONS.start_blend(StringName("cam_prev")))
	store.dispatch(U_VCAM_ACTIONS.update_blend(0.42))
	store.dispatch(U_VCAM_ACTIONS.update_target_validity(false))
	store.dispatch(U_VCAM_ACTIONS.record_recovery("manual_recovery"))

	var state: Dictionary = store.get_state()
	assert_eq(U_VCAM_SELECTORS.get_active_vcam_id(state), StringName("cam_orbit"))
	assert_true(U_VCAM_SELECTORS.is_blending(state))
	assert_almost_eq(U_VCAM_SELECTORS.get_blend_progress(state), 0.42, 0.0001)
	assert_false(U_VCAM_SELECTORS.is_active_target_valid(state))
	assert_eq(U_VCAM_SELECTORS.get_last_recovery_reason(state), "manual_recovery")

func test_blend_debug_fields_populate_while_blending() -> void:
	var fixture := await _create_runtime_fixture()
	autofree_context(fixture)
	var store: M_StateStore = fixture["store"] as M_StateStore
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager

	var target := _create_target_entity(ecs_manager, StringName("player"), Vector3.ZERO)
	await _create_orbit_vcam(ecs_manager, StringName("cam_a"), target, 20, 0.0)
	await _create_orbit_vcam(ecs_manager, StringName("cam_b"), target, 10, 0.3)
	manager.set_active_vcam(StringName("cam_a"))
	_submit_result(manager, StringName("cam_a"), Vector3(0.0, 2.0, 8.0))
	manager.set_active_vcam(StringName("cam_b"))
	_submit_result(manager, StringName("cam_a"), Vector3(0.0, 2.0, 8.0))
	_submit_result(manager, StringName("cam_b"), Vector3(2.0, 2.0, 6.0))
	manager._physics_process(0.05)

	var state: Dictionary = store.get_state()
	assert_true(U_VCAM_SELECTORS.is_blending(state), "Blend should be active after switching to a blend-authored vcam")
	assert_eq(U_VCAM_SELECTORS.get_blend_from_vcam_id(state), StringName("cam_a"))
	assert_eq(U_VCAM_SELECTORS.get_blend_to_vcam_id(state), StringName("cam_b"))

func test_active_target_valid_reflects_follow_target_validity() -> void:
	var fixture := await _create_runtime_fixture()
	autofree_context(fixture)
	var store: M_StateStore = fixture["store"] as M_StateStore
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager

	var target := _create_target_entity(ecs_manager, StringName("player"), Vector3.ZERO)
	var component := await _create_orbit_vcam(ecs_manager, StringName("cam_target_validity"), target, 20, 0.0)
	manager.set_active_vcam(StringName("cam_target_validity"))

	ecs_manager._physics_process(0.016)
	var valid_state: Dictionary = store.get_state()
	assert_true(U_VCAM_SELECTORS.is_active_target_valid(valid_state), "Active target should be valid with a live follow target")

	component.follow_target_path = NodePath("")
	ecs_manager._physics_process(0.016)
	var invalid_state: Dictionary = store.get_state()
	assert_false(
		U_VCAM_SELECTORS.is_active_target_valid(invalid_state),
		"Active target validity should go false after follow target is removed"
	)

func test_last_recovery_reason_updates_on_follow_target_loss() -> void:
	var fixture := await _create_runtime_fixture()
	autofree_context(fixture)
	var store: M_StateStore = fixture["store"] as M_StateStore
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager

	var target := _create_target_entity(ecs_manager, StringName("player"), Vector3.ZERO)
	var component := await _create_orbit_vcam(ecs_manager, StringName("cam_target_recovery"), target, 20, 0.0)
	manager.set_active_vcam(StringName("cam_target_recovery"))

	ecs_manager._physics_process(0.016)
	component.follow_target_path = NodePath("")
	ecs_manager._physics_process(0.016)

	var state: Dictionary = store.get_state()
	assert_eq(
		U_VCAM_SELECTORS.get_last_recovery_reason(state),
		"target_freed",
		"Follow-target loss should publish a recovery reason for observability"
	)

func test_blend_debug_fields_clear_after_blend_completion() -> void:
	var fixture := await _create_runtime_fixture()
	autofree_context(fixture)
	var store: M_StateStore = fixture["store"] as M_StateStore
	var manager: M_VCamManager = fixture["manager"] as M_VCamManager
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager

	var target := _create_target_entity(ecs_manager, StringName("player"), Vector3.ZERO)
	await _create_orbit_vcam(ecs_manager, StringName("cam_blend_from"), target, 20, 0.0)
	await _create_orbit_vcam(ecs_manager, StringName("cam_blend_to"), target, 10, 0.25)
	manager.set_active_vcam(StringName("cam_blend_from"))
	_submit_result(manager, StringName("cam_blend_from"), Vector3(0.0, 2.0, 8.0))
	manager.set_active_vcam(StringName("cam_blend_to"))

	for _i in range(5):
		_submit_result(manager, StringName("cam_blend_from"), Vector3(0.0, 2.0, 8.0))
		_submit_result(manager, StringName("cam_blend_to"), Vector3(3.0, 2.0, 6.0))
		manager._physics_process(0.08)

	var state: Dictionary = store.get_state()
	assert_false(U_VCAM_SELECTORS.is_blending(state), "Blend should complete after authored duration elapses")
	assert_eq(U_VCAM_SELECTORS.get_blend_from_vcam_id(state), StringName(""))
	assert_eq(U_VCAM_SELECTORS.get_blend_to_vcam_id(state), StringName(""))

func _create_runtime_fixture() -> Dictionary:
	var store := _create_store(false)
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

func _create_orbit_vcam(
	ecs_manager: M_ECSManager,
	vcam_id: StringName,
	follow_target: Node3D,
	priority: int,
	blend_duration: float
) -> C_VCamComponent:
	var host := BASE_ECS_ENTITY.new()
	host.name = "E_%sHost" % String(vcam_id)
	ecs_manager.add_child(host)
	autofree(host)

	var mode := RS_VCAM_MODE_ORBIT.new()
	mode.allow_player_rotation = false
	mode.distance = 5.0

	var component := C_VCAM_COMPONENT.new()
	component.vcam_id = vcam_id
	component.priority = priority
	component.mode = mode
	component.follow_target_path = follow_target.get_path()
	component.follow_target_entity_id = StringName("player")
	if blend_duration > 0.0:
		var blend_hint := RS_VCAM_BLEND_HINT.new()
		blend_hint.blend_duration = blend_duration
		component.blend_hint = blend_hint
	host.add_child(component)
	autofree(component)

	await get_tree().process_frame
	await get_tree().process_frame
	return component

func _submit_result(manager: M_VCamManager, vcam_id: StringName, origin: Vector3) -> void:
	manager.submit_evaluated_camera(vcam_id, {
		"transform": Transform3D(Basis.IDENTITY, origin),
		"fov": 70.0,
		"mode_name": "orbit",
	})

func _create_store(enable_global_settings: bool) -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.settings.enable_global_settings_persistence = enable_global_settings
	store.boot_initial_state = RS_BOOT_INITIAL_STATE.new()
	store.menu_initial_state = RS_MENU_INITIAL_STATE.new()
	var navigation_initial := RS_NAVIGATION_INITIAL_STATE.new()
	navigation_initial.shell = StringName("gameplay")
	navigation_initial.base_scene_id = StringName("demo_room")
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

func _cleanup_global_settings_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("global_settings.json"):
		dir.remove("global_settings.json")
	if dir.file_exists("global_settings.json.backup"):
		dir.remove("global_settings.json.backup")
