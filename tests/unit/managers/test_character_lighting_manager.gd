extends BaseTest

const M_CHARACTER_LIGHTING_MANAGER := preload("res://scripts/managers/m_character_lighting_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const I_ECS_MANAGER := preload("res://scripts/interfaces/i_ecs_manager.gd")
const I_SCENE_MANAGER := preload("res://scripts/interfaces/i_scene_manager.gd")
const RS_CHARACTER_LIGHTING_PROFILE := preload("res://scripts/resources/lighting/rs_character_lighting_profile.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

const PARAM_EFFECTIVE_TINT := "effective_tint"
const PARAM_EFFECTIVE_INTENSITY := "effective_intensity"


class FakeECSManager extends I_ECSManager:
	var character_entities: Array[Node] = []

	func get_entities_by_tag(tag: StringName) -> Array[Node]:
		if tag != StringName("character"):
			return []
		var results: Array[Node] = []
		for entity in character_entities:
			if entity == null:
				continue
			if not is_instance_valid(entity):
				continue
			results.append(entity)
		return results

	func get_components(_component_type: StringName) -> Array:
		return []

	func query_entities(_required: Array[StringName], _optional: Array[StringName] = []) -> Array:
		return []

	func get_components_for_entity(_entity: Node) -> Dictionary:
		return {}

	func register_component(_component: BaseECSComponent) -> void:
		pass

	func register_system(_system: BaseECSSystem) -> void:
		pass

	func cache_entity_for_node(_node: Node, _entity: Node) -> void:
		pass

	func get_cached_entity_for(_node: Node) -> Node:
		return null

	func update_entity_tags(_entity: Node) -> void:
		pass

	func get_entity_by_id(_id: StringName) -> Node:
		return null

	func mark_systems_dirty() -> void:
		pass

class FakeSceneManager extends I_SceneManager:
	var transitioning: bool = false

	func is_transitioning() -> bool:
		return transitioning

class FakeCharacterLightingSettings extends Node:
	var default_profile: Resource = null

class FakeLightZone extends Node3D:
	var zone_weight: float = 0.0
	var zone_id: StringName = StringName("zone")
	var zone_priority: int = 0
	var profile: Dictionary = {}

	func get_influence_weight(_world_position: Vector3) -> float:
		return zone_weight

	func get_zone_metadata() -> Dictionary:
		return {
			"zone_id": zone_id,
			"priority": zone_priority,
			"blend_weight": zone_weight,
			"profile": profile.duplicate(true),
			"stable_key": String(zone_id),
		}

func test_manager_lifecycle_discovers_dependencies_and_initializes_cache() -> void:
	var context := await _create_manager_context()
	var manager: M_CharacterLightingManager = context.manager

	assert_eq(manager.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(manager.get("_state_store"), context.store)
	assert_eq(manager.get("_scene_manager"), context.scene_manager)
	assert_eq(manager.get("_ecs_manager"), context.ecs_manager)

func test_discovers_zones_and_scene_default_profile_from_lighting_subtree() -> void:
	var context := await _create_manager_context()
	var manager: M_CharacterLightingManager = context.manager

	var default_profile := RS_CHARACTER_LIGHTING_PROFILE.new()
	default_profile.tint = Color(0.2, 0.3, 0.4, 1.0)
	default_profile.intensity = 1.8
	var settings := FakeCharacterLightingSettings.new()
	settings.name = "CharacterLightingSettings"
	settings.default_profile = default_profile
	context.lighting.add_child(settings)
	autofree(settings)

	var zone := FakeLightZone.new()
	zone.zone_weight = 0.5
	context.lighting.add_child(zone)
	autofree(zone)

	manager.refresh_scene_bindings()

	var zones: Array = manager.get("_zones")
	assert_eq(zones.size(), 1)
	assert_eq(zones[0], zone)
	assert_eq(manager.get("_scene_default_profile"), default_profile)

func test_applies_deterministic_weighted_blend_to_character_meshes() -> void:
	var context := await _create_manager_context()
	var manager: M_CharacterLightingManager = context.manager

	var zone_a := FakeLightZone.new()
	zone_a.zone_id = StringName("zone_a")
	zone_a.zone_priority = 2
	zone_a.zone_weight = 0.25
	zone_a.profile = {
		"tint": Color(1.0, 0.0, 0.0, 1.0),
		"intensity": 2.0,
		"blend_smoothing": 0.0
	}
	context.lighting.add_child(zone_a)
	autofree(zone_a)

	var zone_b := FakeLightZone.new()
	zone_b.zone_id = StringName("zone_b")
	zone_b.zone_priority = 2
	zone_b.zone_weight = 0.75
	zone_b.profile = {
		"tint": Color(0.0, 0.0, 1.0, 1.0),
		"intensity": 0.0,
		"blend_smoothing": 0.0
	}
	context.lighting.add_child(zone_b)
	autofree(zone_b)

	manager._physics_process(0.016)

	var override_material := context.character_mesh.material_override as ShaderMaterial
	assert_not_null(override_material, "Character mesh should receive shader override from manager.")
	var tint: Color = override_material.get_shader_parameter(PARAM_EFFECTIVE_TINT)
	assert_almost_eq(tint.r, 0.25, 0.0001)
	assert_almost_eq(tint.b, 0.75, 0.0001)
	assert_almost_eq(float(override_material.get_shader_parameter(PARAM_EFFECTIVE_INTENSITY)), 0.5, 0.0001)

func test_transition_gating_blocks_lighting_application() -> void:
	var context := await _create_manager_context()
	var manager: M_CharacterLightingManager = context.manager

	context.store.set_slice(StringName("scene"), {
		"is_transitioning": true,
		"scene_stack": []
	})
	context.store.set_slice(StringName("navigation"), {
		"shell": StringName("gameplay")
	})

	var zone := FakeLightZone.new()
	zone.zone_weight = 1.0
	zone.profile = {
		"tint": Color(0.5, 0.6, 0.7, 1.0),
		"intensity": 2.0,
		"blend_smoothing": 0.0
	}
	context.lighting.add_child(zone)
	autofree(zone)

	manager._physics_process(0.016)
	assert_null(context.character_mesh.material_override)

func test_scene_swapped_action_invalidates_caches_and_rebinds_to_new_scene() -> void:
	var context := await _create_manager_context()
	var manager: M_CharacterLightingManager = context.manager

	var zone_a := FakeLightZone.new()
	zone_a.zone_id = StringName("zone_a")
	zone_a.zone_weight = 1.0
	zone_a.profile = {
		"tint": Color(1.0, 0.0, 0.0, 1.0),
		"intensity": 1.0,
		"blend_smoothing": 0.0
	}
	context.lighting.add_child(zone_a)
	autofree(zone_a)
	manager.refresh_scene_bindings()

	var old_zones: Array = manager.get("_zones")
	assert_eq(old_zones.size(), 1)

	var replacement := _create_gameplay_scene_with_lighting()
	context.active_scene_container.add_child(replacement.scene_root)
	autofree(replacement.scene_root)
	context.gameplay_scene.queue_free()
	await get_tree().process_frame

	var zone_b := FakeLightZone.new()
	zone_b.zone_id = StringName("zone_b")
	zone_b.zone_weight = 1.0
	zone_b.profile = {
		"tint": Color(0.0, 0.8, 0.2, 1.0),
		"intensity": 1.5,
		"blend_smoothing": 0.0
	}
	replacement.lighting.add_child(zone_b)
	autofree(zone_b)

	context.store.dispatch({
		"type": StringName("scene/swapped"),
		"payload": {"scene_id": StringName("replacement")}
	})
	manager._physics_process(0.016)

	var new_zones: Array = manager.get("_zones")
	assert_eq(new_zones.size(), 1)
	assert_eq(new_zones[0], zone_b)

func test_dynamic_character_changes_apply_to_new_and_restore_removed_entities() -> void:
	var context := await _create_manager_context()
	var manager: M_CharacterLightingManager = context.manager

	var zone := FakeLightZone.new()
	zone.zone_weight = 1.0
	zone.profile = {
		"tint": Color(0.7, 0.7, 0.7, 1.0),
		"intensity": 1.2,
		"blend_smoothing": 0.0
	}
	context.lighting.add_child(zone)
	autofree(zone)

	manager._physics_process(0.016)
	assert_true(context.character_mesh.material_override is ShaderMaterial)

	var added_character := _create_character_entity("E_CharacterB")
	context.entities_root.add_child(added_character.entity)
	autofree(added_character.entity)
	context.ecs_manager.character_entities.append(added_character.entity)

	manager._physics_process(0.016)
	assert_true(added_character.mesh.material_override is ShaderMaterial)

	context.ecs_manager.character_entities.erase(context.character_entity)
	manager._physics_process(0.016)

	assert_null(context.character_mesh.material_override, "Removed character should restore original materials.")
	assert_true(added_character.mesh.material_override is ShaderMaterial)

func _create_manager_context() -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("scene"), {
		"is_transitioning": false,
		"scene_stack": []
	})
	store.set_slice(StringName("navigation"), {
		"shell": StringName("gameplay")
	})
	add_child(store)
	autofree(store)

	var scene_manager := FakeSceneManager.new()
	add_child(scene_manager)
	autofree(scene_manager)

	var ecs_manager := FakeECSManager.new()
	add_child(ecs_manager)
	autofree(ecs_manager)

	U_SERVICE_LOCATOR.register(StringName("state_store"), store)
	U_SERVICE_LOCATOR.register(StringName("scene_manager"), scene_manager)
	U_SERVICE_LOCATOR.register(StringName("ecs_manager"), ecs_manager)

	var root := Node.new()
	root.name = "Root"
	add_child(root)
	autofree(root)

	var managers := Node.new()
	managers.name = "Managers"
	root.add_child(managers)

	var manager := M_CHARACTER_LIGHTING_MANAGER.new()
	manager.name = "M_CharacterLightingManager"
	managers.add_child(manager)
	autofree(manager)

	var viewport_container := Node.new()
	viewport_container.name = "GameViewportContainer"
	root.add_child(viewport_container)
	var viewport := Node.new()
	viewport.name = "GameViewport"
	viewport_container.add_child(viewport)
	var active_scene_container := Node.new()
	active_scene_container.name = "ActiveSceneContainer"
	viewport.add_child(active_scene_container)

	var scene := _create_gameplay_scene_with_lighting()
	active_scene_container.add_child(scene.scene_root)
	autofree(scene.scene_root)

	var entities := Node.new()
	entities.name = "Entities"
	scene.scene_root.add_child(entities)
	autofree(entities)

	var character_data := _create_character_entity("E_CharacterA")
	entities.add_child(character_data.entity)
	autofree(character_data.entity)
	ecs_manager.character_entities = [character_data.entity]

	await get_tree().process_frame

	return {
		"store": store,
		"scene_manager": scene_manager,
		"ecs_manager": ecs_manager,
		"root": root,
		"manager": manager,
		"active_scene_container": active_scene_container,
		"gameplay_scene": scene.scene_root,
		"lighting": scene.lighting,
		"entities_root": entities,
		"character_entity": character_data.entity,
		"character_mesh": character_data.mesh
	}

func _create_gameplay_scene_with_lighting() -> Dictionary:
	var scene_root := Node3D.new()
	scene_root.name = "GameplayScene"
	var lighting := Node.new()
	lighting.name = "Lighting"
	scene_root.add_child(lighting)
	return {
		"scene_root": scene_root,
		"lighting": lighting
	}

func _create_character_entity(node_name: String) -> Dictionary:
	var entity := Node3D.new()
	entity.name = node_name

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BodyMesh"
	var mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var material := StandardMaterial3D.new()
	material.albedo_texture = _create_test_texture()
	mesh.surface_set_material(0, material)
	mesh_instance.mesh = mesh
	entity.add_child(mesh_instance)

	return {
		"entity": entity,
		"mesh": mesh_instance
	}

func _create_test_texture() -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.4, 0.2, 1.0))
	return ImageTexture.create_from_image(image)
