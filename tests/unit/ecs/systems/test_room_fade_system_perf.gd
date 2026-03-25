extends BaseTest

# Performance regression tests for S_RoomFadeSystem.
# Validates that hot-path functions are not called redundantly per tick.

const ROOM_FADE_SYSTEM_PATH := "res://scripts/ecs/systems/s_room_fade_system.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_ROOM_FADE_GROUP_COMPONENT := preload(
	"res://scripts/ecs/components/c_room_fade_group_component.gd"
)
const RS_ROOM_FADE_SETTINGS := preload(
	"res://scripts/resources/display/vcam/rs_room_fade_settings.gd"
)


class PerfTrackingApplierStub extends RefCounted:
	var apply_calls: int = 0
	var update_calls: int = 0
	var update_single_calls: int = 0
	var invalidate_calls: int = 0
	var restore_calls: int = 0
	var last_updated_alpha: float = -1.0
	var last_updated_target_count: int = 0
	var last_restore_target_count: int = 0
	var updated_alpha_by_target_id: Dictionary = {}

	func invalidate_externally_removed() -> void:
		invalidate_calls += 1

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

	func update_single_fade_alpha(target: Node3D, alpha: float) -> void:
		update_single_calls += 1
		if target != null:
			updated_alpha_by_target_id[target.get_instance_id()] = alpha

	func restore_original_materials(targets: Array) -> void:
		restore_calls += 1
		last_restore_target_count = targets.size()

	func get_cached_mesh_count() -> int:
		return 0


func _room_fade_system_script() -> Script:
	var script_obj := load(ROOM_FADE_SYSTEM_PATH) as Script
	assert_not_null(script_obj, "Room fade system should load: %s" % ROOM_FADE_SYSTEM_PATH)
	return script_obj


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

	var applier := PerfTrackingApplierStub.new()

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


func _register_room_fade_group(
	ecs_manager: MockECSManager,
	entity_name: String,
	target_count: int = 3
) -> Variant:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	for i in target_count:
		var csg_wall := CSGBox3D.new()
		csg_wall.position = Vector3(float(i) * 2.0, 0.0, 0.0)
		entity.add_child(csg_wall)
		autofree(csg_wall)

	return component


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


# --- Perf: invalidate_externally_removed should be called at most once per tick ---

func test_invalidate_externally_removed_not_called_per_component() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: PerfTrackingApplierStub = fixture.get("applier") as PerfTrackingApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	# Register 3 components so the component loop runs 3 times.
	_register_room_fade_group(ecs_manager, "E_RoomA", 5)
	_register_room_fade_group(ecs_manager, "E_RoomB", 5)
	_register_room_fade_group(ecs_manager, "E_RoomC", 5)
	_set_player_position(store, Vector3.ZERO)

	# Run 30 ticks to ensure at least one invalidate fires.
	for i in 30:
		system.process_tick(0.016)

	# Should be called at most once per tick (not per component).
	# With 3 components and 30 ticks, if called per component it would be 90.
	assert_lte(
		applier.invalidate_calls, 30,
		"invalidate_externally_removed should be at most once per tick, not per component (%d)."
		% applier.invalidate_calls
	)
	assert_gt(
		applier.invalidate_calls, 0,
		"invalidate_externally_removed should be called at least once over 30 ticks."
	)


# --- Perf: update_fade_alpha should use single-target API ---

func test_update_uses_single_target_api_not_array_wrapping() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: PerfTrackingApplierStub = fixture.get("applier") as PerfTrackingApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_room_fade_group(ecs_manager, "E_RoomA", 5)
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(0.016)

	assert_gt(
		applier.update_single_calls, 0,
		"System should use update_single_fade_alpha for per-target updates."
	)
	assert_eq(
		applier.update_calls, 0,
		"System should not use update_fade_alpha with single-element array wrapping (%d calls)."
		% applier.update_calls
	)


# --- Perf: apply_fade_material should be called once per component ---

func test_apply_fade_material_called_once_per_component() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: PerfTrackingApplierStub = fixture.get("applier") as PerfTrackingApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_room_fade_group(ecs_manager, "E_RoomA", 5)
	_register_room_fade_group(ecs_manager, "E_RoomB", 5)
	_register_room_fade_group(ecs_manager, "E_RoomC", 5)
	_set_player_position(store, Vector3.ZERO)

	system.process_tick(0.016)

	# apply_fade_material should be called at most once per owned component.
	# Some components may be filtered out by active room check, so <= 3.
	assert_lte(
		applier.apply_calls, 3,
		"apply_fade_material should be called at most once per component, got %d."
		% applier.apply_calls
	)


# --- Perf: _is_supported_target should only run on cache miss (first tick) ---

func test_is_supported_target_not_called_on_cached_ticks() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	# Register 2 groups with 5 targets each = 10 targets.
	_register_room_fade_group(ecs_manager, "E_RoomA", 5)
	_register_room_fade_group(ecs_manager, "E_RoomB", 5)
	_set_player_position(store, Vector3.ZERO)

	# Tick 1 populates cache. Ticks 2-5 should reuse it.
	for i in 5:
		system.process_tick(0.016)

	# After 5 ticks, _perf_is_supported_calls should be <= 10 (first tick only).
	# If it's 50 (10 * 5), filtering happens every tick — the bug we're fixing.
	var is_supported_calls: int = int(system.get("_perf_is_supported_calls"))
	assert_lte(
		is_supported_calls, 10,
		"_is_supported_target should only run on first tick (cache miss), got %d calls over 5 ticks."
		% is_supported_calls
	)


# --- Perf: invalidate_externally_removed should be throttled ---

func test_invalidate_externally_removed_throttled_over_multiple_ticks() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: PerfTrackingApplierStub = fixture.get("applier") as PerfTrackingApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_register_room_fade_group(ecs_manager, "E_RoomA", 5)
	_set_player_position(store, Vector3.ZERO)

	# Run 60 ticks.
	for i in 60:
		system.process_tick(0.016)

	# invalidate_externally_removed should NOT be called every tick.
	# With throttling, it should be called significantly fewer than 60 times.
	assert_lt(
		applier.invalidate_calls, 60,
		"invalidate_externally_removed should be throttled, not called every tick (%d calls in 60 ticks)."
		% applier.invalidate_calls
	)
