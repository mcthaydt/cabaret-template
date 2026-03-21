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
	var updated_alpha_by_target_id: Dictionary = {}

	func invalidate_externally_removed() -> void:
		pass

	func apply_fade_material(targets: Array) -> void:
		apply_calls += 1
		last_updated_target_count = targets.size()

	func update_fade_alpha(targets: Array, alpha: float) -> void:
		update_calls += 1
		last_updated_alpha = alpha
		last_updated_target_count = targets.size()
		for target_variant in targets:
			var target := target_variant as Node3D
			if target == null:
				continue
			updated_alpha_by_target_id[target.get_instance_id()] = alpha

	func restore_original_materials(targets: Array) -> void:
		restore_calls += 1
		last_restore_target_count = targets.size()

class DuplicateOwnershipWarningRecorder extends RefCounted:
	var messages: Array[String] = []

	func record(message: String) -> void:
		messages.append(message)

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

func test_system_supports_csg_room_fade_targets() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	var room_component: Variant = _register_room_fade_group(ecs_manager, "E_RoomFadeL", true)
	room_component.fade_normal = Vector3(0.0, 0.0, -1.0)
	room_component.current_alpha = 1.0
	system.process_tick(0.2)

	assert_eq(applier.apply_calls, 1)
	assert_eq(applier.update_calls, 1)
	assert_lt(room_component.current_alpha, 1.0)

func test_multi_target_group_applies_distinct_target_alphas_by_target_position() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	var setup: Dictionary = _register_room_fade_group_with_opposite_csg_targets(ecs_manager, "E_RoomFadeMulti")
	var room_component = setup.get("component")
	var front_target: Node3D = setup.get("front_target") as Node3D
	var back_target: Node3D = setup.get("back_target") as Node3D
	assert_not_null(room_component)
	assert_not_null(front_target)
	assert_not_null(back_target)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.3
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	room_component.settings = settings
	room_component.current_alpha = 1.0

	system.process_tick(0.1)

	var front_alpha: float = float(applier.updated_alpha_by_target_id.get(front_target.get_instance_id(), -1.0))
	var back_alpha: float = float(applier.updated_alpha_by_target_id.get(back_target.get_instance_id(), -1.0))
	assert_gt(front_alpha, -0.5, "Expected front target alpha update to be captured.")
	assert_gt(back_alpha, -0.5, "Expected back target alpha update to be captured.")
	assert_lt(front_alpha, back_alpha, "Opposite-side targets should not share identical fade behavior.")

func test_multi_target_group_does_not_fade_side_wall_for_forward_looking_camera() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	var setup: Dictionary = _register_room_fade_group_with_front_and_side_csg_targets(
		ecs_manager,
		"E_RoomFadeFrontAndSide"
	)
	var room_component = setup.get("component")
	var front_target: Node3D = setup.get("front_target") as Node3D
	var side_target: Node3D = setup.get("side_target") as Node3D
	assert_not_null(room_component)
	assert_not_null(front_target)
	assert_not_null(side_target)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.3
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	room_component.settings = settings
	room_component.current_alpha = 1.0

	system.process_tick(0.1)

	var front_alpha: float = float(applier.updated_alpha_by_target_id.get(front_target.get_instance_id(), -1.0))
	var side_alpha: float = float(applier.updated_alpha_by_target_id.get(side_target.get_instance_id(), -1.0))
	assert_gt(front_alpha, -0.5, "Expected front target alpha update to be captured.")
	assert_gt(side_alpha, -0.5, "Expected side target alpha update to be captured.")
	assert_almost_eq(front_alpha, 0.05, 0.0001, "Front wall should fade at this camera heading.")
	assert_almost_eq(side_alpha, 1.0, 0.0001, "Side wall should stay opaque at this camera heading.")

func test_duplicate_target_ownership_keeps_first_component_and_skips_duplicate_updates() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	var warning_recorder := DuplicateOwnershipWarningRecorder.new()
	system.duplicate_target_warning_handler = Callable(warning_recorder, "record")

	var setup: Dictionary = _register_room_fade_group_with_duplicate_components(
		ecs_manager,
		"E_RoomFadeDuplicateOwnership"
	)
	var first_component = setup.get("first_component")
	var second_component = setup.get("second_component")
	var shared_target: MeshInstance3D = setup.get("target") as MeshInstance3D
	assert_not_null(first_component)
	assert_not_null(second_component)
	assert_not_null(shared_target)

	var first_settings := RS_ROOM_FADE_SETTINGS.new()
	first_settings.fade_dot_threshold = 0.3
	first_settings.fade_speed = 100.0
	first_settings.min_alpha = 0.05
	first_component.settings = first_settings
	first_component.current_alpha = 1.0

	var second_settings := RS_ROOM_FADE_SETTINGS.new()
	second_settings.fade_dot_threshold = 0.3
	second_settings.fade_speed = 100.0
	second_settings.min_alpha = 0.6
	second_component.settings = second_settings
	second_component.current_alpha = 1.0

	system.process_tick(0.1)

	var shared_target_alpha: float = float(
		applier.updated_alpha_by_target_id.get(shared_target.get_instance_id(), -1.0)
	)
	assert_eq(applier.apply_calls, 1, "Only the first owner should apply fade material.")
	assert_eq(applier.update_calls, 1, "Only the first owner should update alpha for a shared target.")
	assert_almost_eq(shared_target_alpha, 0.05, 0.0001, "Shared target should use first owner settings.")
	assert_almost_eq(float(first_component.current_alpha), 0.05, 0.0001)
	assert_almost_eq(
		float(second_component.current_alpha),
		1.0,
		0.0001,
		"Duplicate owner should be skipped and remain unchanged."
	)
	assert_eq(warning_recorder.messages.size(), 1, "Duplicate ownership should emit one warning per pair per tick.")
	assert_true(
		warning_recorder.messages[0].find("duplicate") >= 0,
		"Warning should describe duplicate room-fade ownership."
	)

func test_system_caches_target_normals_across_ticks() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(ecs_manager)

	_register_room_fade_group(ecs_manager, "E_RoomFadeNormalCache")
	system.process_tick(0.1)
	var cached_normals_after_first: Dictionary = system._cached_normals.duplicate()
	assert_false(cached_normals_after_first.is_empty(), "Should have cached normals after first tick.")

	system.process_tick(0.1)
	var cached_normals_after_second: Dictionary = system._cached_normals.duplicate()
	assert_eq(cached_normals_after_first.size(), cached_normals_after_second.size(),
		"Normal cache size should remain stable across ticks with same targets.")

func test_multi_room_only_fades_room_closest_to_player() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(store)

	var room_a_setup: Dictionary = _register_room_fade_group_at_position(
		ecs_manager, "E_RoomA", Vector3(0.0, 0.0, 0.0)
	)
	var room_b_setup: Dictionary = _register_room_fade_group_at_position(
		ecs_manager, "E_RoomB", Vector3(30.0, 0.0, 0.0)
	)
	var room_a_target: Node3D = room_a_setup.get("target") as Node3D
	var room_b_target: Node3D = room_b_setup.get("target") as Node3D
	assert_not_null(room_a_target)
	assert_not_null(room_b_target)

	_set_player_position(store, Vector3(1.0, 0.0, 0.0))

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.3
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	room_a_setup.get("component").settings = settings
	room_b_setup.get("component").settings = settings

	system.process_tick(0.1)

	var room_a_alpha: float = float(applier.updated_alpha_by_target_id.get(room_a_target.get_instance_id(), -1.0))
	var room_b_alpha: float = float(applier.updated_alpha_by_target_id.get(room_b_target.get_instance_id(), -1.0))
	assert_lt(room_a_alpha, 1.0, "Room A (near player) target should be faded.")
	assert_true(
		room_b_alpha < 0.0 or room_b_alpha >= 1.0,
		"Room B (far from player) target should NOT be faded. Got alpha=%s" % str(room_b_alpha)
	)

func test_multi_room_switches_active_room_when_player_moves() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(store)

	var room_a_setup: Dictionary = _register_room_fade_group_at_position(
		ecs_manager, "E_RoomSwitchA", Vector3(0.0, 0.0, 0.0)
	)
	var room_b_setup: Dictionary = _register_room_fade_group_at_position(
		ecs_manager, "E_RoomSwitchB", Vector3(30.0, 0.0, 0.0)
	)
	var room_a_target: Node3D = room_a_setup.get("target") as Node3D
	var room_b_target: Node3D = room_b_setup.get("target") as Node3D
	var room_a_component = room_a_setup.get("component")
	var room_b_component = room_b_setup.get("component")
	assert_not_null(room_a_target)
	assert_not_null(room_b_target)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.3
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	room_a_component.settings = settings
	room_b_component.settings = settings

	_set_player_position(store, Vector3(1.0, 0.0, 0.0))
	system.process_tick(0.1)

	var room_a_alpha_first: float = float(applier.updated_alpha_by_target_id.get(room_a_target.get_instance_id(), -1.0))
	assert_lt(room_a_alpha_first, 1.0, "Room A should be faded when player is near.")

	_set_player_position(store, Vector3(31.0, 0.0, 0.0))
	applier.updated_alpha_by_target_id.clear()
	system.process_tick(0.1)

	var room_b_alpha_second: float = float(applier.updated_alpha_by_target_id.get(room_b_target.get_instance_id(), -1.0))
	assert_lt(room_b_alpha_second, 1.0, "Room B should be faded after player moved near it.")
	assert_eq(applier.restore_calls, 1, "Room A targets should have been restored after player left.")

func test_multi_room_falls_back_to_all_rooms_when_no_player_position() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	_register_room_fade_group_at_position(ecs_manager, "E_FallbackA", Vector3(0.0, 0.0, 0.0))
	_register_room_fade_group_at_position(ecs_manager, "E_FallbackB", Vector3(30.0, 0.0, 0.0))

	system.process_tick(0.1)

	assert_eq(applier.apply_calls, 2, "Both rooms should be processed when no player position is available.")

func test_multi_room_falls_back_when_player_position_is_not_vector3() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(store)

	_register_room_fade_group_at_position(ecs_manager, "E_StringPosA", Vector3(0.0, 0.0, 0.0))
	_register_room_fade_group_at_position(ecs_manager, "E_StringPosB", Vector3(30.0, 0.0, 0.0))

	store.set_slice("gameplay", {
		"player_entity_id": "player",
		"entities": {
			"player": {
				"entity_type": "player",
				"position": "(1.0, 0.0, 0.0)",
			}
		}
	})

	system.process_tick(0.1)

	assert_eq(applier.apply_calls, 2, "Both rooms should be processed when position is not Vector3.")

func test_system_invalidates_normal_cache_when_targets_change() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	assert_not_null(system)
	assert_not_null(ecs_manager)
	assert_not_null(applier)

	_register_room_fade_group(ecs_manager, "E_RoomFadeNormalInvalidate")
	system.process_tick(0.1)
	assert_false(system._cached_normals.is_empty())

	ecs_manager.clear_all_components()
	system.process_tick(0.1)
	assert_true(system._cached_normals.is_empty(),
		"Normal cache should be cleared when targets become stale.")

func test_csg_normals_use_target_centroid_not_world_origin() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var main_camera: Camera3D = fixture.get("main_camera") as Camera3D
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(main_camera)

	# Room centered at (-16, 0, -10), far from world origin.
	# North wall at z=-5 and south wall at z=-15.
	# Camera looks -Z (south). North wall is behind camera → should stay opaque.
	# South wall is in front of camera → should fade.
	var setup: Dictionary = _register_room_fade_group_offset_csg(
		ecs_manager, "E_OffOriginRoom", Vector3(-16.0, 0.0, -10.0)
	)
	var north_target: Node3D = setup.get("north_target") as Node3D
	var south_target: Node3D = setup.get("south_target") as Node3D
	var component = setup.get("component")
	assert_not_null(north_target)
	assert_not_null(south_target)
	assert_not_null(component)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.3
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings
	component.current_alpha = 1.0

	# Camera looking -Z
	main_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(-16.0, 5.0, 0.0))
	main_camera.look_at(Vector3(-16.0, 0.0, -10.0), Vector3.UP)

	system.process_tick(0.1)

	var north_alpha: float = float(applier.updated_alpha_by_target_id.get(north_target.get_instance_id(), -1.0))
	var south_alpha: float = float(applier.updated_alpha_by_target_id.get(south_target.get_instance_id(), -1.0))
	assert_gt(north_alpha, -0.5, "Expected north target alpha update.")
	assert_gt(south_alpha, -0.5, "Expected south target alpha update.")
	# North wall should be opaque (camera looks away from its inward face)
	assert_almost_eq(north_alpha, 1.0, 0.01, "North wall should stay opaque when camera looks -Z.")
	# South wall should fade (camera looks toward its inward face)
	assert_almost_eq(south_alpha, 0.05, 0.01, "South wall should fade when camera looks -Z.")

func test_csg_normals_correct_for_room_at_origin() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var main_camera: Camera3D = fixture.get("main_camera") as Camera3D
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(main_camera)

	# Same layout but at origin — sanity check that the fix doesn't regress.
	var setup: Dictionary = _register_room_fade_group_offset_csg(
		ecs_manager, "E_OriginRoom", Vector3(0.0, 0.0, 0.0)
	)
	var north_target: Node3D = setup.get("north_target") as Node3D
	var south_target: Node3D = setup.get("south_target") as Node3D
	var component = setup.get("component")

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.3
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings
	component.current_alpha = 1.0

	main_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 10.0))
	main_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)

	system.process_tick(0.1)

	var north_alpha: float = float(applier.updated_alpha_by_target_id.get(north_target.get_instance_id(), -1.0))
	var south_alpha: float = float(applier.updated_alpha_by_target_id.get(south_target.get_instance_id(), -1.0))
	assert_gt(north_alpha, -0.5, "Expected north target alpha update.")
	assert_gt(south_alpha, -0.5, "Expected south target alpha update.")
	assert_almost_eq(north_alpha, 1.0, 0.01, "North wall should stay opaque when camera looks -Z.")
	assert_almost_eq(south_alpha, 0.05, 0.01, "South wall should fade when camera looks -Z.")

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

func _register_room_fade_group(ecs_manager: MockECSManager, entity_name: String, use_csg_target: bool = false) -> Variant:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	if use_csg_target:
		var csg_wall := CSGBox3D.new()
		entity.add_child(csg_wall)
		autofree(csg_wall)
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = BoxMesh.new()
		entity.add_child(mesh_instance)
		autofree(mesh_instance)

	return component

func _register_room_fade_group_with_opposite_csg_targets(ecs_manager: MockECSManager, entity_name: String) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var front_target := CSGBox3D.new()
	front_target.position = Vector3(0.0, 0.0, 5.0)
	entity.add_child(front_target)
	autofree(front_target)

	var back_target := CSGBox3D.new()
	back_target.position = Vector3(0.0, 0.0, -5.0)
	entity.add_child(back_target)
	autofree(back_target)

	return {
		"component": component,
		"front_target": front_target,
		"back_target": back_target,
	}

func _register_room_fade_group_with_front_and_side_csg_targets(
	ecs_manager: MockECSManager,
	entity_name: String
) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var front_target := CSGBox3D.new()
	front_target.size = Vector3(2.0, 2.0, 0.1)
	front_target.position = Vector3(0.0, 0.0, 5.0)
	entity.add_child(front_target)
	autofree(front_target)

	var side_target := CSGBox3D.new()
	side_target.size = Vector3(2.0, 2.0, 0.1)
	side_target.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(7.0, 0.0, 4.0))
	entity.add_child(side_target)
	autofree(side_target)

	return {
		"component": component,
		"front_target": front_target,
		"side_target": side_target,
	}

func _register_room_fade_group_at_position(
	ecs_manager: MockECSManager,
	entity_name: String,
	world_position: Vector3
) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)
	entity.global_position = world_position

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	entity.add_child(mesh_instance)
	autofree(mesh_instance)

	return {
		"entity": entity,
		"component": component,
		"target": mesh_instance,
	}

func _register_room_fade_group_offset_csg(
	ecs_manager: MockECSManager,
	entity_name: String,
	center: Vector3
) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)
	entity.global_position = center

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	# North wall: thin in Z, offset +5 Z from center
	var north_target := CSGBox3D.new()
	north_target.size = Vector3(4.0, 4.0, 0.1)
	north_target.position = Vector3(0.0, 0.0, 5.0)
	entity.add_child(north_target)
	autofree(north_target)

	# South wall: thin in Z, offset -5 Z from center
	var south_target := CSGBox3D.new()
	south_target.size = Vector3(4.0, 4.0, 0.1)
	south_target.position = Vector3(0.0, 0.0, -5.0)
	entity.add_child(south_target)
	autofree(south_target)

	return {
		"entity": entity,
		"component": component,
		"north_target": north_target,
		"south_target": south_target,
	}

func _register_room_fade_group_with_duplicate_components(
	ecs_manager: MockECSManager,
	entity_name: String
) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)

	var first_component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(first_component)
	autofree(first_component)
	ecs_manager.add_component_to_entity(entity, first_component)

	var second_component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(second_component)
	autofree(second_component)
	ecs_manager.add_component_to_entity(entity, second_component)

	var shared_target := MeshInstance3D.new()
	shared_target.mesh = BoxMesh.new()
	entity.add_child(shared_target)
	autofree(shared_target)

	return {
		"entity": entity,
		"first_component": first_component,
		"second_component": second_component,
		"target": shared_target,
	}

func _set_player_position(store: MockStateStore, position: Vector3) -> void:
	store.set_slice("gameplay", {
		"player_entity_id": "player",
		"entities": {
			"player": {
				"entity_type": "player",
				"position": position,
			}
		}
	})
