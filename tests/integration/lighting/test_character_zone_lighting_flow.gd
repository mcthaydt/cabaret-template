extends BaseTest

const M_CHARACTER_LIGHTING_MANAGER := preload("res://scripts/managers/m_character_lighting_manager.gd")
const INTER_CHARACTER_LIGHT_ZONE := preload("res://scripts/gameplay/inter_character_light_zone.gd")
const RS_CHARACTER_LIGHTING_PROFILE := preload("res://scripts/resources/lighting/rs_character_lighting_profile.gd")
const RS_CHARACTER_LIGHT_ZONE_CONFIG := preload("res://scripts/resources/lighting/rs_character_light_zone_config.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const I_ECS_MANAGER := preload("res://scripts/interfaces/i_ecs_manager.gd")
const I_SCENE_MANAGER := preload("res://scripts/interfaces/i_scene_manager.gd")

const PARAM_EFFECTIVE_TINT := "effective_tint"
const PARAM_EFFECTIVE_INTENSITY := "effective_intensity"
const TAG_CHARACTER := StringName("character")

class FakeECSManager extends I_ECSManager:
	var character_entities: Array[Node] = []

	func get_entities_by_tag(tag: StringName) -> Array[Node]:
		if tag != TAG_CHARACTER:
			return []
		var resolved: Array[Node] = []
		for entity in character_entities:
			if entity == null or not is_instance_valid(entity):
				continue
			resolved.append(entity)
		return resolved

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

class FakeSceneManager extends I_SCENE_MANAGER:
	var transitioning: bool = false

	func is_transitioning() -> bool:
		return transitioning

class FakeCharacterLightingSettings extends Node:
	var default_profile: Resource = null

func test_overlap_blending_uses_zone_weights_and_registered_external_zone() -> void:
	var context := await _create_lighting_context()
	var warm_profile := _create_profile(Color(1.0, 0.2, 0.1, 1.0), 2.0)
	var cool_profile := _create_profile(Color(0.1, 0.3, 1.0, 1.0), 0.5)

	await _create_zone(context.lighting, warm_profile, StringName("lighting_zone"), 1.0, 4)
	await _create_zone(context.entities_root, cool_profile, StringName("external_zone"), 0.5, 2)
	context.manager.refresh_scene_bindings()

	_process_lighting(context.manager)
	var material := context.character_mesh.material_override as ShaderMaterial
	assert_not_null(material, "Character mesh should receive zone-lighting material override.")

	var tint: Color = material.get_shader_parameter(PARAM_EFFECTIVE_TINT)
	assert_almost_eq(tint.r, 0.7, 0.0001)
	assert_almost_eq(tint.g, 0.233333, 0.0001)
	assert_almost_eq(tint.b, 0.4, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter(PARAM_EFFECTIVE_INTENSITY)), 1.5, 0.0001)

func test_uses_scene_default_profile_when_character_outside_all_zones() -> void:
	var context := await _create_lighting_context()
	context.character_entity.global_position = Vector3(30.0, 0.0, 0.0)

	var profile := _create_profile(Color(0.35, 0.45, 0.7, 1.0), 1.25)
	await _create_zone(context.lighting, profile, StringName("far_zone"), 1.0, 1, Vector3.ZERO, Vector3(2.0, 2.0, 2.0))
	context.manager.refresh_scene_bindings()

	_process_lighting(context.manager)
	var material := context.character_mesh.material_override as ShaderMaterial
	assert_not_null(material)
	var tint: Color = material.get_shader_parameter(PARAM_EFFECTIVE_TINT)
	assert_almost_eq(tint.r, 0.25, 0.0001)
	assert_almost_eq(tint.g, 0.35, 0.0001)
	assert_almost_eq(tint.b, 0.55, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter(PARAM_EFFECTIVE_INTENSITY)), 1.4, 0.0001)

func test_transition_blocking_restores_material_and_resumes_when_unblocked() -> void:
	var context := await _create_lighting_context()
	var profile := _create_profile(Color(0.8, 0.7, 0.2, 1.0), 1.8)
	await _create_zone(context.lighting, profile, StringName("transition_zone"), 1.0, 3)
	context.manager.refresh_scene_bindings()

	_process_lighting(context.manager)
	assert_not_null(context.character_mesh.material_override as ShaderMaterial,
		"Lighting should be active before transition gating is enabled.")

	context.store.set_slice(StringName("scene"), {
		"is_transitioning": true,
		"scene_stack": []
	})
	_process_lighting(context.manager)
	assert_null(context.character_mesh.material_override,
		"Transition gating should restore character materials while blocked.")

	context.store.set_slice(StringName("scene"), {
		"is_transitioning": false,
		"scene_stack": []
	})
	_process_lighting(context.manager)
	assert_not_null(context.character_mesh.material_override as ShaderMaterial,
		"Lighting should resume after transition gating clears.")

func test_respawned_character_inside_zone_receives_lighting() -> void:
	var context := await _create_lighting_context()
	var profile := _create_profile(Color(0.1, 0.9, 0.2, 1.0), 1.6)
	await _create_zone(context.lighting, profile, StringName("respawn_zone"), 1.0, 2)
	context.manager.refresh_scene_bindings()

	_process_lighting(context.manager)
	assert_not_null(context.character_mesh.material_override as ShaderMaterial)

	var respawn := _create_character_entity("E_RespawnedCharacter")
	context.entities_root.add_child(respawn.entity)
	autofree(respawn.entity)
	respawn.entity.global_position = Vector3.ZERO

	var ecs_manager := context.ecs_manager as FakeECSManager
	assert_not_null(ecs_manager)
	ecs_manager.character_entities = [respawn.entity]
	_process_lighting(context.manager)

	assert_null(context.character_mesh.material_override,
		"Removed character should have materials restored after respawn replacement.")
	assert_not_null(respawn.mesh.material_override as ShaderMaterial,
		"Respawned character inside zone should receive lighting on next update.")

func test_partial_zone_influence_blends_toward_scene_default() -> void:
	var context := await _create_lighting_context()
	var profile := _create_profile(Color(0.9, 0.2, 0.1, 1.0), 2.0)
	await _create_zone(
		context.lighting,
		profile,
		StringName("edge_zone"),
		1.0,
		1,
		Vector3.ZERO,
		Vector3(8.0, 4.0, 8.0),
		1.0
	)
	context.character_entity.global_position = Vector3(3.0, 0.0, 0.0)
	context.manager.refresh_scene_bindings()

	_process_lighting(context.manager)
	var material := context.character_mesh.material_override as ShaderMaterial
	assert_not_null(material)

	var tint: Color = material.get_shader_parameter(PARAM_EFFECTIVE_TINT)
	assert_almost_eq(tint.r, 0.4125, 0.0001)
	assert_almost_eq(tint.g, 0.3125, 0.0001)
	assert_almost_eq(tint.b, 0.4375, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter(PARAM_EFFECTIVE_INTENSITY)), 1.55, 0.0001)

func _process_lighting(manager: M_CharacterLightingManager) -> void:
	manager._physics_process(0.016)

func _create_lighting_context() -> Dictionary:
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
	U_ServiceLocator.register(StringName("state_store"), store)

	var scene_manager := FakeSceneManager.new()
	add_child(scene_manager)
	autofree(scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), scene_manager)

	var ecs_manager := FakeECSManager.new()
	add_child(ecs_manager)
	autofree(ecs_manager)
	U_ServiceLocator.register(StringName("ecs_manager"), ecs_manager)

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

	var gameplay_scene := Node3D.new()
	gameplay_scene.name = "GameplayScene"
	active_scene_container.add_child(gameplay_scene)
	autofree(gameplay_scene)

	var lighting := Node.new()
	lighting.name = "Lighting"
	gameplay_scene.add_child(lighting)

	var settings := FakeCharacterLightingSettings.new()
	settings.name = "CharacterLightingSettings"
	settings.default_profile = _create_profile(Color(0.25, 0.35, 0.55, 1.0), 1.4)
	lighting.add_child(settings)
	autofree(settings)

	var entities := Node.new()
	entities.name = "Entities"
	gameplay_scene.add_child(entities)
	autofree(entities)

	var character := _create_character_entity("E_TestCharacter")
	entities.add_child(character.entity)
	autofree(character.entity)
	character.entity.global_position = Vector3.ZERO
	ecs_manager.character_entities = [character.entity]

	await get_tree().process_frame
	await get_tree().process_frame

	return {
		"store": store,
		"scene_manager": scene_manager,
		"ecs_manager": ecs_manager,
		"root": root,
		"manager": manager,
		"active_scene_container": active_scene_container,
		"gameplay_scene": gameplay_scene,
		"lighting": lighting,
		"entities_root": entities,
		"character_entity": character.entity,
		"character_mesh": character.mesh,
	}

func _create_zone(
	parent: Node,
	profile: RS_CharacterLightingProfile,
	zone_id: StringName,
	blend_weight: float = 1.0,
	priority: int = 0,
	position: Vector3 = Vector3.ZERO,
	box_size: Vector3 = Vector3(8.0, 4.0, 8.0),
	falloff: float = 0.0
) -> Inter_CharacterLightZone:
	var config := RS_CHARACTER_LIGHT_ZONE_CONFIG.new()
	config.zone_id = zone_id
	config.shape_type = RS_CharacterLightZoneConfig.ShapeType.BOX
	config.box_size = box_size
	config.falloff = clampf(falloff, 0.0, 1.0)
	config.blend_weight = blend_weight
	config.priority = priority
	config.profile = profile

	var zone := INTER_CHARACTER_LIGHT_ZONE.new()
	zone.name = "Inter_CharacterLightZone_%s" % String(zone_id)
	zone.config = config
	zone.position = position
	parent.add_child(zone)
	autofree(zone)

	await get_tree().process_frame
	await get_tree().process_frame
	return zone

func _create_profile(tint: Color, intensity: float) -> RS_CharacterLightingProfile:
	var profile := RS_CHARACTER_LIGHTING_PROFILE.new()
	profile.tint = tint
	profile.intensity = intensity
	profile.blend_smoothing = 0.0
	return profile

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
	image.fill(Color(0.6, 0.6, 0.6, 1.0))
	return ImageTexture.create_from_image(image)
