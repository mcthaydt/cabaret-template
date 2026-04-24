extends BaseTest

## C10 Commit 1 (TDD RED): entity identification should be tag/metadata-driven,
## not dependent on name prefixes.

const ENTITY_LOOKUP_PATH := "res://scripts/core/utils/ecs/u_entity_lookup.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const BASE_ECS_ENTITY := preload("res://scripts/core/ecs/base_ecs_entity.gd")

var _lookup_script: Script = null

func before_each() -> void:
	super.before_each()
	_lookup_script = load(ENTITY_LOOKUP_PATH) as Script

func after_each() -> void:
	super.after_each()
	_lookup_script = null

func _require_lookup_script() -> bool:
	assert_not_null(
		_lookup_script,
		"Expected U_EntityLookup script at %s (C10 Commit 2 implementation target)." % ENTITY_LOOKUP_PATH
	)
	return _lookup_script != null

func test_find_entity_by_tag_returns_tagged_entity_without_name_prefix() -> void:
	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var player := Node3D.new()
	autofree(player)
	player.name = "HeroCharacter"
	add_child(player)
	ecs_manager.register_entity_tag(StringName("player"), player)

	if not _require_lookup_script():
		return

	var found: Node = _lookup_script.call("find_entity_by_tag", ecs_manager, StringName("player")) as Node
	assert_same(found, player, "Lookup should resolve player by tag even when node name has no E_Player prefix.")

func test_find_entities_by_tag_returns_all_tagged_entities() -> void:
	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var first := Node3D.new()
	autofree(first)
	first.name = "GuardA"
	add_child(first)
	ecs_manager.register_entity_tag(StringName("enemy"), first)

	var second := Node3D.new()
	autofree(second)
	second.name = "GuardB"
	add_child(second)
	ecs_manager.register_entity_tag(StringName("enemy"), second)

	if not _require_lookup_script():
		return

	var found_variant: Variant = _lookup_script.call("find_entities_by_tag", ecs_manager, StringName("enemy"))
	assert_true(found_variant is Array, "Lookup should return an Array for multi-entity tag queries.")
	if not (found_variant is Array):
		return

	var found: Array = found_variant as Array
	assert_eq(found.size(), 2, "Tag query should return both tagged entities.")
	assert_true(found.has(first), "Results should include first tagged entity.")
	assert_true(found.has(second), "Results should include second tagged entity.")

func test_resolve_entity_id_prefers_metadata_over_name_stripping() -> void:
	var entity := Node3D.new()
	autofree(entity)
	entity.name = "E_Player"
	entity.set_meta("entity_id", StringName("primary_player"))

	if not _require_lookup_script():
		return

	var resolved: Variant = _lookup_script.call("resolve_entity_id", entity)
	assert_eq(StringName(String(resolved)), StringName("primary_player"),
		"resolve_entity_id should prefer explicit metadata before deriving IDs from node names.")

func test_resolve_entity_id_falls_back_to_current_name_based_behavior() -> void:
	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	autofree(entity)
	entity.name = "E_Player"

	if not _require_lookup_script():
		return

	var resolved: Variant = _lookup_script.call("resolve_entity_id", entity)
	assert_eq(StringName(String(resolved)), StringName("player"),
		"resolve_entity_id should keep current name-based fallback when metadata is absent.")
