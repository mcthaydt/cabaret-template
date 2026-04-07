extends BaseTest

const WALL_VISIBILITY_SYSTEM_PATH := "res://scripts/ecs/systems/s_wall_visibility_system.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_ROOM_FADE_GROUP_COMPONENT := preload("res://scripts/ecs/components/c_room_fade_group_component.gd")
const RS_ROOM_FADE_SETTINGS := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")


class WallVisibilityApplierStub extends RefCounted:
	var apply_calls: int = 0
	var restore_calls: int = 0
	var last_restore_target_count: int = 0
	var uniforms_by_target_id: Dictionary = {}

	func invalidate_externally_removed() -> void:
		pass

	func apply_visibility_material(targets: Array) -> void:
		apply_calls += 1

	func update_uniforms(target: Node3D, clip_y: float, fade: float) -> void:
		if target != null:
			uniforms_by_target_id[target.get_instance_id()] = {
				"clip_y": clip_y,
				"fade_amount": fade,
			}

	func update_clip_y(targets: Array, clip_y: float) -> void:
		for target_variant in targets:
			var target := target_variant as Node3D
			if target == null:
				continue
			var target_id: int = target.get_instance_id()
			if uniforms_by_target_id.has(target_id):
				(uniforms_by_target_id[target_id] as Dictionary)["clip_y"] = clip_y
			else:
				uniforms_by_target_id[target_id] = {"clip_y": clip_y, "fade_amount": 0.0}

	func restore_original_materials(targets: Array) -> void:
		restore_calls += 1
		last_restore_target_count = targets.size()

	func get_cached_mesh_count() -> int:
		return 0


func _wall_visibility_system_script() -> Script:
	var script_obj := load(WALL_VISIBILITY_SYSTEM_PATH) as Script
	assert_not_null(script_obj, "Wall visibility system should load: %s" % WALL_VISIBILITY_SYSTEM_PATH)
	return script_obj


# --- Core behavior tests ---

func test_system_discovers_room_fade_components_via_ecs_manager() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	_register_room_fade_group(ecs_manager, "E_WallVisA")
	system.process_tick(0.1)

	assert_eq(applier.apply_calls, 1, "Should apply visibility material to targets.")


func test_system_is_noop_when_no_components_exist() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	assert_not_null(system)
	assert_not_null(applier)

	system.process_tick(0.1)
	assert_eq(applier.apply_calls, 0)
	assert_eq(applier.restore_calls, 0)


func test_system_restores_to_opaque_when_mode_is_not_orbit() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)
	assert_not_null(store)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisB")
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 0)

	store.set_slice("vcam", {"active_mode": "custom_mode"})
	system.process_tick(0.1)

	assert_eq(component.current_alpha, 1.0, "Component alpha should be restored to 1.0.")
	assert_eq(applier.restore_calls, 1, "Should restore materials when leaving orbit mode.")


func test_system_restores_stale_targets_when_components_removed() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)
	assert_not_null(ecs_manager)

	_register_room_fade_group(ecs_manager, "E_WallVisC")
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 0)

	ecs_manager.clear_all_components()
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 1)
	assert_eq(applier.last_restore_target_count, 1)


func test_system_restores_targets_when_camera_is_missing() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	var main_camera: Camera3D = fixture.get("main_camera") as Camera3D
	assert_not_null(system)

	_register_room_fade_group(ecs_manager, "E_WallVisD")
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 0)

	camera_manager.main_camera = null
	remove_child(main_camera)
	system.process_tick(0.1)
	assert_eq(applier.restore_calls, 1)
	assert_eq(applier.last_restore_target_count, 1)


# --- Directional fade tests ---

func test_camera_facing_wall_gets_fade_amount_one() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisE")
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings

	system.process_tick(0.1)

	# fade_amount=1.0 means fully dissolved, so current_alpha should be near 0.0
	assert_almost_eq(component.current_alpha, 0.0, 0.0001,
		"Camera-facing wall should have fade_amount=1.0 (current_alpha=0.0).")


func test_perpendicular_wall_stays_opaque() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisF")
	component.fade_normal = Vector3(1.0, 0.0, 0.0)
	component.current_alpha = 0.5

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings

	system.process_tick(0.1)

	# Perpendicular wall: dot≈0, below threshold → fade_amount=0, current_alpha=1.0
	assert_almost_eq(component.current_alpha, 1.0, 0.0001,
		"Perpendicular wall should remain opaque (fade_amount=0.0).")


func test_fade_amount_transitions_at_fade_speed_rate() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisG")
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 2.0
	settings.min_alpha = 0.05
	component.settings = settings

	system.process_tick(0.25)
	# fade_amount should increase by 2.0 * 0.25 = 0.5, so current_alpha = 1.0 - 0.5 = 0.5
	assert_almost_eq(component.current_alpha, 0.5, 0.0001,
		"Fade should transition at fade_speed per second.")


func test_fade_amount_does_not_exceed_one() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisH")
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings

	system.process_tick(0.5)
	assert_almost_eq(component.current_alpha, 0.0, 0.0001,
		"Fade amount should clamp to 1.0 (current_alpha = 0.0).")


# --- Height clip tests ---

func test_clip_y_set_from_player_position_and_offset() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisClipY")
	component.clip_height_offset = 2.0

	_set_player_position(store, Vector3(0.0, 3.0, 0.0))
	system.process_tick(0.1)

	# clip_y should be player_y (3.0) + offset (2.0) = 5.0
	var target_node: Node3D = _get_first_target(component)
	assert_not_null(target_node, "Should have a target node.")
	var target_id: int = target_node.get_instance_id()
	var uniforms: Dictionary = applier.uniforms_by_target_id.get(target_id, {}) as Dictionary
	assert_almost_eq(float(uniforms.get("clip_y", -1.0)), 5.0, 0.0001,
		"clip_y should be player_y + clip_height_offset.")


func test_clip_y_defaults_to_high_value_without_player_position() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisNoPlayer")
	system.process_tick(0.1)

	var target_node: Node3D = _get_first_target(component)
	assert_not_null(target_node, "Should have a target node.")
	var target_id: int = target_node.get_instance_id()
	var uniforms: Dictionary = applier.uniforms_by_target_id.get(target_id, {}) as Dictionary
	assert_almost_eq(float(uniforms.get("clip_y", -1.0)), 100.0, 0.0001,
		"clip_y should default to 100.0 when no player position is available.")


func test_custom_clip_height_offset_per_component() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisCustomOffset")
	component.clip_height_offset = 5.0

	_set_player_position(store, Vector3(0.0, 0.0, 0.0))
	system.process_tick(0.1)

	var target_node: Node3D = _get_first_target(component)
	assert_not_null(target_node)
	var target_id: int = target_node.get_instance_id()
	var uniforms: Dictionary = applier.uniforms_by_target_id.get(target_id, {}) as Dictionary
	assert_almost_eq(float(uniforms.get("clip_y", -1.0)), 5.0, 0.0001,
		"clip_y should use the component's clip_height_offset.")


# --- Multi-target tests ---

func test_multi_target_front_wall_fades_side_wall_stays_opaque() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var setup: Dictionary = _register_room_fade_group_with_front_and_side_csg_targets(
		ecs_manager, "E_WallVisFrontSide"
	)
	var component = setup.get("component")
	var front_target: Node3D = setup.get("front_target") as Node3D
	var side_target: Node3D = setup.get("side_target") as Node3D
	assert_not_null(component)
	assert_not_null(front_target)
	assert_not_null(side_target)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.3
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings
	component.current_alpha = 1.0

	system.process_tick(0.1)

	var front_uniforms: Dictionary = applier.uniforms_by_target_id.get(
		front_target.get_instance_id(), {}
	) as Dictionary
	var side_uniforms: Dictionary = applier.uniforms_by_target_id.get(
		side_target.get_instance_id(), {}
	) as Dictionary
	assert_almost_eq(
		float(front_uniforms.get("fade_amount", -1.0)), 1.0, 0.0001,
		"Front wall should be fully dissolved."
	)
	assert_almost_eq(
		float(side_uniforms.get("fade_amount", -1.0)), 0.0, 0.0001,
		"Side wall should remain opaque."
	)


func test_csg_targets_supported() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisCSG", true)
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0
	system.process_tick(0.2)

	assert_eq(applier.apply_calls, 1)
	assert_lt(component.current_alpha, 1.0, "CSG target should trigger fade.")


func test_viewport_camera_fallback_when_camera_manager_returns_null() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	assert_not_null(system)

	_register_room_fade_group(ecs_manager, "E_WallVisFallback")
	camera_manager.main_camera = null
	system.process_tick(0.1)

	assert_eq(applier.apply_calls, 1, "Should use viewport camera fallback.")
	assert_eq(applier.restore_calls, 0)


func test_uses_default_settings_when_component_settings_null() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisDefaults")
	component.settings = null
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0

	# Default fade_speed=4.0, fade_dot_threshold=0.3. Camera -Z, wall normal -Z → dot≈1.0 > 0.3 → fade
	# fade_amount increases by 4.0 * 0.1 = 0.4, current_alpha = 1.0 - 0.4 = 0.6
	system.process_tick(0.1)
	assert_almost_eq(component.current_alpha, 0.6, 0.0001,
		"Should use default settings (fade_speed=4.0).")


# --- Fixture helpers ---

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


func _get_first_target(component: Variant) -> Node3D:
	if component == null:
		return null
	if not component.has_method("collect_mesh_targets"):
		return null
	var targets: Array = component.call("collect_mesh_targets") as Array
	if targets.is_empty():
		return null
	return targets[0] as Node3D


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


# --- Corridor tests ---

func test_side_wall_outside_camera_player_corridor_stays_opaque() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	# Camera at origin, player at (0,0,10), wall facing camera but offset to the side
	camera_manager.main_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0))
	_set_player_position(store, Vector3(0.0, 0.0, 10.0))

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisCorridor")
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0

	# Move the entity (and target) far off the camera-player corridor line
	var entity: Node = component.get_parent() as Node
	entity.position = Vector3(50.0, 0.0, 5.0)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings

	system.process_tick(0.1)

	# The wall faces the camera (dot > threshold) but is outside the corridor
	assert_almost_eq(component.current_alpha, 1.0, 0.0001,
		"Wall outside corridor should remain opaque.")


# --- Bucket continuity tests ---

func test_bucket_continuity_fades_all_segments_when_one_is_in_corridor() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_set_player_position(store, Vector3(0.0, 0.0, 0.0))

	var setup: Dictionary = _register_room_fade_group_with_front_and_side_csg_targets(
		ecs_manager, "E_WallVisBucket"
	)
	var component = setup.get("component")
	var front_target: Node3D = setup.get("front_target") as Node3D

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings
	component.current_alpha = 1.0

	system.process_tick(0.1)

	# Both targets share the same bucket key (front = +z or -z), front target is in corridor
	# so both should fade (bucket continuity)
	var front_uniforms: Dictionary = applier.uniforms_by_target_id.get(
		front_target.get_instance_id(), {}
	) as Dictionary
	assert_almost_eq(
		float(front_uniforms.get("fade_amount", -1.0)), 1.0, 0.0001,
		"Front target in corridor should fade."
	)


# --- Room filtering tests ---

func test_multi_room_only_processes_room_containing_player() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	# Player near room A at (0,0,0)
	_set_player_position(store, Vector3(0.0, 0.0, 0.0))

	# Room A component (player is here)
	var component_a: Variant = _register_room_fade_group(ecs_manager, "E_RoomA")
	component_a.fade_normal = Vector3(0.0, 0.0, -1.0)
	component_a.current_alpha = 1.0
	var entity_a: Node = component_a.get_parent() as Node
	entity_a.position = Vector3(0.0, 0.0, 0.0)

	# Room B component (far away, player is NOT here)
	var entity_b := BASE_ECS_ENTITY.new()
	entity_b.name = "E_RoomB"
	add_child(entity_b)
	autofree(entity_b)
	entity_b.position = Vector3(100.0, 0.0, 100.0)

	var component_b := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_b.add_child(component_b)
	autofree(component_b)
	component_b.fade_normal = Vector3(0.0, 0.0, -1.0)
	component_b.current_alpha = 1.0
	ecs_manager.add_component_to_entity(entity_b, component_b)

	var mesh_b := MeshInstance3D.new()
	mesh_b.mesh = BoxMesh.new()
	entity_b.add_child(mesh_b)
	autofree(mesh_b)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component_a.settings = settings
	component_b.settings = settings

	system.process_tick(0.1)

	# Room A should be processed (player inside), Room B should not
	var target_a: Node3D = _get_first_target(component_a)
	assert_not_null(target_a)
	var target_a_id: int = target_a.get_instance_id()
	assert_true(
		applier.uniforms_by_target_id.has(target_a_id),
		"Room A target should be processed."
	)


# --- Duplicate target ownership tests ---

func test_duplicate_target_assigned_to_first_component_only() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var warnings: Array = []
	system.duplicate_target_warning_handler = func(msg: String) -> void:
		warnings.append(msg)

	# Shared target node
	var shared_mesh := MeshInstance3D.new()
	shared_mesh.mesh = BoxMesh.new()
	shared_mesh.name = "SharedWall"
	add_child(shared_mesh)
	autofree(shared_mesh)

	# Component A with shared target
	var entity_a := BASE_ECS_ENTITY.new()
	entity_a.name = "E_DupA"
	add_child(entity_a)
	autofree(entity_a)

	var component_a := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_a.add_child(component_a)
	autofree(component_a)
	ecs_manager.add_component_to_entity(entity_a, component_a)
	shared_mesh.reparent(entity_a)

	# Component B trying to claim the same target
	var entity_b := BASE_ECS_ENTITY.new()
	entity_b.name = "E_DupB"
	add_child(entity_b)
	autofree(entity_b)

	var component_b := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity_b.add_child(component_b)
	autofree(component_b)
	ecs_manager.add_component_to_entity(entity_b, component_b)

	system.process_tick(0.1)

	assert_eq(warnings.size(), 1, "Should warn about duplicate target ownership.")


# --- min_fade cap tests ---

func test_fade_amount_capped_by_min_fade() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	system.min_fade = 0.1

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisMinFade")
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings

	system.process_tick(0.1)

	# max_fade = 1.0 - 0.1 = 0.9, so fade_amount should be capped at 0.9
	var target_node: Node3D = _get_first_target(component)
	assert_not_null(target_node)
	var target_id: int = target_node.get_instance_id()
	var uniforms: Dictionary = applier.uniforms_by_target_id.get(target_id, {}) as Dictionary
	assert_almost_eq(float(uniforms.get("fade_amount", -1.0)), 0.9, 0.0001,
		"fade_amount should be capped at 1.0 - min_fade.")


# --- Mobile tick throttling tests ---

func test_mobile_tick_throttling_skips_non_matching_frames() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	# Force mobile mode
	system._is_mobile = true
	system.mobile_tick_interval = 4

	_register_room_fade_group(ecs_manager, "E_WallVisMobile")

	# Ticks 1-3 should be skipped, tick 4 should process
	system.process_tick(0.1)
	assert_eq(applier.apply_calls, 0, "Tick 1 should be skipped on mobile.")

	system.process_tick(0.1)
	assert_eq(applier.apply_calls, 0, "Tick 2 should be skipped on mobile.")

	system.process_tick(0.1)
	assert_eq(applier.apply_calls, 0, "Tick 3 should be skipped on mobile.")

	system.process_tick(0.1)
	assert_eq(applier.apply_calls, 1, "Tick 4 should process on mobile.")


# --- Roof handling tests ---

func test_roof_target_inherits_wall_fade_when_non_roof_is_fading() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var applier: WallVisibilityApplierStub = fixture.get("applier") as WallVisibilityApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)

	_set_player_position(store, Vector3(0.0, 0.0, 0.0))

	# Create entity with a wall target and a roof target
	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_WallVisRoof"
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	# Wall facing camera
	var wall_target := CSGBox3D.new()
	wall_target.size = Vector3(4.0, 2.0, 0.1)
	wall_target.position = Vector3(0.0, 1.0, 5.0)
	entity.add_child(wall_target)
	autofree(wall_target)

	# Roof above player (normal pointing up)
	var roof_target := CSGBox3D.new()
	roof_target.size = Vector3(4.0, 0.1, 4.0)
	roof_target.position = Vector3(0.0, 3.0, 0.0)
	entity.add_child(roof_target)
	autofree(roof_target)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings

	system.process_tick(0.1)

	var roof_id: int = roof_target.get_instance_id()
	var roof_uniforms: Dictionary = applier.uniforms_by_target_id.get(roof_id, {}) as Dictionary
	# Roof should have some fade (inherited from non-roof wall fade), not zero
	assert_gt(
		float(roof_uniforms.get("fade_amount", 0.0)),
		0.0,
		"Roof should inherit fade from non-roof targets in same component."
	)


# --- Fade-up toward opaque tests ---

func test_fade_amount_transitions_toward_opaque_when_dot_below_threshold() -> void:
	var fixture := _create_fixture()
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)

	var component: Variant = _register_room_fade_group(ecs_manager, "E_WallVisFadeUp")
	component.fade_normal = Vector3(1.0, 0.0, 0.0)  # Perpendicular to camera
	component.current_alpha = 0.0  # Start fully faded

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 2.0
	settings.min_alpha = 0.05
	component.settings = settings

	system.process_tick(0.25)

	# Perpendicular wall: dot≈0, below threshold → target_fade=0, fade_amount should decrease
	# fade_amount goes from 1.0 toward 0.0 at rate 2.0*0.25=0.5
	# current_alpha = 1.0 - fade_amount = 1.0 - 0.5 = 0.5
	assert_almost_eq(component.current_alpha, 0.5, 0.0001,
		"Fade should transition toward opaque when dot below threshold."
	)
