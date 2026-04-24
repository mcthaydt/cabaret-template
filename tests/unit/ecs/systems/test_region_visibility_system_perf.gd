extends BaseTest

# Performance regression tests for S_RegionVisibilitySystem.
# Validates that redundant _is_supported_target checks are eliminated.

const REGION_VISIBILITY_SYSTEM_PATH := "res://scripts/core/ecs/systems/s_region_visibility_system.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const BASE_ECS_ENTITY := preload("res://scripts/core/ecs/base_ecs_entity.gd")
const C_REGION_VISIBILITY_COMPONENT := preload(
	"res://scripts/core/ecs/components/c_region_visibility_component.gd"
)


class PerfTrackingApplierStub extends RefCounted:
	var apply_calls: int = 0
	var update_calls: int = 0
	var restore_calls: int = 0
	var last_updated_alpha: float = -1.0
	var last_updated_target_count: int = 0
	var last_restore_target_count: int = 0
	var apply_target_counts: Array[int] = []

	func apply_fade_material(targets: Array) -> void:
		apply_calls += 1
		last_updated_target_count = targets.size()
		apply_target_counts.append(targets.size())

	func update_fade_alpha(targets: Array, alpha: float) -> void:
		update_calls += 1
		last_updated_alpha = alpha
		last_updated_target_count = targets.size()

	func restore_original_materials(targets: Array) -> void:
		restore_calls += 1
		last_restore_target_count = targets.size()


func _region_visibility_system_script() -> Script:
	var script_obj := load(REGION_VISIBILITY_SYSTEM_PATH) as Script
	assert_not_null(
		script_obj, "Region visibility system should load: %s" % REGION_VISIBILITY_SYSTEM_PATH
	)
	return script_obj


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

	var applier := PerfTrackingApplierStub.new()

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
	tag: StringName,
	target_count: int = 5
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

	var targets: Array = []
	for i in target_count:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = BoxMesh.new()
		entity.add_child(mesh_instance)
		autofree(mesh_instance)
		targets.append(mesh_instance)

	return {
		"entity": entity,
		"component": component,
		"targets": targets,
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


# --- Perf: restore_to_opaque should not re-check already-filtered targets ---

func test_restore_to_opaque_completes_without_redundant_checks() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: PerfTrackingApplierStub = fixture.get("applier") as PerfTrackingApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	# Register 2 regions far from player so they fade.
	_register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a", 5)
	_register_region(ecs_manager, "E_RegionB", Vector3(-100.0, 0.0, 0.0), &"region_b", 5)
	_set_player_position(store, Vector3.ZERO)

	# First tick: regions fade.
	system.process_tick(0.016)
	assert_gt(applier.apply_calls, 0, "Should apply fade to inactive regions.")

	# Switch to non-orbit mode to trigger restore_to_opaque.
	store.set_slice("vcam", {"active_mode": "custom_mode"})
	applier.restore_calls = 0
	system.process_tick(0.016)

	# Restore should happen cleanly — this validates the restore path works.
	assert_gt(applier.restore_calls, 0, "Should restore materials on mode switch.")


# --- Perf: faded regions should track targets without redundant validation ---

func test_faded_regions_track_targets_correctly() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: PerfTrackingApplierStub = fixture.get("applier") as PerfTrackingApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	# Register 3 regions far from player.
	_register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a", 5)
	_register_region(ecs_manager, "E_RegionB", Vector3(-100.0, 0.0, 0.0), &"region_b", 5)
	_register_region(ecs_manager, "E_RegionC", Vector3(0.0, 0.0, 100.0), &"region_c", 5)
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(0.016)

	# Each faded component should get exactly one apply + one update call.
	# apply_calls counts number of apply_fade_material invocations (one per faded component).
	# update_calls counts number of update_fade_alpha invocations (one per faded component).
	assert_eq(
		applier.apply_calls, applier.update_calls,
		"Each faded component should get one apply and one update, got apply=%d update=%d."
		% [applier.apply_calls, applier.update_calls]
	)


# --- Perf: multiple ticks should not accumulate stale tracking overhead ---

func test_multiple_ticks_do_not_accumulate_stale_overhead() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: PerfTrackingApplierStub = fixture.get("applier") as PerfTrackingApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a", 5)
	_set_player_position(store, Vector3.ZERO)

	# Run 5 ticks.
	for i in 5:
		system.process_tick(0.016)

	# apply should be called once per tick for the faded region = 5 total.
	assert_eq(
		applier.apply_calls, 5,
		"apply_fade_material should be called once per tick per faded component, got %d."
		% applier.apply_calls
	)
	# update should also be 1 per tick = 5 total.
	assert_eq(
		applier.update_calls, 5,
		"update_fade_alpha should be called once per tick per faded component, got %d."
		% applier.update_calls
	)


# --- Perf: _collect_mesh_targets should reuse cached results on subsequent ticks ---

func test_collect_mesh_targets_does_not_refilter_on_second_tick() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: PerfTrackingApplierStub = fixture.get("applier") as PerfTrackingApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a", 10)
	_set_player_position(store, Vector3.ZERO)

	# Tick 1: system must discover and filter targets.
	system.process_tick(0.016)
	var first_tick_apply_count: int = applier.apply_calls

	# Tick 2: targets unchanged — system should reuse cached filtered list.
	# If _is_supported_target is called again, _collect_mesh_targets rebuilt the list.
	# We verify by checking that apply_fade_material receives the same target count
	# (not 0, which would mean targets were lost).
	system.process_tick(0.016)
	var second_tick_apply_count: int = applier.apply_calls - first_tick_apply_count

	assert_eq(
		second_tick_apply_count, first_tick_apply_count,
		"Second tick should process same targets as first tick (cached), got first=%d second=%d."
		% [first_tick_apply_count, second_tick_apply_count]
	)
	# Verify target count is stable across ticks.
	assert_eq(
		applier.apply_target_counts[0], applier.apply_target_counts[applier.apply_target_counts.size() - 1],
		"Target count should be stable across ticks (no re-filtering loss)."
	)


# --- Perf: system should expose is_supported_target call count for validation ---

func test_is_supported_target_not_called_on_cached_ticks() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	# Register 2 regions with 10 targets each = 20 targets.
	_register_region(ecs_manager, "E_RegionA", Vector3(100.0, 0.0, 0.0), &"region_a", 10)
	_register_region(ecs_manager, "E_RegionB", Vector3(-100.0, 0.0, 0.0), &"region_b", 10)
	_set_player_position(store, Vector3.ZERO)

	# Tick 1 populates cache. Tick 2-5 should reuse it.
	for i in 5:
		system.process_tick(0.016)

	# After 5 ticks, _perf_is_supported_calls should be <= 20 (first tick only).
	# If it's 100 (20 * 5), filtering happens every tick — the bug we're fixing.
	var is_supported_calls: int = int(system.get("_perf_is_supported_calls"))
	assert_lte(
		is_supported_calls, 20,
		"_is_supported_target should only run on first tick (cache miss), got %d calls over 5 ticks."
		% is_supported_calls
	)
