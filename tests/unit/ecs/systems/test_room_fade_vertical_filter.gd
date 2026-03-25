extends BaseTest

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

class RoomFadeMaterialApplierStub extends RefCounted:
	var apply_calls: int = 0
	var update_calls: int = 0
	var restore_calls: int = 0
	var last_updated_alpha: float = -1.0
	var last_updated_target_count: int = 0
	var last_restore_target_count: int = 0

	func invalidate_externally_removed() -> void:
		pass

	func apply_fade_material(targets: Array) -> void:
		apply_calls += 1
		last_updated_target_count = targets.size()

	func update_fade_alpha(targets: Array, alpha: float) -> void:
		update_calls += 1
		last_updated_alpha = alpha
		last_updated_target_count = targets.size()

	func update_single_fade_alpha(target: Node3D, alpha: float) -> void:
		update_calls += 1
		last_updated_alpha = alpha
		last_updated_target_count = 1

	func restore_original_materials(targets: Array) -> void:
		restore_calls += 1
		last_restore_target_count = targets.size()

	func get_cached_mesh_count() -> int:
		return 0

func _room_fade_system_script() -> Script:
	var script_obj := load(ROOM_FADE_SYSTEM_PATH) as Script
	assert_not_null(script_obj, "Room fade system should load: %s" % ROOM_FADE_SYSTEM_PATH)
	return script_obj

func _create_fixture(player_position: Vector3) -> Dictionary:
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
	state_store.set_slice("gameplay", {
		"player_entity_id": "player_1",
		"entities": {
			"player_1": {
				"position": player_position,
			},
		},
	})

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

func _register_room_fade_at_height(
	ecs_manager: MockECSManager,
	entity_name: String,
	y_min: float,
	y_max: float
) -> Variant:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = entity_name
	add_child(entity)
	autofree(entity)

	var component := C_ROOM_FADE_GROUP_COMPONENT.new()
	component.fade_normal = Vector3(0.0, 0.0, -1.0)
	component.current_alpha = 1.0
	var settings := RS_ROOM_FADE_SETTINGS.new()
	settings.fade_dot_threshold = 0.2
	settings.fade_speed = 1.0
	settings.min_alpha = 0.1
	component.settings = settings
	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)

	var bottom_mesh := MeshInstance3D.new()
	bottom_mesh.mesh = BoxMesh.new()
	bottom_mesh.position = Vector3(0.0, y_min, 0.0)
	entity.add_child(bottom_mesh)
	autofree(bottom_mesh)

	var top_mesh := MeshInstance3D.new()
	top_mesh.mesh = BoxMesh.new()
	top_mesh.position = Vector3(0.0, y_max, 0.0)
	entity.add_child(top_mesh)
	autofree(top_mesh)

	return component

func test_player_on_ground_floor_matches_ground_room_only() -> void:
	var fixture := _create_fixture(Vector3(0.0, 1.5, 0.0))
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager
	var applier: RoomFadeMaterialApplierStub = fixture.get("applier") as RoomFadeMaterialApplierStub

	var ground: Variant = _register_room_fade_at_height(ecs_manager, "E_Ground", 0.0, 3.0)
	var balcony: Variant = _register_room_fade_at_height(ecs_manager, "E_Balcony", 4.0, 7.0)

	system.process_tick(0.1)

	assert_lt(ground.current_alpha, 1.0, "Ground floor should be fading")
	assert_eq(balcony.current_alpha, 1.0, "Balcony should remain opaque")

func test_player_on_balcony_matches_balcony_room_only() -> void:
	var fixture := _create_fixture(Vector3(0.0, 5.5, 0.0))
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager

	var ground: Variant = _register_room_fade_at_height(ecs_manager, "E_Ground", 0.0, 3.0)
	var balcony: Variant = _register_room_fade_at_height(ecs_manager, "E_Balcony", 4.0, 7.0)

	system.process_tick(0.1)

	assert_eq(ground.current_alpha, 1.0, "Ground floor should remain opaque")
	assert_lt(balcony.current_alpha, 1.0, "Balcony should be fading")

func test_player_near_edge_still_matches_correct_room() -> void:
	var fixture := _create_fixture(Vector3(0.0, 2.8, 0.0))
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager

	var ground: Variant = _register_room_fade_at_height(ecs_manager, "E_Ground", 0.0, 3.0)
	var balcony: Variant = _register_room_fade_at_height(ecs_manager, "E_Balcony", 4.0, 7.0)

	system.process_tick(0.1)

	assert_lt(ground.current_alpha, 1.0, "Ground floor should be fading for player near ceiling")
	assert_eq(balcony.current_alpha, 1.0, "Balcony should remain opaque")

func test_single_component_always_returned() -> void:
	var fixture := _create_fixture(Vector3(0.0, 50.0, 0.0))
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager

	var ground: Variant = _register_room_fade_at_height(ecs_manager, "E_Ground", 0.0, 3.0)

	system.process_tick(0.1)

	assert_lt(ground.current_alpha, 1.0, "Single component should always be processed")

func test_horizontal_tolerance_preserved() -> void:
	var fixture := _create_fixture(Vector3(1.5, 1.5, 0.0))
	var system = fixture.get("system")
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager

	var ground: Variant = _register_room_fade_at_height(ecs_manager, "E_Ground", 0.0, 3.0)
	var balcony: Variant = _register_room_fade_at_height(ecs_manager, "E_Balcony", 4.0, 7.0)

	system.process_tick(0.1)

	assert_lt(ground.current_alpha, 1.0, "Ground should fade for player 1.5m outside XZ bounds")
	assert_eq(balcony.current_alpha, 1.0, "Balcony should remain opaque")
