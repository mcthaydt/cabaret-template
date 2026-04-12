extends BaseTest

# C5 Decomposition tests — test extracted methods independently.
# These methods are extracted from process_tick to decompose the god method.

const WALL_VISIBILITY_SYSTEM_PATH := "res://scripts/ecs/systems/s_wall_visibility_system.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_ROOM_FADE_GROUP_COMPONENT := preload("res://scripts/ecs/components/c_room_fade_group_component.gd")


class WallVisibilityApplierStub extends RefCounted:
	var apply_calls: int = 0
	var restore_calls: int = 0
	var invalidate_calls: int = 0

	func invalidate_externally_removed() -> void:
		invalidate_calls += 1

	func apply_visibility_material(_targets: Array) -> void:
		apply_calls += 1

	func update_uniforms(_target: Node3D, _clip_y: float, _fade: float) -> void:
		pass

	func restore_original_materials(_targets: Array) -> void:
		restore_calls += 1

	func get_cached_mesh_count() -> int:
		return 0


func _wall_visibility_system_script() -> Script:
	var script_obj := load(WALL_VISIBILITY_SYSTEM_PATH) as Script
	assert_not_null(script_obj, "Wall visibility system should load: %s" % WALL_VISIBILITY_SYSTEM_PATH)
	return script_obj


func _create_fixture() -> Dictionary:
	var system_script := _wall_visibility_system_script()
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

	var applier := WallVisibilityApplierStub.new()

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


# --- _resolve_tick_data tests ---

func test_resolve_tick_data_returns_orbit_mode() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	var tick_data: Dictionary = system._resolve_tick_data(0.1, 1)
	assert_true(bool(tick_data.get("is_orbit", false)),
		"_resolve_tick_data should return is_orbit=true when in orbit mode.")


func test_resolve_tick_data_returns_camera_data() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	var tick_data: Dictionary = system._resolve_tick_data(0.1, 1)
	assert_true(bool(tick_data.get("camera_valid", false)),
		"_resolve_tick_data should return camera_valid=true when camera exists.")
	assert_eq(tick_data.get("applier", null), fixture.get("applier"),
		"_resolve_tick_data should return the resolved applier.")


func test_resolve_tick_data_returns_player_data() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	# Set player position in state
	store.set_slice("gameplay", {
		"player_entity_id": "player",
		"entities": {
			"player": {"entity_type": "player", "position": Vector3(1.0, 2.0, 3.0)}
		}
	})

	var tick_data: Dictionary = system._resolve_tick_data(0.1, 1)
	assert_true(bool(tick_data.get("has_player", false)),
		"_resolve_tick_data should return has_player=true when player exists.")
	var player_pos: Vector3 = tick_data.get("player_position", Vector3.ZERO) as Vector3
	assert_almost_eq(player_pos.x, 1.0, 0.001,
		"_resolve_tick_data should return correct player_position.x.")


func test_resolve_tick_data_returns_not_orbit_when_custom_mode() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	store.set_slice("vcam", {"active_mode": "custom_mode"})

	var tick_data: Dictionary = system._resolve_tick_data(0.1, 1)
	assert_false(bool(tick_data.get("is_orbit", true)),
		"_resolve_tick_data should return is_orbit=false when not in orbit mode.")


func test_resolve_tick_data_returns_camera_invalid_when_no_camera() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	var main_camera: Camera3D = fixture.get("main_camera") as Camera3D
	assert_not_null(system)

	camera_manager.main_camera = null
	remove_child(main_camera)

	var tick_data: Dictionary = system._resolve_tick_data(0.1, 1)
	assert_false(bool(tick_data.get("camera_valid", true)),
		"_resolve_tick_data should return camera_valid=false when camera is null.")


func test_resolve_tick_data_returns_resolved_delta() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	var tick_data: Dictionary = system._resolve_tick_data(0.25, 2)
	var resolved_delta: float = float(tick_data.get("resolved_delta", 0.0))
	# resolved_delta = maxf(0.25, 0.0) * 2 = 0.5
	assert_almost_eq(resolved_delta, 0.5, 0.001,
		"_resolve_tick_data should compensate resolved_delta for tick interval.")


func test_resolve_tick_data_returns_mobile_hide_flag() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	system._is_mobile = true
	system.mobile_hide_walls_instead_of_fade = true

	var tick_data: Dictionary = system._resolve_tick_data(0.1, 1)
	assert_true(bool(tick_data.get("use_mobile_hide", false)),
		"_resolve_tick_data should return use_mobile_hide=true when mobile hide mode.")


# --- _filter_rooms_by_aabb tests ---

func test_filter_rooms_returns_all_when_no_player() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component_a: Variant = _register_room_fade_group(ecs_manager, "E_FilterA")
	var component_b: Variant = _register_room_fade_group(ecs_manager, "E_FilterB")
	var components: Array = [component_a, component_b]
	var targets_by_id: Dictionary = {}

	var result: Array = system._filter_rooms_by_aabb(components, targets_by_id, Vector3.ZERO, false)
	assert_eq(result.size(), 2,
		"_filter_rooms_by_aabb should return all components when has_player=false.")


func test_filter_rooms_returns_all_when_single_component() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_FilterSingle")
	var components: Array = [component]
	var targets_by_id: Dictionary = {}

	var result: Array = system._filter_rooms_by_aabb(components, targets_by_id, Vector3(100.0, 0.0, 100.0), true)
	assert_eq(result.size(), 1,
		"_filter_rooms_by_aabb should return all when only one component regardless of player position.")


func test_filter_rooms_returns_matching_when_player_in_room() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	# Room A: player is inside
	var component_a: Variant = _register_room_fade_group(ecs_manager, "E_RoomFilterA")
	var entity_a: Node = (component_a as Object).get_parent() as Node
	entity_a.position = Vector3(0.0, 0.0, 0.0)

	# Room B: far away
	var component_b: Variant = _register_room_fade_group(ecs_manager, "E_RoomFilterB")
	var entity_b: Node = (component_b as Object).get_parent() as Node
	entity_b.position = Vector3(100.0, 0.0, 100.0)

	var components: Array = [component_a, component_b]
	var targets_by_id: Dictionary = {}
	# Populate targets_by_id with actual mesh targets
	for comp in components:
		if comp is Object and comp.has_method("collect_mesh_targets"):
			var comp_id: int = (comp as Object).get_instance_id()
			var targets: Array = comp.call("collect_mesh_targets") as Array
			targets_by_id[comp_id] = targets

	var result: Array = system._filter_rooms_by_aabb(components, targets_by_id, Vector3(0.0, 0.0, 0.0), true)
	assert_eq(result.size(), 1,
		"_filter_rooms_by_aabb should return only the room containing the player.")


func test_filter_rooms_falls_back_to_all_when_no_match() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component_a: Variant = _register_room_fade_group(ecs_manager, "E_RoomFilterC")
	var component_b: Variant = _register_room_fade_group(ecs_manager, "E_RoomFilterD")
	var components: Array = [component_a, component_b]
	var targets_by_id: Dictionary = {}
	for comp in components:
		if comp is Object and comp.has_method("collect_mesh_targets"):
			var comp_id: int = (comp as Object).get_instance_id()
			targets_by_id[comp_id] = comp.call("collect_mesh_targets") as Array

	# Player far from both rooms
	var result: Array = system._filter_rooms_by_aabb(components, targets_by_id, Vector3(999.0, 999.0, 999.0), true)
	assert_eq(result.size(), 2,
		"_filter_rooms_by_aabb should fall back to all components when no room matches.")


# --- _deduplicate_targets tests ---

func test_deduplicate_assigns_first_owner() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	# Suppress duplicate-target warnings
	var _warnings: Array = []
	system.duplicate_target_warning_handler = func(msg: String) -> void:
		_warnings.append(msg)

	var component_a: Variant = _register_room_fade_group(ecs_manager, "E_DedupA")
	var component_b: Variant = _register_room_fade_group(ecs_manager, "E_DedupB")
	var component_a_obj: Object = component_a as Object
	var component_b_obj: Object = component_b as Object

	# Shared target node
	var shared_mesh := MeshInstance3D.new()
	shared_mesh.mesh = BoxMesh.new()
	shared_mesh.name = "SharedDedupWall"
	add_child(shared_mesh)
	autofree(shared_mesh)

	var comp_a_id: int = component_a_obj.get_instance_id()
	var comp_b_id: int = component_b_obj.get_instance_id()

	var targets_by_id: Dictionary = {}
	targets_by_id[comp_a_id] = [shared_mesh]
	targets_by_id[comp_b_id] = [shared_mesh]  # same target in both

	var matching: Array = [component_a, component_b]
	var result: Dictionary = system._deduplicate_targets(matching, targets_by_id)

	# First component should own the target
	var owned_a: Array = result.get(comp_a_id, []) as Array
	var owned_b: Array = result.get(comp_b_id, []) as Array
	assert_eq(owned_a.size(), 1,
		"First component should own the shared target.")
	assert_eq(owned_b.size(), 0,
		"Second component should not own the shared target (first-owner-wins).")


func test_deduplicate_no_duplicates_all_kept() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component_a: Variant = _register_room_fade_group(ecs_manager, "E_DedupC")
	var component_b: Variant = _register_room_fade_group(ecs_manager, "E_DedupD")
	var comp_a_id: int = (component_a as Object).get_instance_id()
	var comp_b_id: int = (component_b as Object).get_instance_id()

	var targets_by_id: Dictionary = {}
	var targets_a: Array = []
	if component_a is Object and component_a.has_method("collect_mesh_targets"):
		targets_a = component_a.call("collect_mesh_targets") as Array
	targets_by_id[comp_a_id] = targets_a
	var targets_b: Array = []
	if component_b is Object and component_b.has_method("collect_mesh_targets"):
		targets_b = component_b.call("collect_mesh_targets") as Array
	targets_by_id[comp_b_id] = targets_b

	var matching: Array = [component_a, component_b]
	var result: Dictionary = system._deduplicate_targets(matching, targets_by_id)

	var owned_a: Array = result.get(comp_a_id, []) as Array
	var owned_b: Array = result.get(comp_b_id, []) as Array
	assert_eq(owned_a.size(), targets_a.size(),
		"Component A should keep all targets when no duplicates.")
	assert_eq(owned_b.size(), targets_b.size(),
		"Component B should keep all targets when no duplicates.")


func test_deduplicate_empty_components_returns_empty() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	var result: Dictionary = system._deduplicate_targets([], {})
	assert_eq(result.size(), 0,
		"_deduplicate_targets should return empty dict for empty input.")


# --- _apply_wall_materials tests ---

func test_apply_wall_materials_calls_apply_for_non_mobile() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	assert_not_null(system)

	var targets: Array = [MeshInstance3D.new()]
	autofree(targets[0])

	system._apply_wall_materials(applier, targets, false)
	assert_eq(applier.apply_calls, 1,
		"_apply_wall_materials should call apply_visibility_material for non-mobile hide mode.")
	assert_eq(applier.restore_calls, 0,
		"_apply_wall_materials should NOT call restore for non-mobile hide mode.")


func test_apply_wall_materials_calls_restore_for_mobile_hide() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	assert_not_null(system)

	var targets: Array = [MeshInstance3D.new()]
	autofree(targets[0])

	system._apply_wall_materials(applier, targets, true)
	assert_eq(applier.apply_calls, 0,
		"_apply_wall_materials should NOT call apply_visibility_material for mobile hide mode.")
	assert_eq(applier.restore_calls, 1,
		"_apply_wall_materials should call restore_original_materials for mobile hide mode.")


func test_apply_wall_materials_noop_with_empty_targets() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	assert_not_null(system)

	system._apply_wall_materials(applier, [], false)
	assert_eq(applier.apply_calls, 0,
		"_apply_wall_materials should be a noop with empty targets.")
	assert_eq(applier.restore_calls, 0,
		"_apply_wall_materials should be a noop with empty targets.")


# --- _detect_roofs tests ---

func test_detect_roofs_flags_upward_normal_above_player() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	# Target above player with upward normal
	var roof_target := CSGBox3D.new()
	roof_target.position = Vector3(0.0, 3.0, 0.0)
	add_child(roof_target)
	autofree(roof_target)

	var targets: Array = [roof_target]
	var normals: Array = [Vector3(0.0, 1.0, 0.0)]

	var results: Array = system._detect_roofs(targets, normals, true, Vector3(0.0, 0.0, 0.0))
	assert_eq(results.size(), 1,
		"_detect_roofs should return same count as targets.")
	assert_true(bool(results[0]),
		"_detect_roofs should flag upward-normal target above player as roof.")


func test_detect_roofs_does_not_flag_wall_normal() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	var wall_target := CSGBox3D.new()
	wall_target.position = Vector3(0.0, 1.0, 0.0)
	add_child(wall_target)
	autofree(wall_target)

	var targets: Array = [wall_target]
	var normals: Array = [Vector3(0.0, 0.0, -1.0)]

	var results: Array = system._detect_roofs(targets, normals, true, Vector3(0.0, 0.0, 0.0))
	assert_false(bool(results[0]),
		"_detect_roofs should NOT flag wall-normal target as roof.")


func test_detect_roofs_does_not_flag_below_player() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	var floor_target := CSGBox3D.new()
	floor_target.position = Vector3(0.0, -1.0, 0.0)
	add_child(floor_target)
	autofree(floor_target)

	var targets: Array = [floor_target]
	var normals: Array = [Vector3(0.0, 1.0, 0.0)]

	var results: Array = system._detect_roofs(targets, normals, true, Vector3(0.0, 0.0, 0.0))
	assert_false(bool(results[0]),
		"_detect_roofs should NOT flag upward target below player as roof.")


func test_detect_roofs_no_player_all_false() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	var target := CSGBox3D.new()
	target.position = Vector3(0.0, 5.0, 0.0)
	add_child(target)
	autofree(target)

	var targets: Array = [target]
	var normals: Array = [Vector3(0.0, 1.0, 0.0)]

	var results: Array = system._detect_roofs(targets, normals, false, Vector3.ZERO)
	assert_false(bool(results[0]),
		"_detect_roofs should return false when no player position.")


func test_detect_roofs_mixed_targets() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	assert_not_null(system)

	var wall := CSGBox3D.new()
	wall.position = Vector3(0.0, 1.0, 0.0)
	add_child(wall)
	autofree(wall)

	var roof := CSGBox3D.new()
	roof.position = Vector3(0.0, 3.0, 0.0)
	add_child(roof)
	autofree(roof)

	var targets: Array = [wall, roof]
	var normals: Array = [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)]

	var results: Array = system._detect_roofs(targets, normals, true, Vector3(0.0, 0.0, 0.0))
	assert_false(bool(results[0]), "Wall should not be a roof.")
	assert_true(bool(results[1]), "Roof should be a roof.")


# --- _cleanup_stale_targets tests ---

func test_cleanup_stale_targets_restores_removed_targets() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	# Register a component and process once to populate tracking
	var component: Variant = _register_room_fade_group(ecs_manager, "E_CleanupA")
	system.process_tick(0.1)

	# Now remove the component
	ecs_manager.clear_all_components()

	# Call cleanup with empty active targets (simulating no active targets)
	system._cleanup_stale_targets({})
	assert_gt(applier.restore_calls, 0,
		"_cleanup_stale_targets should restore materials for stale targets.")


func test_cleanup_stale_targets_keeps_active_targets() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_CleanupKeep")
	system.process_tick(0.1)

	# After process_tick, targets are in _seen_this_frame
	var seen_targets: Dictionary = system._seen_this_frame.duplicate()

	# Cleanup with same active targets should not restore anything new
	var restore_count_before: int = (fixture.get("applier") as WallVisibilityApplierStub).restore_calls
	system._cleanup_stale_targets(seen_targets)
	var restore_count_after: int = (fixture.get("applier") as WallVisibilityApplierStub).restore_calls
	assert_eq(restore_count_after, restore_count_before,
		"_cleanup_stale_targets should not restore active targets.")


# --- process_tick line count verification ---

func test_process_tick_is_under_60_lines() -> void:
	var script := _wall_visibility_system_script()
	if script == null:
		return

	var source: String = script.source_code
	var lines: PackedStringArray = source.split("\n")

	# Find process_tick method and count its lines
	var start_line: int = -1
	var end_line: int = -1
	var indent_level: int = -1
	var in_method: bool = false

	for i in range(lines.size()):
		var line: String = lines[i]
		if line.find("func process_tick(") >= 0:
			start_line = i
			# Determine indentation of the func declaration
			var stripped: String = line.lstrip("\t ")
			indent_level = line.length() - stripped.length()
			in_method = true
			continue
		if in_method:
			if line.strip_edges() == "":
				continue
			var stripped: String = line.lstrip("\t ")
			var current_indent: int = line.length() - stripped.length()
			# If we hit another method at the same or lower indent level, we're done
			if current_indent <= indent_level and stripped.begins_with("func "):
				end_line = i - 1
				break
			# Also check for class-level variables or signals
			if current_indent <= indent_level and (stripped.begins_with("var ") or stripped.begins_with("signal ")):
				end_line = i - 1
				break

	if end_line == -1:
		end_line = lines.size() - 1

	var method_lines: int = end_line - start_line + 1
	assert_lt(method_lines, 60,
		"process_tick should be under 60 lines after decomposition, got %d." % method_lines)


# --- Fixture helpers ---

func _register_room_fade_group(
	ecs_manager: MockECSManager,
	entity_name: String,
	use_csg_target: bool = false
) -> Variant:
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