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

	func update_single_fade_alpha(target: Node3D, alpha: float) -> void:
		update_calls += 1
		last_updated_alpha = alpha
		last_updated_target_count = 1
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

# Test 1: Mobile frame-skip reduces tick frequency
func test_mobile_frame_skip_reduces_processing_frequency() -> void:
	var fixture := _create_fixture(true)
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)

	_register_room_fade_group(ecs_manager, "E_MobileRoom")

	# Call process_tick 8 times — only 2 should actually process (every 4th tick)
	for i in range(8):
		system.process_tick(0.016)

	# With MOBILE_TICK_INTERVAL=4, ticks at counter 4 and 8 should process
	assert_eq(applier.update_calls, 2, "Mobile should only process every 4th tick (2 of 8)")

# Test 2: Desktop processes every tick (no frame skip)
func test_desktop_processes_every_tick() -> void:
	var fixture := _create_fixture(false)
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	assert_not_null(system)
	assert_not_null(applier)

	_register_room_fade_group(ecs_manager, "E_DesktopRoom")

	for i in range(8):
		system.process_tick(0.016)

	assert_eq(applier.update_calls, 8, "Desktop should process every tick (8 of 8)")

# Test 3: Mobile skips corridor logic — target outside corridor still fades
func test_mobile_skips_corridor_logic_target_still_fades() -> void:
	var fixture := _create_fixture(true)
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var state_store: MockStateStore = fixture.get("state_store") as MockStateStore
	assert_not_null(system)
	assert_not_null(applier)

	# Place player far off to the side so corridor check would fail on desktop
	_set_player_position(state_store, Vector3(50.0, 0.0, 0.0))

	# Camera looking at -Z, wall normal is -Z (dot > threshold → should fade)
	var room_data := _register_room_fade_group_at_position(ecs_manager, "E_MobileCorridorTest", Vector3.ZERO)
	var component: Variant = room_data.get("component")
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0
	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings

	# Reset counter so next tick is a processing tick
	system._mobile_tick_counter = 3

	system.process_tick(0.1)

	# On mobile, corridor is bypassed so target should fade even though player is far away
	assert_lt(component.current_alpha, 1.0, "Mobile should fade target even when outside corridor")

# Test 4: Desktop uses corridor logic — target outside corridor stays opaque
func test_desktop_uses_corridor_logic_target_stays_opaque() -> void:
	var fixture := _create_fixture(false)
	var system = fixture.get("system")
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var state_store: MockStateStore = fixture.get("state_store") as MockStateStore
	var main_camera: Camera3D = fixture.get("main_camera") as Camera3D
	assert_not_null(system)
	assert_not_null(applier)

	# Place player far off to the side so corridor check fails
	_set_player_position(state_store, Vector3(50.0, 0.0, 0.0))

	# Use a side target positioned far outside the camera-player corridor
	var entity := BASE_ECS_ENTITY.new()
	entity.name = "E_DesktopCorridorTest"
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 100.0
	settings.min_alpha = 0.05
	component.settings = settings

	# CSG target positioned far from the camera-player line
	var csg_target := CSGBox3D.new()
	csg_target.size = Vector3(2.0, 2.0, 0.1)
	csg_target.position = Vector3(0.0, 0.0, 5.0)
	entity.add_child(csg_target)
	autofree(csg_target)

	# Camera at origin looking at -Z, player at (50,0,0), target at (0,0,5)
	# Dot of camera_forward(-Z) with thin-axis-normal(Z) = -1.0 < threshold → opaque
	# But let's use a target whose normal aligns with camera forward
	# Actually, the thin axis detection will derive normal from the CSG shape
	# For a box at (0,0,5) with size (2,2,0.1), thin axis is Z, so normal = (0,0,1) or (0,0,-1)
	# camera_forward = (0,0,-1), dot with (0,0,-1) = 1.0 > threshold → would fade
	# But corridor check: camera(0,0,0) to player(50,0,0), target at (0,0,5)
	# segment_t = dot((0,0,5)-(0,0,0), (50,0,0)-(0,0,0)) / |segment|^2 = 0/2500 = 0.0
	# closest_point = (0,0,0), distance = 5.0, corridor_radius ~= max(0.8, min(4.0, 0.1*1.2)) = 0.8
	# 5.0 > 0.8 → corridor fails → target stays opaque on desktop

	system.process_tick(0.1)

	assert_almost_eq(component.current_alpha, 1.0, 0.001,
		"Desktop should keep target opaque when corridor check fails")

func _create_fixture(is_mobile: bool) -> Dictionary:
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
	system._is_mobile = is_mobile
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
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	entity.add_child(mesh_instance)
	autofree(mesh_instance)

	return component

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
