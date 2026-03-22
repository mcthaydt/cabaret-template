extends GutTest

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func test_silhouette_event_sets_transparency_on_occluders() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var target := _create_mesh_target()

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [target],
		"enabled": true,
	})
	manager._physics_process(0.0)
	assert_almost_eq(target.transparency, 0.0, 0.001,
		"First detection frame should not apply silhouette due debounce")

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [target],
		"enabled": true,
	})
	manager._physics_process(0.0)

	assert_almost_eq(target.transparency, U_VCamSilhouetteHelper.DEFAULT_SILHOUETTE_TRANSPARENCY, 0.001,
		"VFX manager should set transparency on occluder from event payload")

func test_silhouette_disable_restores_transparency() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var target := _create_mesh_target()
	var original_transparency: float = target.transparency

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [target],
		"enabled": true,
	})
	manager._physics_process(0.0)
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [target],
		"enabled": true,
	})
	manager._physics_process(0.0)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [],
		"enabled": false,
	})
	manager._physics_process(0.0)

	assert_almost_eq(target.transparency, original_transparency, 0.001,
		"Disable request should restore original transparency")

func test_silhouette_preserves_material_override() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var target := _create_mesh_target()
	var original_material := StandardMaterial3D.new()
	target.material_override = original_material

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [target],
		"enabled": true,
	})
	manager._physics_process(0.0)
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [target],
		"enabled": true,
	})
	manager._physics_process(0.0)

	assert_eq(target.material_override, original_material,
		"Occluder material_override should stay untouched")

func test_silhouette_event_respects_player_gating() -> void:
	var manager := await _create_manager_with_state(StringName("player"), false, [], StringName("gameplay"))
	var target := _create_mesh_target()

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("enemy"),
		"occluders": [target],
		"enabled": true,
	})
	manager._physics_process(0.0)

	assert_almost_eq(target.transparency, 0.0, 0.001,
		"Non-player silhouette request should be ignored")

func test_silhouette_event_respects_transition_blocking() -> void:
	var manager := await _create_manager_with_state(StringName("player"), true, [], StringName("gameplay"))
	var target := _create_mesh_target()

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [target],
		"enabled": true,
	})
	manager._physics_process(0.0)

	assert_almost_eq(target.transparency, 0.0, 0.001,
		"Transition-blocked silhouette request should be ignored")

func _create_mesh_target() -> MeshInstance3D:
	var target := MeshInstance3D.new()
	target.mesh = BoxMesh.new()
	add_child_autofree(target)
	return target

func _create_manager_with_state(
	player_entity_id: StringName,
	is_transitioning: bool,
	scene_stack: Array,
	shell: StringName
) -> M_VFXManager:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {
		"player_entity_id": String(player_entity_id),
	})
	store.set_slice(StringName("scene"), {
		"is_transitioning": is_transitioning,
		"scene_stack": scene_stack.duplicate(true),
	})
	store.set_slice(StringName("navigation"), {
		"shell": shell,
	})
	add_child_autofree(store)

	var manager := M_VFX_MANAGER.new()
	manager.state_store = store
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager
