extends BaseTest

const M_VCAM_MANAGER := preload("res://scripts/core/managers/m_vcam_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/core/resources/display/vcam/rs_vcam_mode_orbit.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_VCAM_ACTIONS := preload("res://scripts/core/state/actions/u_vcam_actions.gd")

class MobileSilhouetteStub extends M_VCAM_MANAGER:
	var test_follow_target: Node3D = null
	var test_occluders: Array = []

	func _resolve_follow_target_for_vcam(_vcam: Node) -> Node3D:
		if test_follow_target != null and is_instance_valid(test_follow_target):
			return test_follow_target
		return null

	func _detect_occluders_for_silhouette(
		_camera_transform: Transform3D,
		_follow_target: Node3D,
		_debug_enabled: bool = false,
		_debug_context: String = ""
	) -> Array:
		return test_occluders.duplicate(false)

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

# Test 1: Mobile flag forces silhouette disabled regardless of redux state
func test_is_occlusion_silhouette_enabled_returns_false_on_mobile() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": true})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_mobile_manager(store, camera_manager)
	manager._is_mobile = true

	var result: bool = manager._is_occlusion_silhouette_enabled()
	assert_false(result, "Mobile should force silhouette disabled even when redux state is true")

# Test 2: Desktop respects redux state when enabled
func test_is_occlusion_silhouette_enabled_respects_redux_on_desktop_enabled() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": true})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_mobile_manager(store, camera_manager)
	manager._is_mobile = false

	var result: bool = manager._is_occlusion_silhouette_enabled()
	assert_true(result, "Desktop should return true when redux state is enabled")

# Test 3: Desktop respects redux state when disabled
func test_is_occlusion_silhouette_enabled_respects_redux_on_desktop_disabled() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": false})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_mobile_manager(store, camera_manager)
	manager._is_mobile = false

	var result: bool = manager._is_occlusion_silhouette_enabled()
	assert_false(result, "Desktop should return false when redux state is disabled")

# Test 4: Mobile publishes silhouette clear instead of occluders
func test_mobile_publishes_silhouette_clear_on_submit() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": true})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_mobile_manager(store, camera_manager)
	manager._is_mobile = true
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5))
	var follow_target := Node3D.new()
	add_child(follow_target)
	autofree(follow_target)
	manager.test_follow_target = follow_target
	manager.test_occluders = [_create_mesh_occluder()]

	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": Transform3D.IDENTITY})

	var payload := _find_last_silhouette_payload(store)
	assert_false(payload.is_empty(), "Mobile should still publish silhouette event (clear request)")
	assert_eq(payload.get("enabled", true), false, "Mobile silhouette request should be disabled")
	var occluders := payload.get("occluders", []) as Array
	assert_eq(occluders.size(), 0, "Mobile should not carry occluders")

func _create_mobile_manager(
	injected_store: I_StateStore = null,
	injected_camera_manager: I_CameraManager = null
) -> MobileSilhouetteStub:
	var manager := MobileSilhouetteStub.new()
	if injected_store != null:
		manager.state_store = injected_store
	if injected_camera_manager != null:
		manager.camera_manager = injected_camera_manager
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame
	return manager

func _create_vcam(
	vcam_id: StringName,
	priority: int,
	active: bool = true
) -> C_VCamComponent:
	var component := C_VCAM_COMPONENT.new()
	component.vcam_id = vcam_id
	component.priority = priority
	component.is_active = active
	component.mode = RS_VCAM_MODE_ORBIT.new()
	add_child(component)
	autofree(component)
	return component

func _create_mesh_occluder() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	add_child(mesh)
	autofree(mesh)
	return mesh

func _find_last_silhouette_payload(store: MockStateStore) -> Dictionary:
	var actions: Array[Dictionary] = store.get_dispatched_actions()
	for i in range(actions.size() - 1, -1, -1):
		var action: Dictionary = actions[i]
		if action.get("type", StringName("")) != U_VCAM_ACTIONS.ACTION_SILHOUETTE_UPDATE_REQUEST:
			continue
		return {
			"entity_id": action.get("entity_id", StringName("")),
			"occluders": action.get("occluders", []),
			"enabled": action.get("enabled", false),
		}
	return {}
