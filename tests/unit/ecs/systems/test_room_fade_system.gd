extends BaseTest

const ROOM_FADE_SYSTEM_PATH := "res://scripts/ecs/systems/s_room_fade_system.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_ROOM_FADE_GROUP_COMPONENT := preload("res://scripts/ecs/components/c_room_fade_group_component.gd")
const RS_ROOM_FADE_SETTINGS := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")

class RoomFadeMaterialApplierStub extends RefCounted:
	var apply_calls: int = 0
	var update_calls: int = 0
	var restore_calls: int = 0
	var last_updated_alpha: float = -1.0
	var last_updated_target_count: int = 0
	var last_restore_target_count: int = 0

	func apply_fade_material(targets: Array[MeshInstance3D]) -> void:
		apply_calls += 1
		last_updated_target_count = targets.size()

	func update_fade_alpha(targets: Array[MeshInstance3D], alpha: float) -> void:
		update_calls += 1
		last_updated_alpha = alpha
		last_updated_target_count = targets.size()

	func restore_original_materials(targets: Array[MeshInstance3D]) -> void:
		restore_calls += 1
		last_restore_target_count = targets.size()

func _room_fade_system_script() -> Script:
	var script_obj := load(ROOM_FADE_SYSTEM_PATH) as Script
	assert_not_null(script_obj, "Room fade system should load: %s" % ROOM_FADE_SYSTEM_PATH)
	return script_obj

func test_system_discovers_room_fade_components_via_ecs_manager() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	_register_room_fade_group(ecs_manager, "E_RoomFadeA")
	system.process_tick(0.1)

	assert_eq(applier.apply_calls, 1)
	assert_eq(applier.update_calls, 1)

func test_dot_above_threshold_triggers_fade_down() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(ecs_manager)

	var room_component: Variant = _register_room_fade_group(ecs_manager, "E_RoomFadeB")
	room_component.fade_normal = Vector3(0.0, 0.0, -1.0)
	room_component.current_alpha = 1.0

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 1.0
	settings.min_alpha = 0.1
	room_component.settings = settings

	system.process_tick(0.25)
	assert_almost_eq(room_component.current_alpha, 0.75, 0.0001)

func test_dot_below_threshold_triggers_fade_up_toward_opaque() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(ecs_manager)

	var room_component: Variant = _register_room_fade_group(ecs_manager, "E_RoomFadeC")
	room_component.fade_normal = Vector3(0.0, 0.0, 1.0)
	room_component.current_alpha = 0.3

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 1.0
	settings.min_alpha = 0.1
	room_component.settings = settings

	system.process_tick(0.25)
	assert_almost_eq(room_component.current_alpha, 0.55, 0.0001)

func test_current_alpha_changes_at_fade_speed_rate_per_second() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(ecs_manager)

	var room_component: Variant = _register_room_fade_group(ecs_manager, "E_RoomFadeD")
	room_component.fade_normal = Vector3(0.0, 0.0, -1.0)
	room_component.current_alpha = 1.0

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 2.0
	settings.min_alpha = 0.05
	room_component.settings = settings

	system.process_tick(0.4)
	assert_almost_eq(room_component.current_alpha, 0.2, 0.0001)

func test_current_alpha_never_drops_below_min_alpha() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(ecs_manager)

	var room_component: Variant = _register_room_fade_group(ecs_manager, "E_RoomFadeE")
	room_component.fade_normal = Vector3(0.0, 0.0, -1.0)
	room_component.current_alpha = 1.0

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.35
	room_component.settings = settings

	system.process_tick(0.5)
	assert_almost_eq(room_component.current_alpha, 0.35, 0.0001)

func test_system_updates_material_alpha_with_component_current_alpha() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	var room_component: Variant = _register_room_fade_group(ecs_manager, "E_RoomFadeF")
	room_component.fade_normal = Vector3(0.0, 0.0, -1.0)
	room_component.current_alpha = 1.0

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 1.0
	settings.min_alpha = 0.1
	room_component.settings = settings

	system.process_tick(0.2)
	assert_almost_eq(room_component.current_alpha, 0.8, 0.0001)
	assert_almost_eq(applier.last_updated_alpha, room_component.current_alpha, 0.0001)

func test_system_uses_default_settings_when_component_settings_null() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(ecs_manager)

	var room_component: Variant = _register_room_fade_group(ecs_manager, "E_RoomFadeG")
	room_component.settings = null
	room_component.fade_normal = Vector3(0.0, 0.0, -1.0)
	room_component.current_alpha = 1.0

	system.process_tick(0.1)
	assert_almost_eq(room_component.current_alpha, 0.6, 0.0001)

func test_system_is_noop_when_no_room_fade_components_exist() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	assert_not_null(system)
	assert_not_null(applier)

	system.process_tick(0.1)
	assert_eq(applier.apply_calls, 0)
	assert_eq(applier.update_calls, 0)
	assert_eq(applier.restore_calls, 0)

func test_system_restores_stale_targets_when_components_are_removed() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	_register_room_fade_group(ecs_manager, "E_RoomFadeH")
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 0)

	ecs_manager.clear_all_components()
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 1)
	assert_eq(applier.last_restore_target_count, 1)

func test_system_restores_targets_when_main_camera_is_missing() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	var main_camera: Camera3D = fixture.get("main_camera") as Camera3D
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(camera_manager)
	assert_not_null(main_camera)

	_register_room_fade_group(ecs_manager, "E_RoomFadeI")
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 0)

	camera_manager.main_camera = null
	remove_child(main_camera)
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 1)
	assert_eq(applier.last_restore_target_count, 1)

func test_system_restores_to_opaque_when_active_mode_is_not_orbit() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(store)

	var room_component: Variant = _register_room_fade_group(ecs_manager, "E_RoomFadeJ")
	room_component.fade_normal = Vector3(0.0, 0.0, -1.0)
	room_component.current_alpha = 1.0
	system.process_tick(0.1)
	assert_lt(room_component.current_alpha, 1.0)
	assert_eq(applier.restore_calls, 0)

	store.set_slice("vcam", {"active_mode": "first_person"})
	system.process_tick(0.1)

	assert_eq(room_component.current_alpha, 1.0)
	assert_eq(applier.restore_calls, 1)
	assert_eq(applier.apply_calls, 1)
	assert_eq(applier.update_calls, 1)

func test_system_uses_viewport_camera_fallback_when_camera_manager_main_is_null() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(camera_manager)

	_register_room_fade_group(ecs_manager, "E_RoomFadeK")
	camera_manager.main_camera = null
	system.process_tick(0.1)

	assert_eq(applier.apply_calls, 1)
	assert_eq(applier.update_calls, 1)
	assert_eq(applier.restore_calls, 0)

func _create_fixture() -> Dictionary:
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
	state_store.set_slice("vcam", {"active_mode": "orbit"})

	var applier := RoomFadeMaterialApplierStub.new()

	var system: Variant = room_fade_system_script.new()
	autofree(system)
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.state_store = state_store
	system.material_applier = applier
	add_child(system)
	system.configure(ecs_manager)

	return {
		"system": system,
		"ecs_manager": ecs_manager,
		"camera_manager": camera_manager,
		"main_camera": main_camera,
		"state_store": state_store,
		"applier": applier,
	}

func _register_room_fade_group(ecs_manager: MockECSManager, entity_name: String) -> Variant:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
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

	return component
