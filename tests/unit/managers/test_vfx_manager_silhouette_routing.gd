extends GutTest

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()

func _create_player_entity(mesh_count: int = 1) -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	for i in mesh_count:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		root.add_child(mesh)
	return root

func _create_manager_with_state(
	player_entity_id: StringName,
	is_transitioning: bool,
	scene_stack: Array,
	shell: StringName,
	player_entity: Node3D = null,
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

	var ecs := MOCK_ECS_MANAGER.new()
	if player_entity != null:
		ecs.register_entity_id(player_entity_id, player_entity)
	add_child_autofree(ecs)

	var manager := M_VFX_MANAGER.new()
	manager.state_store = store
	manager.ecs_manager = ecs
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager

func test_silhouette_applies_overlay_to_player_meshes_not_occluders() -> void:
	var player := _create_player_entity(2)
	var occluder := MeshInstance3D.new()
	occluder.mesh = BoxMesh.new()
	add_child_autofree(occluder)
	var occluder_original := StandardMaterial3D.new()
	occluder.material_override = occluder_original

	var manager := await _create_manager_with_state(
		StringName("player"), false, [], StringName("gameplay"), player
	)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [occluder],
		"enabled": true,
	})
	manager._physics_process(0.0)

	var mesh_a: MeshInstance3D = player.get_child(0) as MeshInstance3D
	var mesh_b: MeshInstance3D = player.get_child(1) as MeshInstance3D
	assert_true(mesh_a.material_overlay is ShaderMaterial, "Player mesh A should have silhouette overlay")
	assert_true(mesh_b.material_overlay is ShaderMaterial, "Player mesh B should have silhouette overlay")
	assert_eq(occluder.material_override, occluder_original, "Occluder material_override should be untouched")
	assert_null(occluder.material_overlay, "Occluder material_overlay should be untouched")

func test_silhouette_disable_removes_overlay() -> void:
	var player := _create_player_entity(1)
	var manager := await _create_manager_with_state(
		StringName("player"), false, [], StringName("gameplay"), player
	)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [MeshInstance3D.new()],
		"enabled": true,
	})
	manager._physics_process(0.0)

	var mesh: MeshInstance3D = player.get_child(0) as MeshInstance3D
	assert_true(mesh.material_overlay is ShaderMaterial, "Should have overlay after enable")

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [],
		"enabled": false,
	})
	manager._physics_process(0.0)

	assert_null(mesh.material_overlay, "Overlay should be removed on disable")

func test_empty_occluders_removes_overlay() -> void:
	var player := _create_player_entity(1)
	var manager := await _create_manager_with_state(
		StringName("player"), false, [], StringName("gameplay"), player
	)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [MeshInstance3D.new()],
		"enabled": true,
	})
	manager._physics_process(0.0)

	var mesh: MeshInstance3D = player.get_child(0) as MeshInstance3D
	assert_true(mesh.material_overlay is ShaderMaterial, "Should have overlay")

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [],
		"enabled": true,
	})
	manager._physics_process(0.0)

	assert_null(mesh.material_overlay, "Empty occluders should remove overlay even with enabled=true")

func test_respects_player_gating() -> void:
	var player := _create_player_entity(1)
	var manager := await _create_manager_with_state(
		StringName("player"), false, [], StringName("gameplay"), player
	)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("enemy"),
		"occluders": [MeshInstance3D.new()],
		"enabled": true,
	})
	manager._physics_process(0.0)

	var mesh: MeshInstance3D = player.get_child(0) as MeshInstance3D
	assert_null(mesh.material_overlay, "Non-player entity should not trigger overlay")

func test_respects_transition_blocking() -> void:
	var player := _create_player_entity(1)
	var manager := await _create_manager_with_state(
		StringName("player"), true, [], StringName("gameplay"), player
	)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [MeshInstance3D.new()],
		"enabled": true,
	})
	manager._physics_process(0.0)

	var mesh: MeshInstance3D = player.get_child(0) as MeshInstance3D
	assert_null(mesh.material_overlay, "Transition-blocked request should not apply overlay")

func test_unresolvable_entity_is_safe() -> void:
	var manager := await _create_manager_with_state(
		StringName("player"), false, [], StringName("gameplay"), null
	)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": StringName("player"),
		"occluders": [MeshInstance3D.new()],
		"enabled": true,
	})
	manager._physics_process(0.0)

	assert_eq(manager._silhouette_helper.get_active_count(), 0, "Unresolvable entity should not crash or apply")
