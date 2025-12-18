extends BaseTest

## Tests for entity ID and tagging system (Phase 6 - T063)

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

var _manager: M_ECSManager = null

func before_each() -> void:
	super.before_each()
	U_ECS_EVENT_BUS.reset()
	_manager = _spawn_manager()

func _spawn_manager() -> M_ECSManager:
	var manager := ECS_MANAGER.new()
	add_child_autofree(manager)
	return manager

func _spawn_entity(node_name: String) -> BaseECSEntity:
	var entity: BaseECSEntity = ECS_ENTITY.new()
	entity.name = node_name
	add_child_autofree(entity)
	return entity

func _spawn_component(entity: Node, component_script: Script) -> BaseECSComponent:
	var component: BaseECSComponent = component_script.new()
	entity.add_child(component)
	return component

func _set_entity_tags(entity: Node, tags_list: Array) -> void:
	var typed_tags: Array[StringName] = []
	for tag in tags_list:
		typed_tags.append(tag)
	entity.tags = typed_tags

## ========================================
## T063b: ID Generation Tests
## ========================================

func test_entity_id_generated_from_name() -> void:
	var entity := _spawn_entity("E_Player")

	var entity_id: StringName = entity.get_entity_id()

	assert_eq(entity_id, StringName("player"), "Should strip E_ prefix and lowercase")

func test_entity_id_strips_e_prefix() -> void:
	var entity := _spawn_entity("E_Goblin_1")

	var entity_id: StringName = entity.get_entity_id()

	assert_eq(entity_id, StringName("goblin_1"), "Should strip E_ prefix")

func test_entity_id_lowercase() -> void:
	var entity := _spawn_entity("E_PLAYER")

	var entity_id: StringName = entity.get_entity_id()

	assert_eq(entity_id, StringName("player"), "Should convert to lowercase")

func test_entity_id_manual_override() -> void:
	var entity := _spawn_entity("E_Player")
	entity.entity_id = StringName("hero")

	var entity_id: StringName = entity.get_entity_id()

	assert_eq(entity_id, StringName("hero"), "Should use manual override")

func test_entity_id_caching() -> void:
	var entity := _spawn_entity("E_Player")

	var id1: StringName = entity.get_entity_id()
	var id2: StringName = entity.get_entity_id()

	assert_eq(id1, id2, "Should return cached ID")

func test_entity_id_without_e_prefix() -> void:
	var entity := _spawn_entity("Player")

	var entity_id: StringName = entity.get_entity_id()

	assert_eq(entity_id, StringName("player"), "Should work without E_ prefix")

## ========================================
## T063c: Duplicate ID Tests
## ========================================

func test_duplicate_id_gets_suffix() -> void:
	var entity1 := _spawn_entity("E_Player")
	var entity2 := _spawn_entity("E_Enemy")

	# Manually set both to same ID to test duplicate handling
	entity1.entity_id = StringName("player")
	entity2.entity_id = StringName("player")

	_manager.register_entity(entity1)
	_manager.register_entity(entity2)

	var id1: StringName = _manager._registered_entities[entity1]
	var id2: StringName = _manager._registered_entities[entity2]

	assert_eq(id1, StringName("player"), "First entity keeps original ID")
	assert_ne(id2, StringName("player"), "Second entity gets modified ID")
	assert_true(String(id2).begins_with("player_"), "Second entity ID should have suffix")

func test_duplicate_id_logs_warning() -> void:
	var entity1 := _spawn_entity("E_Player")
	var entity2 := _spawn_entity("E_Enemy")

	# Manually set both to same ID to test duplicate handling
	entity1.entity_id = StringName("player")
	entity2.entity_id = StringName("player")

	_manager.register_entity(entity1)

	# GUT doesn't have push_warning assertions, but we can verify the behavior
	_manager.register_entity(entity2)

	# Both should be registered with different IDs
	assert_true(_manager._registered_entities.has(entity1), "First entity registered")
	assert_true(_manager._registered_entities.has(entity2), "Second entity registered")

func test_duplicate_id_updates_entity() -> void:
	var entity1 := _spawn_entity("E_Player")
	var entity2 := _spawn_entity("E_Enemy")

	# Manually set both to same ID to test duplicate handling
	entity1.entity_id = StringName("player")
	entity2.entity_id = StringName("player")

	_manager.register_entity(entity1)
	_manager.register_entity(entity2)

	var id2: StringName = entity2.get_entity_id()

	assert_true(String(id2).begins_with("player_"), "Entity should be updated with new ID")

## ========================================
## T063d: Tag Tests
## ========================================

func test_entity_tags_indexed() -> void:
	var entity := _spawn_entity("E_Player")
	var test_tags: Array[StringName] = [StringName("player"), StringName("controllable")]
	entity.tags = test_tags

	_manager.register_entity(entity)

	var player_entities := _manager.get_entities_by_tag(StringName("player"))
	var controllable_entities := _manager.get_entities_by_tag(StringName("controllable"))

	assert_eq(player_entities.size(), 1, "Should find entity by 'player' tag")
	assert_eq(controllable_entities.size(), 1, "Should find entity by 'controllable' tag")
	assert_eq(player_entities[0], entity, "Should return correct entity")

func test_entity_multiple_tags() -> void:
	var entity := _spawn_entity("E_Enemy")
	_set_entity_tags(entity, [StringName("enemy"), StringName("hostile"), StringName("goblin")])

	_manager.register_entity(entity)

	var enemy_entities := _manager.get_entities_by_tag(StringName("enemy"))
	var hostile_entities := _manager.get_entities_by_tag(StringName("hostile"))
	var goblin_entities := _manager.get_entities_by_tag(StringName("goblin"))

	assert_eq(enemy_entities.size(), 1, "Should find by 'enemy' tag")
	assert_eq(hostile_entities.size(), 1, "Should find by 'hostile' tag")
	assert_eq(goblin_entities.size(), 1, "Should find by 'goblin' tag")

func test_get_entities_by_tags_any() -> void:
	var entity1 := _spawn_entity("E_Player")
	_set_entity_tags(entity1, [StringName("player"), StringName("controllable")])
	var entity2 := _spawn_entity("E_Enemy")
	_set_entity_tags(entity2, [StringName("enemy"), StringName("hostile")])
	var entity3 := _spawn_entity("E_NPC")
	_set_entity_tags(entity3, [StringName("npc"), StringName("friendly")])

	_manager.register_entity(entity1)
	_manager.register_entity(entity2)
	_manager.register_entity(entity3)

	var results := _manager.get_entities_by_tags([StringName("player"), StringName("enemy")], false)

	assert_eq(results.size(), 2, "Should find entities with ANY of the tags")
	assert_true(results.has(entity1), "Should include player")
	assert_true(results.has(entity2), "Should include enemy")
	assert_false(results.has(entity3), "Should not include NPC")

func test_get_entities_by_tags_all() -> void:
	var entity1 := _spawn_entity("E_Player")
	_set_entity_tags(entity1, [StringName("player"), StringName("controllable"), StringName("hero")])
	var entity2 := _spawn_entity("E_Enemy")
	_set_entity_tags(entity2, [StringName("enemy"), StringName("hostile")])
	var entity3 := _spawn_entity("E_NPC")
	_set_entity_tags(entity3, [StringName("npc"), StringName("friendly"), StringName("hero")])

	_manager.register_entity(entity1)
	_manager.register_entity(entity2)
	_manager.register_entity(entity3)

	var results := _manager.get_entities_by_tags([StringName("hero"), StringName("player")], true)

	assert_eq(results.size(), 1, "Should find only entities with ALL tags")
	assert_eq(results[0], entity1, "Should only return player with both tags")

func test_get_entity_tags() -> void:
	var entity := _spawn_entity("E_Player")
	_set_entity_tags(entity, [StringName("player"), StringName("controllable")])

	var tags: Array[StringName] = entity.get_tags()

	assert_eq(tags.size(), 2, "Should return all tags")
	assert_true(tags.has(StringName("player")), "Should include 'player' tag")
	assert_true(tags.has(StringName("controllable")), "Should include 'controllable' tag")

func test_has_tag() -> void:
	var entity := _spawn_entity("E_Player")
	_set_entity_tags(entity, [StringName("player")])

	assert_true(entity.has_tag(StringName("player")), "Should have 'player' tag")
	assert_false(entity.has_tag(StringName("enemy")), "Should not have 'enemy' tag")

## ========================================
## T063e: Registration/Unregistration Tests
## ========================================

func test_entity_registered_on_component_add() -> void:
	var entity := _spawn_entity("E_Player")

	# Create a minimal component that validates (extend BaseECSComponent)
	var component_script := GDScript.new()
	component_script.source_code = """
extends BaseECSComponent
func get_component_type() -> StringName:
	return StringName("TestComponent")
"""
	component_script.reload()

	var component := _spawn_component(entity, component_script)
	_manager.register_component(component)

	assert_true(_manager._registered_entities.has(entity), "Entity should auto-register")
	assert_eq(_manager.get_entity_by_id(StringName("player")), entity, "Should be findable by ID")

func test_entity_unregister_removes_from_indexes() -> void:
	var entity := _spawn_entity("E_Player")
	_set_entity_tags(entity, [StringName("player")])

	_manager.register_entity(entity)
	assert_true(_manager._registered_entities.has(entity), "Entity should be registered")

	_manager.unregister_entity(entity)

	assert_false(_manager._registered_entities.has(entity), "Entity should be unregistered")
	assert_null(_manager.get_entity_by_id(StringName("player")), "Should not be findable by ID")
	assert_eq(_manager.get_entities_by_tag(StringName("player")).size(), 0, "Should not be in tag index")

func test_entity_events_published() -> void:
	var entity := _spawn_entity("E_Player")

	_manager.register_entity(entity)

	var history := U_ECS_EVENT_BUS.get_event_history()

	assert_gt(history.size(), 0, "Should have events in history")
	var found_registered := false
	for event in history:
		if event["name"] == StringName("entity_registered"):
			found_registered = true
			assert_eq(event["payload"]["entity_id"], StringName("player"), "Event should have entity_id")
			assert_eq(event["payload"]["entity"], entity, "Event should have entity reference")
			break

	assert_true(found_registered, "Should publish entity_registered event")

func test_entity_unregister_event_published() -> void:
	var entity := _spawn_entity("E_Player")
	_manager.register_entity(entity)

	U_ECS_EVENT_BUS.clear_history()
	_manager.unregister_entity(entity)

	var history := U_ECS_EVENT_BUS.get_event_history()

	var found_unregistered := false
	for event in history:
		if event["name"] == StringName("entity_unregistered"):
			found_unregistered = true
			assert_eq(event["payload"]["entity_id"], StringName("player"), "Event should have entity_id")
			break

	assert_true(found_unregistered, "Should publish entity_unregistered event")

## ========================================
## T063f: Tag Modification Tests
## ========================================

func test_add_tag_updates_index() -> void:
	var entity := _spawn_entity("E_Player")
	_manager.register_entity(entity)

	entity.add_tag(StringName("hero"))

	var hero_entities := _manager.get_entities_by_tag(StringName("hero"))
	assert_eq(hero_entities.size(), 1, "Should find entity by new tag")
	assert_eq(hero_entities[0], entity, "Should return correct entity")

func test_remove_tag_updates_index() -> void:
	var entity := _spawn_entity("E_Player")
	_set_entity_tags(entity, [StringName("player"), StringName("hero")])
	_manager.register_entity(entity)

	entity.remove_tag(StringName("hero"))

	var hero_entities := _manager.get_entities_by_tag(StringName("hero"))
	assert_eq(hero_entities.size(), 0, "Should not find entity by removed tag")

	var player_entities := _manager.get_entities_by_tag(StringName("player"))
	assert_eq(player_entities.size(), 1, "Should still find by remaining tag")

func test_add_tag_duplicate_ignored() -> void:
	var entity := _spawn_entity("E_Player")
	_set_entity_tags(entity, [StringName("player")])
	_manager.register_entity(entity)

	entity.add_tag(StringName("player"))

	var tags: Array[StringName] = entity.get_tags()
	assert_eq(tags.size(), 1, "Should not add duplicate tag")

func test_remove_nonexistent_tag_safe() -> void:
	var entity := _spawn_entity("E_Player")
	_manager.register_entity(entity)

	entity.remove_tag(StringName("nonexistent"))

	# Should not crash, just do nothing
	pass_test("Should handle removing nonexistent tag safely")

## ========================================
## Additional Integration Tests
## ========================================

func test_get_all_entity_ids() -> void:
	var entity1 := _spawn_entity("E_Player")
	var entity2 := _spawn_entity("E_Enemy")

	_manager.register_entity(entity1)
	_manager.register_entity(entity2)

	var all_ids := _manager.get_all_entity_ids()

	assert_eq(all_ids.size(), 2, "Should return all entity IDs")
	assert_true(all_ids.has(StringName("player")), "Should include player ID")
	assert_true(all_ids.has(StringName("enemy")), "Should include enemy ID")

func test_u_ecs_utils_get_entity_id() -> void:
	var entity := _spawn_entity("E_Player")

	var entity_id := U_ECS_UTILS.get_entity_id(entity)

	assert_eq(entity_id, StringName("player"), "U_ECSUtils should get entity ID")

func test_u_ecs_utils_get_entity_tags() -> void:
	var entity := _spawn_entity("E_Player")
	_set_entity_tags(entity, [StringName("player"), StringName("hero")])

	var tags := U_ECS_UTILS.get_entity_tags(entity)

	assert_eq(tags.size(), 2, "U_ECSUtils should get entity tags")
	assert_true(tags.has(StringName("player")), "Should include player tag")
	assert_true(tags.has(StringName("hero")), "Should include hero tag")

func test_u_ecs_utils_build_entity_snapshot() -> void:
	var entity := _spawn_entity("E_Player")
	_set_entity_tags(entity, [StringName("player")])
	entity.global_position = Vector3(1, 2, 3)

	var snapshot := U_ECS_UTILS.build_entity_snapshot(entity)

	assert_eq(snapshot["entity_id"], "player", "Snapshot should include entity_id as String")
	assert_eq(snapshot["tags"].size(), 1, "Snapshot should include tags")
	assert_eq(snapshot["position"], Vector3(1, 2, 3), "Snapshot should include position")
