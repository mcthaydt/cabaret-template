extends BaseTest

const REGION_VISIBILITY_SYSTEM_PATH := "res://scripts/ecs/systems/s_region_visibility_system.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_REGION_VISIBILITY_COMPONENT := preload(
	"res://scripts/ecs/components/c_region_visibility_component.gd"
)
const RS_REGION_VISIBILITY_SETTINGS := preload(
	"res://scripts/resources/display/vcam/rs_region_visibility_settings.gd"
)

class MaterialApplierStub extends RefCounted:
	var apply_calls: int = 0
	var update_calls: int = 0
	var restore_calls: int = 0
	var last_updated_alpha: float = -1.0
	var last_updated_target_count: int = 0
	var last_restore_target_count: int = 0
	var updated_alpha_by_target_id: Dictionary = {}

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

func _region_visibility_system_script() -> Script:
	var script_obj := load(REGION_VISIBILITY_SYSTEM_PATH) as Script
	assert_not_null(script_obj, "Region visibility system should load: %s" % REGION_VISIBILITY_SYSTEM_PATH)
	return script_obj

# --- Core Gating ---

func test_execution_priority_is_100() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)
	assert_eq(int(system.get("execution_priority")), 100)

func test_noop_when_no_components() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: MaterialApplierStub = fixture.get("applier") as MaterialApplierStub
	assert_not_null(system)
	assert_not_null(applier)

	system.process_tick(0.1)
	assert_eq(applier.apply_calls, 0)
	assert_eq(applier.update_calls, 0)
	assert_eq(applier.restore_calls, 0)

func test_noop_in_non_orbit_mode() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: MaterialApplierStub = fixture.get("applier") as MaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	store.set_slice("vcam", {"active_mode": "custom_mode"})
	_register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	system.process_tick(0.1)

	assert_eq(applier.apply_calls, 0)
	assert_eq(applier.update_calls, 0)

func test_restores_opaque_when_leaving_orbit() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: MaterialApplierStub = fixture.get("applier") as MaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a")
	_set_player_position(store, Vector3.ZERO)
	system.process_tick(0.1)
	var component = setup.get("component")
	assert_lt(component.current_alpha, 1.0, "Should have faded inactive region.")

	store.set_slice("vcam", {"active_mode": "custom_mode"})
	system.process_tick(0.1)
	assert_almost_eq(component.current_alpha, 1.0, 0.0001, "Should restore to opaque.")
	assert_gt(applier.restore_calls, 0, "Should call restore.")

# --- Player Detection ---

func test_player_inside_region_marks_active() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	_set_player_position(store, Vector3.ZERO)
	system.process_tick(0.1)

	var component = setup.get("component")
	assert_true(component.is_active_region, "Player is inside region AABB.")

func test_player_outside_region_marks_inactive() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	_set_player_position(store, Vector3(100.0, 0.0, 100.0))
	system.process_tick(0.1)

	var component = setup.get("component")
	assert_false(component.is_active_region, "Player is far from region.")

# --- Fade Logic ---

func test_active_region_stays_opaque() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(0.1)
	system.process_tick(0.1)
	system.process_tick(0.1)

	var component = setup.get("component")
	assert_almost_eq(component.current_alpha, 1.0, 0.0001)

func test_inactive_region_fades_toward_min_alpha() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a")
	_set_player_position(store, Vector3.ZERO)

	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.fade_speed = 2.0
	settings.min_alpha = 0.0
	var component = setup.get("component")
	component.settings = settings

	system.process_tick(0.25)
	assert_almost_eq(component.current_alpha, 0.5, 0.0001)

func test_fade_speed_controls_rate() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a")
	_set_player_position(store, Vector3.ZERO)

	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.fade_speed = 4.0
	settings.min_alpha = 0.0
	var component = setup.get("component")
	component.settings = settings

	system.process_tick(0.1)
	assert_almost_eq(component.current_alpha, 0.6, 0.0001, "4.0 * 0.1 = 0.4 decrease from 1.0")

func test_min_alpha_respected() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a")
	_set_player_position(store, Vector3.ZERO)

	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.fade_speed = 100.0
	settings.min_alpha = 0.2
	var component = setup.get("component")
	component.settings = settings

	system.process_tick(1.0)
	assert_almost_eq(component.current_alpha, 0.2, 0.0001)

func test_region_switch_fades_old_unfades_new() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup_a := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var setup_b := _register_region(ecs_manager, "E_RegionB", Vector3(100.0, 0.0, 0.0), &"region_b")

	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.fade_speed = 100.0
	settings.min_alpha = 0.0
	(setup_a.get("component")).settings = settings
	(setup_b.get("component")).settings = settings

	_set_player_position(store, Vector3.ZERO)
	system.process_tick(1.0)
	assert_almost_eq((setup_a.get("component")).current_alpha, 1.0, 0.0001)
	assert_almost_eq((setup_b.get("component")).current_alpha, 0.0, 0.001)

	_set_player_position(store, Vector3(100.0, 0.0, 0.0))
	system.process_tick(1.0)
	assert_almost_eq((setup_b.get("component")).current_alpha, 1.0, 0.0001)
	assert_almost_eq((setup_a.get("component")).current_alpha, 0.0, 0.001)

# --- Material Applier ---

func test_applier_called_for_inactive_regions() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: MaterialApplierStub = fixture.get("applier") as MaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a")
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(0.1)
	assert_gt(applier.apply_calls, 0, "Should apply fade material to inactive region.")
	assert_gt(applier.update_calls, 0, "Should update fade alpha on inactive region.")

func test_applier_not_called_for_active_region() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: MaterialApplierStub = fixture.get("applier") as MaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(0.1)
	assert_eq(applier.apply_calls, 0, "Should not apply fade to active region at full alpha.")
	assert_eq(applier.update_calls, 0, "Should not update fade on active region at full alpha.")

func test_stale_targets_restored() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: MaterialApplierStub = fixture.get("applier") as MaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a")
	_set_player_position(store, Vector3.ZERO)
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 0)

	ecs_manager.clear_all_components()
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 1)

# --- Edge Cases ---

func test_no_player_position_all_regions_opaque() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	system.process_tick(0.1)

	var component = setup.get("component")
	assert_almost_eq(component.current_alpha, 1.0, 0.0001, "No player data should keep regions opaque.")
	assert_true(component.is_active_region)

func test_overlapping_regions_both_active() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup_a := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var setup_b := _register_region(ecs_manager, "E_RegionB", Vector3(1.0, 0.0, 0.0), &"region_b")
	_set_player_position(store, Vector3(0.5, 0.0, 0.0))

	system.process_tick(0.1)
	assert_true((setup_a.get("component")).is_active_region)
	assert_true((setup_b.get("component")).is_active_region)

func test_null_component_no_crash() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)
	system.process_tick(0.1)
	assert_true(true, "No crash on empty tick.")

# --- Public Queries ---

func test_get_active_region_tags() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	_register_region(ecs_manager, "E_RegionB", Vector3(100.0, 0.0, 0.0), &"region_b")
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(0.1)
	var active_tags: Array = system.get_active_region_tags()
	assert_true(active_tags.has(&"region_a"))
	assert_false(active_tags.has(&"region_b"))

func test_is_region_faded() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	_register_region(ecs_manager, "E_RegionB", Vector3(100.0, 0.0, 0.0), &"region_b")
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(0.1)
	assert_false(bool(system.is_region_faded(&"region_a")), "Active region should not be faded.")
	assert_true(bool(system.is_region_faded(&"region_b")), "Inactive region should be faded.")

# --- Three-Tier Zones ---

func test_player_in_inner_zone_is_active_not_near() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 6.0
	settings.fade_speed = 100.0
	(setup.get("component")).settings = settings
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(1.0)
	var component = setup.get("component")
	assert_true(component.is_active_region, "Player at origin should be in inner zone.")
	assert_false(component.is_near_region, "Player in inner zone should not be near.")
	assert_almost_eq(component.current_alpha, 1.0, 0.0001)

func test_player_in_outer_zone_is_near_not_active() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 6.0
	settings.near_alpha = 0.5
	settings.fade_speed = 100.0
	(setup.get("component")).settings = settings
	_set_player_position(store, Vector3(2.0, 0.0, 0.0))

	system.process_tick(1.0)
	var component = setup.get("component")
	assert_false(component.is_active_region, "Player at 2.0 should be outside inner zone (grow=1.0).")
	assert_true(component.is_near_region, "Player at 2.0 should be inside outer zone (grow=3.0).")

func test_player_outside_both_zones_is_neither() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 6.0
	(setup.get("component")).settings = settings
	_set_player_position(store, Vector3(100.0, 0.0, 0.0))

	system.process_tick(0.1)
	var component = setup.get("component")
	assert_false(component.is_active_region)
	assert_false(component.is_near_region)

func test_near_region_fades_to_near_alpha() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 6.0
	settings.near_alpha = 0.5
	settings.fade_speed = 100.0
	(setup.get("component")).settings = settings
	_set_player_position(store, Vector3(2.0, 0.0, 0.0))

	system.process_tick(1.0)
	var component = setup.get("component")
	assert_almost_eq(component.current_alpha, 0.5, 0.0001, "Near region should fade to near_alpha.")

func test_far_region_fades_to_min_alpha() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 6.0
	settings.min_alpha = 0.1
	settings.fade_speed = 100.0
	(setup.get("component")).settings = settings
	_set_player_position(store, Vector3(100.0, 0.0, 0.0))

	system.process_tick(1.0)
	var component = setup.get("component")
	assert_almost_eq(component.current_alpha, 0.1, 0.0001, "Far region should fade to min_alpha.")

func test_transition_near_to_active() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 6.0
	settings.near_alpha = 0.5
	settings.fade_speed = 100.0
	(setup.get("component")).settings = settings

	_set_player_position(store, Vector3(2.0, 0.0, 0.0))
	system.process_tick(1.0)
	var component = setup.get("component")
	assert_almost_eq(component.current_alpha, 0.5, 0.0001, "Should be at near_alpha.")

	_set_player_position(store, Vector3.ZERO)
	system.process_tick(1.0)
	assert_almost_eq(component.current_alpha, 1.0, 0.0001, "Should fade up to opaque.")

func test_transition_active_to_near() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 6.0
	settings.near_alpha = 0.5
	settings.fade_speed = 100.0
	(setup.get("component")).settings = settings

	_set_player_position(store, Vector3.ZERO)
	system.process_tick(1.0)
	var component = setup.get("component")
	assert_almost_eq(component.current_alpha, 1.0, 0.0001)

	_set_player_position(store, Vector3(2.0, 0.0, 0.0))
	system.process_tick(1.0)
	assert_almost_eq(component.current_alpha, 0.5, 0.0001, "Should fade down to near_alpha.")

func test_get_near_region_tags() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var settings_a := RS_REGION_VISIBILITY_SETTINGS.new()
	settings_a.inner_aabb_grow = 1.0
	settings_a.aabb_grow = 3.0
	var setup_a := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	(setup_a.get("component")).settings = settings_a

	var settings_b := RS_REGION_VISIBILITY_SETTINGS.new()
	settings_b.inner_aabb_grow = 1.0
	settings_b.aabb_grow = 5.0
	var setup_b := _register_region(ecs_manager, "E_RegionB", Vector3(4.0, 0.0, 0.0), &"region_b")
	(setup_b.get("component")).settings = settings_b

	_set_player_position(store, Vector3.ZERO)
	system.process_tick(0.1)

	var near_tags: Array = system.get_near_region_tags()
	assert_false(near_tags.has(&"region_a"), "Active region should not be in near tags.")
	assert_true(near_tags.has(&"region_b"), "Region_b at 4.0 away with outer grow=5.0 should be near.")

func test_active_tags_exclude_near() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 5.0
	var setup_a := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	(setup_a.get("component")).settings = settings

	var settings_b := RS_REGION_VISIBILITY_SETTINGS.new()
	settings_b.inner_aabb_grow = 1.0
	settings_b.aabb_grow = 5.0
	var setup_b := _register_region(ecs_manager, "E_RegionB", Vector3(4.0, 0.0, 0.0), &"region_b")
	(setup_b.get("component")).settings = settings_b

	_set_player_position(store, Vector3.ZERO)
	system.process_tick(0.1)

	var active_tags: Array = system.get_active_region_tags()
	assert_true(active_tags.has(&"region_a"))
	assert_false(active_tags.has(&"region_b"), "Near region should not be in active tags.")

func test_applier_called_for_near_regions() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: MaterialApplierStub = fixture.get("applier") as MaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var setup := _register_region(ecs_manager, "E_RegionA", Vector3.ZERO, &"region_a")
	var settings := RS_REGION_VISIBILITY_SETTINGS.new()
	settings.inner_aabb_grow = 1.0
	settings.aabb_grow = 6.0
	settings.near_alpha = 0.5
	settings.fade_speed = 100.0
	(setup.get("component")).settings = settings
	_set_player_position(store, Vector3(2.0, 0.0, 0.0))

	system.process_tick(1.0)
	assert_gt(applier.apply_calls, 0, "Should apply fade material to near region.")
	assert_gt(applier.update_calls, 0, "Should update fade alpha on near region.")
	assert_almost_eq(applier.last_updated_alpha, 0.5, 0.0001, "Alpha should be near_alpha.")

# --- Fixture Helpers ---

func _create_fixture() -> Dictionary:
	var system_script := _region_visibility_system_script()
	if system_script == null:
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

	var applier := MaterialApplierStub.new()

	var system: Variant = system_script.new()
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

func _register_region(
	ecs_manager: MockECSManager,
	entity_name: String,
	world_position: Vector3,
	tag: StringName
) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)
	entity.global_position = world_position

	var component := C_REGION_VISIBILITY_COMPONENT.new()
	component.region_tag = tag
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
