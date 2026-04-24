extends BaseTest

const ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const CAMERA_STATE_SYSTEM := preload("res://scripts/ecs/systems/s_camera_state_system.gd")
const CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	super.after_each()

func test_entity_death_event_applies_camera_shake_through_camera_state_system() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var camera_state: C_CameraStateComponent = fixture["camera_state"] as C_CameraStateComponent
	var camera_manager: MockCameraManager = fixture["camera_manager"] as MockCameraManager

	assert_not_null(camera_state)
	assert_not_null(camera_manager)
	assert_eq(camera_state.shake_trauma, 0.0)
	assert_eq(camera_manager.shake_sources.size(), 0)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_ENTITY_DEATH, {
		"entity_id": StringName("player"),
	})
	await _pump()

	assert_true(camera_state.shake_trauma > 0.0)
	assert_true(camera_state.shake_trauma <= 0.5)
	assert_true(camera_manager.shake_sources.has(StringName("qb_camera_rule")))
	assert_true(camera_manager.apply_calls > 0)

func _setup_fixture() -> Dictionary:
	var root := Node3D.new()
	root.name = "IntegrationRoot"
	add_child(root)
	autofree(root)
	await _pump()

	var manager := ECS_MANAGER.new()
	root.add_child(manager)
	autofree(manager)
	await _pump_physics()

	var store := MOCK_STATE_STORE.new()
	autofree(store)
	store.set_slice(StringName("vcam"), {
		"in_fov_zone": false,
	})

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	autofree(camera_manager)
	var main_camera := Camera3D.new()
	autofree(main_camera)
	main_camera.fov = 90.0
	camera_manager.main_camera = main_camera

	var camera_state_system := CAMERA_STATE_SYSTEM.new()
	camera_state_system.state_store = store
	camera_state_system.ecs_manager = manager
	camera_state_system.camera_manager = camera_manager
	manager.add_child(camera_state_system)
	autofree(camera_state_system)
	await _pump_physics()

	var camera_entity := Node3D.new()
	camera_entity.name = "E_Camera"
	root.add_child(camera_entity)
	autofree(camera_entity)

	var camera_state := CAMERA_STATE_COMPONENT.new()
	camera_entity.add_child(camera_state)
	autofree(camera_state)
	await _pump_physics()

	return {
		"root": root,
		"manager": manager,
		"store": store,
		"camera_manager": camera_manager,
		"camera_state": camera_state,
	}

func _pump() -> void:
	await get_tree().process_frame

func _pump_physics() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
