extends GutTest

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/ecs/u_ecs_event_names.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()

func test_uses_injected_state_store() -> void:
	var mock_store := MOCK_STATE_STORE.new()
	add_child_autofree(mock_store)

	var manager := M_VFX_MANAGER.new()
	manager.state_store = mock_store
	add_child_autofree(manager)
	await get_tree().process_frame

	assert_eq(manager.get("_state_store"), mock_store,
		"M_VFXManager should use injected state_store")

func test_uses_injected_camera_manager() -> void:
	var mock_camera := MOCK_CAMERA_MANAGER.new()
	add_child_autofree(mock_camera)

	var manager := M_VFX_MANAGER.new()
	manager.camera_manager = mock_camera
	add_child_autofree(manager)
	await get_tree().process_frame

	assert_eq(manager.get("_camera_manager"), mock_camera,
		"M_VFXManager should use injected camera_manager")

func test_injection_overrides_discovery() -> void:
	var service_store := MOCK_STATE_STORE.new()
	add_child_autofree(service_store)
	U_SERVICE_LOCATOR.register(U_ECS_EVENT_NAMES.SERVICE_STATE_STORE, service_store)

	var service_camera := MOCK_CAMERA_MANAGER.new()
	add_child_autofree(service_camera)
	U_SERVICE_LOCATOR.register(U_ECS_EVENT_NAMES.SERVICE_CAMERA_MANAGER, service_camera)

	var injected_store := MOCK_STATE_STORE.new()
	add_child_autofree(injected_store)

	var injected_camera := MOCK_CAMERA_MANAGER.new()
	add_child_autofree(injected_camera)

	var manager := M_VFX_MANAGER.new()
	manager.state_store = injected_store
	manager.camera_manager = injected_camera
	add_child_autofree(manager)
	await get_tree().process_frame

	assert_eq(manager.get("_state_store"), injected_store,
		"Injected state_store should override ServiceLocator")
	assert_eq(manager.get("_camera_manager"), injected_camera,
		"Injected camera_manager should override ServiceLocator")

func test_fallback_to_discovery_when_no_injection() -> void:
	var service_store := MOCK_STATE_STORE.new()
	add_child_autofree(service_store)
	U_SERVICE_LOCATOR.register(U_ECS_EVENT_NAMES.SERVICE_STATE_STORE, service_store)

	var service_camera := MOCK_CAMERA_MANAGER.new()
	add_child_autofree(service_camera)
	U_SERVICE_LOCATOR.register(U_ECS_EVENT_NAMES.SERVICE_CAMERA_MANAGER, service_camera)

	var manager := M_VFX_MANAGER.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	assert_eq(manager.get("_state_store"), service_store,
		"M_VFXManager should fall back to ServiceLocator state_store")
	assert_eq(manager.get("_camera_manager"), service_camera,
		"M_VFXManager should fall back to ServiceLocator camera_manager")
