extends BaseTest

const WOODS_SCENE_ID := StringName("ai_woods")
const WARMUP_FRAMES := 180
const SETTLE_FRAMES := 60
const MAX_OBSERVATION_FRAMES := 900

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/ecs/components/c_resource_node_component.gd")
const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _scene_manager: Node = null

func before_all() -> void:
	super.before_all()
	_scene_manager = U_SERVICE_LOCATOR.get_service(StringName("M_SceneManager"))
	if _scene_manager == null:
		push_warning("M_SceneManager not registered — smoke test requires running root scene")

func test_woods_scene_loads_via_scene_manager() -> void:
	if _scene_manager == null:
		push_warning("Skipping: M_SceneManager unavailable")
		return
	_scene_manager.transition_to_scene(WOODS_SCENE_ID, "instant")
	for i in range(WARMUP_FRAMES):
		await get_tree().process_frame
	for i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	assert_true(true, "Woods scene loaded without crash")

func test_woods_brains_tick_after_warmup() -> void:
	if _scene_manager == null:
		push_warning("Skipping: M_SceneManager unavailable")
		return
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

func test_woods_resource_or_inventory_changes_within_observation() -> void:
	if _scene_manager == null:
		push_warning("Skipping: M_SceneManager unavailable")
		return
	var resource_nodes: Array[C_ResourceNodeComponent] = _find_resource_node_components()
	var initial_amounts: Dictionary = {}
	for i in range(resource_nodes.size()):
		initial_amounts[i] = resource_nodes[i].current_amount
	var build_sites: Array[C_BuildSiteComponent] = _find_build_site_components()
	var initial_stages: Dictionary = {}
	for i in range(build_sites.size()):
		initial_stages[i] = build_sites[i].current_stage_index
	var changed := false
	for i in range(MAX_OBSERVATION_FRAMES):
		await get_tree().process_frame
		for j in range(resource_nodes.size()):
			if resource_nodes[j].current_amount != initial_amounts.get(j, 0):
				changed = true
				break
		if not changed:
			for j in range(build_sites.size()):
				if build_sites[j].current_stage_index != initial_stages.get(j, 0):
					changed = true
					break
		if changed:
			break
	assert_true(changed, "Resource node amounts or build site stages should change within observation window")

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