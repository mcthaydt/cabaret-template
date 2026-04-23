extends BaseTest

const WOODS_SCENE_ID := StringName("ai_woods")
const WARMUP_FRAMES := 180
const SETTLE_FRAMES := 60
const MAX_OBSERVATION_FRAMES := 1800
const MAX_LONG_OBSERVATION_FRAMES := 3600
const MAX_STAGE_ADVANCE_GRACE_FRAMES := 900
const MAX_STAGE_TWO_REACH_FRAMES := 3600
const MAX_STAGE_TWO_PROGRESS_FRAMES := 3600
const MAX_RABBIT_RADIUS_FROM_SPAWN := 30.0

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/ecs/components/c_resource_node_component.gd")
const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
const I_ECS_MANAGER := preload("res://scripts/interfaces/i_ecs_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const ROOT_SCENE := preload("res://scenes/root.tscn")

var _scene_manager: Node = null
var _root_harness: Node = null

func before_each() -> void:
	super.before_each()
	_scene_manager = null
	_root_harness = null

func test_woods_scene_loads_via_scene_manager() -> void:
	var is_ready: bool = await _ensure_scene_manager_ready()
	assert_true(is_ready, "scene_manager service must exist after root harness bootstrap")
	if not is_ready:
		return
	await _load_woods_scene()
	assert_true(true, "Woods scene loaded without crash")

func test_woods_brains_tick_after_warmup() -> void:
	var is_ready: bool = await _ensure_scene_manager_ready()
	assert_true(is_ready, "scene_manager service must exist after root harness bootstrap")
	if not is_ready:
		return
	await _load_woods_scene()
	var brains: Array[C_AIBrainComponent] = _find_brain_components()
	assert_gt(brains.size(), 0, "Woods scene should have at least one AI brain")
	var any_ticked := false
	for brain in brains:
		if brain.bt_state_bag.size() > 0:
			any_ticked = true
			break
	if not any_ticked:
		for i in range(MAX_OBSERVATION_FRAMES):
			await get_tree().process_frame
			for brain in brains:
				if brain.bt_state_bag.size() > 0:
					any_ticked = true
					break
			if any_ticked:
				break
	assert_true(any_ticked, "At least one brain should have ticked within observation window")

func test_woods_scene_contains_visible_showcase_archetypes() -> void:
	var is_ready: bool = await _ensure_scene_manager_ready()
	assert_true(is_ready, "scene_manager service must exist after root harness bootstrap")
	if not is_ready:
		return
	await _load_woods_scene(8, 8)
	var builder: Node = _find_entity_by_id(&"builder")
	var wolf: Node = _find_entity_by_id(&"wolf")
	var rabbits: Array[Node] = _find_entities_by_tag(&"prey")
	assert_not_null(builder, "Woods scene should contain one Builder entity.")
	assert_not_null(wolf, "Woods scene should contain one Wolf entity.")
	assert_eq(rabbits.size(), 4, "Woods scene should contain exactly four prey-tagged Rabbits.")
	assert_false(_entity_has_tag(builder, &"prey"), "Builder must not be wolf prey; the primary loop should not be derailed.")
	assert_true(_has_debug_label(builder), "Builder should have a visible debug/name label.")
	assert_true(_has_debug_label(wolf), "Wolf should have a visible debug/name label.")
	for rabbit in rabbits:
		assert_true(_has_debug_label(rabbit), "Rabbit %s should have a visible debug/name label." % str(U_ECS_UTILS.get_entity_id(rabbit)))

func test_woods_resource_or_inventory_changes_within_observation() -> void:
	var is_ready: bool = await _ensure_scene_manager_ready()
	assert_true(is_ready, "scene_manager service must exist after root harness bootstrap")
	if not is_ready:
		return
	await _load_woods_scene()
	var resource_nodes: Array[C_ResourceNodeComponent] = _find_resource_node_components()
	var initial_amounts: Dictionary = {}
	for i in range(resource_nodes.size()):
		initial_amounts[i] = resource_nodes[i].current_amount
	var build_sites: Array[C_BuildSiteComponent] = _find_build_site_components()
	var initial_stages: Dictionary = {}
	for i in range(build_sites.size()):
		initial_stages[i] = build_sites[i].current_stage_index
	var resource_changed := false
	var stage_advanced := false
	for i in range(MAX_OBSERVATION_FRAMES):
		await get_tree().process_frame
		for j in range(resource_nodes.size()):
			if resource_nodes[j].current_amount != initial_amounts.get(j, 0):
				resource_changed = true
				break
		for j in range(build_sites.size()):
			if build_sites[j].current_stage_index > int(initial_stages.get(j, 0)):
				stage_advanced = true
				break
		if resource_changed and stage_advanced:
			break
	assert_true(resource_changed, "Builder should harvest at least one resource within observation window")
	assert_true(stage_advanced, "Builder should advance construction stage 0 -> 1 within observation window")

func test_woods_rabbits_remain_within_bounded_radius() -> void:
	var is_ready: bool = await _ensure_scene_manager_ready()
	assert_true(is_ready, "scene_manager service must exist after root harness bootstrap")
	if not is_ready:
		return
	await _load_woods_scene(8, 8)
	var rabbits: Array[Node] = _find_entities_by_tag(&"prey")
	assert_eq(rabbits.size(), 4, "Expected four rabbit entities for bounds validation.")
	if rabbits.size() != 4:
		return
	var spawn_positions: Dictionary = {}
	for rabbit in rabbits:
		if not is_instance_valid(rabbit):
			continue
		if rabbit is Node3D:
			spawn_positions[U_ECS_UTILS.get_entity_id(rabbit)] = (rabbit as Node3D).global_position
	for i in range(MAX_LONG_OBSERVATION_FRAMES):
		await get_tree().process_frame
	for rabbit in rabbits:
		if not is_instance_valid(rabbit):
			continue
		if not (rabbit is Node3D):
			continue
		var rabbit_id: StringName = U_ECS_UTILS.get_entity_id(rabbit)
		var start_variant: Variant = spawn_positions.get(rabbit_id, null)
		if not (start_variant is Vector3):
			continue
		var start: Vector3 = start_variant as Vector3
		var current: Vector3 = (rabbit as Node3D).global_position
		var offset_xz := Vector2(current.x - start.x, current.z - start.z)
		assert_true(
			offset_xz.length() <= MAX_RABBIT_RADIUS_FROM_SPAWN,
			"Rabbit %s drifted beyond bounds (distance=%.2f)." % [rabbit_id, offset_xz.length()]
		)

func test_woods_builder_advances_beyond_mixed_material_stage() -> void:
	var is_ready: bool = await _ensure_scene_manager_ready()
	assert_true(is_ready, "scene_manager service must exist after root harness bootstrap")
	if not is_ready:
		return
	await _load_woods_scene()
	var build_sites: Array[C_BuildSiteComponent] = _find_build_site_components()
	assert_gt(build_sites.size(), 0, "Expected at least one build site in woods scene.")
	if build_sites.is_empty():
		return
	var reached_stage_two: bool = false
	var advanced_past_stage_two: bool = false
	var deposited_stone_for_walls: bool = false
	for i in range(MAX_STAGE_TWO_REACH_FRAMES):
		await get_tree().process_frame
		for build_site in build_sites:
			if build_site.current_stage_index >= 2:
				reached_stage_two = true
			if build_site.current_stage_index >= 3:
				advanced_past_stage_two = true
			if int(build_site.placed_materials.get(&"stone", 0)) >= 1:
				deposited_stone_for_walls = true
		if reached_stage_two or advanced_past_stage_two:
			break
	assert_true(reached_stage_two or advanced_past_stage_two, "Builder should reach walls stage (stage_index=2) within observation window.")
	if advanced_past_stage_two:
		deposited_stone_for_walls = true
	else:
		for i in range(MAX_STAGE_TWO_PROGRESS_FRAMES):
			await get_tree().process_frame
			for build_site in build_sites:
				if build_site.current_stage_index >= 3:
					advanced_past_stage_two = true
				if int(build_site.placed_materials.get(&"stone", 0)) >= 1:
					deposited_stone_for_walls = true
			if advanced_past_stage_two and deposited_stone_for_walls:
				break
	if deposited_stone_for_walls and not advanced_past_stage_two:
		for i in range(MAX_STAGE_ADVANCE_GRACE_FRAMES):
			await get_tree().process_frame
			for build_site in build_sites:
				if build_site.current_stage_index >= 3:
					advanced_past_stage_two = true
					break
			if advanced_past_stage_two:
				break
	assert_true(deposited_stone_for_walls, "Builder should deposit stone to satisfy mixed-material walls stage.")
	assert_true(advanced_past_stage_two, "Builder should advance beyond stage_index=2 after satisfying walls stage materials.")

func _load_woods_scene(warmup_frames: int = WARMUP_FRAMES, settle_frames: int = SETTLE_FRAMES) -> void:
	_scene_manager.transition_to_scene(WOODS_SCENE_ID, "instant")
	var scene_id_resolved: bool = false
	for i in range(120):
		await get_tree().process_frame
		if _scene_manager != null and _scene_manager.get_current_scene() == WOODS_SCENE_ID:
			scene_id_resolved = true
			break
	if scene_id_resolved:
		await _wait_for_woods_entities_ready()
	for i in range(maxi(warmup_frames, 0)):
		await get_tree().process_frame
	for i in range(maxi(settle_frames, 0)):
		await get_tree().process_frame

func _wait_for_woods_entities_ready(max_frames: int = 180) -> void:
	for i in range(maxi(max_frames, 0)):
		var builder: Node = _find_entity_by_id(&"builder")
		var wolf: Node = _find_entity_by_id(&"wolf")
		var rabbits: Array[Node] = _find_entities_by_tag(&"prey")
		if builder != null and wolf != null and rabbits.size() >= 4:
			return
		await get_tree().process_frame

func _ensure_scene_manager_ready() -> bool:
	_scene_manager = U_SERVICE_LOCATOR.try_get_service(&"scene_manager")
	if _scene_manager != null:
		return true
	if ROOT_SCENE == null:
		return false
	_root_harness = ROOT_SCENE.instantiate()
	if _root_harness == null:
		return false
	get_tree().root.add_child(_root_harness)
	autofree(_root_harness)
	for i in range(5):
		await get_tree().process_frame
	_scene_manager = U_SERVICE_LOCATOR.try_get_service(&"scene_manager")
	return _scene_manager != null

func _find_brain_components() -> Array[C_AIBrainComponent]:
	var result: Array[C_AIBrainComponent] = []
	var root := get_tree().root
	if root == null:
		return result
	_collect_brain_components(root, result)
	return result

func _collect_brain_components(node: Node, out: Array[C_AIBrainComponent]) -> void:
	if node is C_AIBrainComponent:
		out.append(node as C_AIBrainComponent)
	for child in node.get_children():
		_collect_brain_components(child, out)

func _find_entity_by_id(entity_id: StringName) -> Node:
	var ecs_manager := _get_ecs_manager()
	if ecs_manager != null:
		var from_manager: Node = ecs_manager.get_entity_by_id(entity_id)
		if from_manager != null and is_instance_valid(from_manager):
			return from_manager
	var root := get_tree().root
	if root == null:
		return null
	return _find_entity_by_id_recursive(root, entity_id)

func _find_entity_by_id_recursive(node: Node, entity_id: StringName) -> Node:
	if U_ECS_UTILS.get_entity_id(node) == entity_id:
		return node
	for child in node.get_children():
		var found: Node = _find_entity_by_id_recursive(child, entity_id)
		if found != null:
			return found
	return null

func _find_entities_by_tag(tag: StringName) -> Array[Node]:
	var ecs_manager := _get_ecs_manager()
	if ecs_manager != null:
		var managed_entities: Array[Node] = ecs_manager.get_entities_by_tag(tag)
		if not managed_entities.is_empty():
			return managed_entities
	var result: Array[Node] = []
	var root := get_tree().root
	if root == null:
		return result
	_collect_entities_by_tag(root, tag, result)
	return result

func _get_ecs_manager() -> I_ECSManager:
	return U_SERVICE_LOCATOR.try_get_service(&"ecs_manager") as I_ECSManager

func _collect_entities_by_tag(node: Node, tag: StringName, out: Array[Node]) -> void:
	if _entity_has_tag(node, tag):
		out.append(node)
	for child in node.get_children():
		_collect_entities_by_tag(child, tag, out)

func _entity_has_tag(entity: Node, tag: StringName) -> bool:
	if entity == null:
		return false
	if not entity.has_method("get_tags"):
		return false
	var tags_variant: Variant = entity.call("get_tags")
	if not (tags_variant is Array):
		return false
	return (tags_variant as Array).has(tag)

func _has_debug_label(entity: Node) -> bool:
	if entity == null:
		return false
	return entity.get_node_or_null("DebugWoodsAgentLabel") != null

func _find_resource_node_components() -> Array[C_ResourceNodeComponent]:
	var result: Array[C_ResourceNodeComponent] = []
	var root := get_tree().root
	if root == null:
		return result
	_collect_resource_nodes(root, result)
	return result

func _collect_resource_nodes(node: Node, out: Array[C_ResourceNodeComponent]) -> void:
	if node is C_ResourceNodeComponent:
		out.append(node as C_ResourceNodeComponent)
	for child in node.get_children():
		_collect_resource_nodes(child, out)

func _find_build_site_components() -> Array[C_BuildSiteComponent]:
	var result: Array[C_BuildSiteComponent] = []
	var root := get_tree().root
	if root == null:
		return result
	_collect_build_sites(root, result)
	return result

func _collect_build_sites(node: Node, out: Array[C_BuildSiteComponent]) -> void:
	if node is C_BuildSiteComponent:
		out.append(node as C_BuildSiteComponent)
	for child in node.get_children():
		_collect_build_sites(child, out)
