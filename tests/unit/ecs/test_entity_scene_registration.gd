extends BaseTest

const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const SCENE_BASE := preload("res://scenes/templates/tmpl_base_scene.tscn")
const SCENE_EXTERIOR := preload("res://scenes/gameplay/gameplay_exterior.tscn")
const SCENE_INTERIOR := preload("res://scenes/gameplay/gameplay_interior_house.tscn")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")

var _state_store: M_StateStore = null
var _spawn_manager: M_SpawnManager = null

func before_each() -> void:
	super.before_each()
	_state_store = M_STATE_STORE.new()
	add_child_autofree(_state_store)
	await get_tree().process_frame
	# Register state_store with ServiceLocator so managers can find it
	U_ServiceLocator.register(StringName("state_store"), _state_store)

	# Create spawn_manager (required by gameplay scenes)
	_spawn_manager = M_SPAWN_MANAGER.new()
	add_child_autofree(_spawn_manager)
	await get_tree().process_frame
	U_ServiceLocator.register(StringName("spawn_manager"), _spawn_manager)

func _await_ecs_registration() -> void:
	await get_tree().process_frame
	await wait_physics_frames(2)  # Components register via deferred calls

func _assert_tags(entity: BaseECSEntity, expected_tags: Array[StringName], label: String) -> void:
	var entity_tags: Array[StringName] = entity.get_tags()
	var expected_sorted: Array[String] = _sort_tags(expected_tags)
	var actual_sorted: Array[String] = _sort_tags(entity_tags)
	assert_eq(actual_sorted, expected_sorted, "%s tags should match" % label)

func _sort_tags(tags: Array) -> Array[String]:
	var sorted: Array[String] = []
	for tag in tags:
		sorted.append(String(tag))
	sorted.sort()
	return sorted

func _assert_expected_entities(scene: Node, expected: Dictionary) -> void:
	var manager: M_ECSManager = U_ECSUtils.get_manager(scene)
	for id in expected.keys():
		var entity: Node = null
		if manager:
			entity = manager.get_entity_by_id(StringName(id))
		if entity == null:
			entity = _find_entity_by_id(scene, StringName(id))
		assert_not_null(entity, "Entity '%s' should exist in scene tree" % id)
		assert_true(entity is BaseECSEntity, "Entity '%s' should extend BaseECSEntity" % id)
		var expected_tags: Array[StringName] = []
		for tag in expected[id]:
			expected_tags.append(StringName(tag))
		_assert_tags(entity as BaseECSEntity, expected_tags, "Entity %s" % id)

func _find_entity_by_id(root: Node, id: StringName) -> BaseECSEntity:
	if root is BaseECSEntity and (root as BaseECSEntity).get_entity_id() == id:
		return root as BaseECSEntity
	for child in root.get_children():
		if not (child is Node):
			continue
		var found := _find_entity_by_id(child, id)
		if found != null:
			return found
	return null

func test_tmpl_base_scene_registers_player_and_camera() -> void:
	var scene := SCENE_BASE.instantiate()
	add_child_autofree(scene)
	await _await_ecs_registration()

	var expected: Dictionary = {
		StringName("player"): [StringName("player"), StringName("character")],
		StringName("camera"): [StringName("camera")]
	}

	_assert_expected_entities(scene, expected)

func test_gameplay_exterior_entities_register_ids_and_tags() -> void:
	var scene := SCENE_EXTERIOR.instantiate()
	add_child_autofree(scene)
	await _await_ecs_registration()

	var expected: Dictionary = {
		StringName("door_to_house"): [StringName("trigger"), StringName("door")],
		StringName("deathzone_exterior"): [StringName("hazard"), StringName("death")],
		StringName("spiketrap_a"): [StringName("hazard"), StringName("trap")],
		StringName("spiketrap_b"): [StringName("hazard"), StringName("trap")],
		StringName("checkpoint_exterior"): [StringName("checkpoint"), StringName("objective")],
		StringName("tutorial_exterior"): [StringName("interactable"), StringName("tutorial")],
		StringName("finalgoal"): [StringName("objective"), StringName("endgame")]
	}

	_assert_expected_entities(scene, expected)

func test_gameplay_interior_entities_register_ids_and_tags() -> void:
	var scene := SCENE_INTERIOR.instantiate()
	add_child_autofree(scene)
	await _await_ecs_registration()

	var expected: Dictionary = {
		StringName("door_to_exterior"): [StringName("trigger"), StringName("door")],
		StringName("deathzone_interior"): [StringName("hazard"), StringName("death")],
		StringName("goalzone_interior"): [StringName("objective"), StringName("goal")],
		StringName("tutorial_interior"): [StringName("interactable"), StringName("tutorial")]
	}

	_assert_expected_entities(scene, expected)
