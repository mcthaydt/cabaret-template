extends BaseTest

const U_AI_CONTEXT_BUILDER_PATH := "res://scripts/utils/ai/u_ai_context_builder.gd"
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

class EntityQueryStub extends RefCounted:
	var entity: Node = null
	var _components: Dictionary = {}

	func _init(next_entity: Node, next_components: Dictionary = {}) -> void:
		entity = next_entity
		_components = next_components

	func get_all_components() -> Dictionary:
		return _components

func _load_context_builder_script() -> Script:
	var script_variant: Variant = load(U_AI_CONTEXT_BUILDER_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % U_AI_CONTEXT_BUILDER_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_brain() -> C_AIBrainComponent:
	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	autofree(brain)
	brain.brain_settings = RS_AI_BRAIN_SETTINGS.new()
	return brain

func _new_entity(name: String = "E_TestNPC") -> Node3D:
	var entity := Node3D.new()
	entity.name = name
	autofree(entity)
	return entity

func test_builds_context_with_redux_state_snapshot() -> void:
	var builder_script: Script = _load_context_builder_script()
	if builder_script == null:
		return
	var builder: Variant = builder_script.new()
	var entity: Node3D = _new_entity()
	var brain: C_AIBrainComponent = _new_brain()
	var query: EntityQueryStub = EntityQueryStub.new(entity)
	var redux_state: Dictionary = {"gameplay": {"ai_demo_flags": {}}}

	var context: Dictionary = builder.build(query, brain, redux_state, null, null)
	redux_state["mutated"] = true

	assert_true(context.has("redux_state"))
	assert_true(context.has("state"))
	assert_eq(context["redux_state"].get("mutated", false), true)
	assert_eq(context["state"].get("mutated", false), true)

func test_includes_entity_and_entity_id() -> void:
	var builder_script: Script = _load_context_builder_script()
	if builder_script == null:
		return
	var builder: Variant = builder_script.new()
	var entity: Node3D = _new_entity("E_PatrolDrone")
	var brain: C_AIBrainComponent = _new_brain()
	var query: EntityQueryStub = EntityQueryStub.new(entity)

	var context: Dictionary = builder.build(query, brain, {}, null, null)

	assert_eq(context.get("entity", null), entity)
	assert_eq(context.get("entity_id", StringName()), &"patroldrone")

func test_includes_components_dict() -> void:
	var builder_script: Script = _load_context_builder_script()
	if builder_script == null:
		return
	var builder: Variant = builder_script.new()
	var entity: Node3D = _new_entity()
	var brain: C_AIBrainComponent = _new_brain()
	entity.add_child(brain)
	autofree(brain)
	var manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(manager)
	manager.add_component_to_entity(entity, brain)
	var query: EntityQueryStub = EntityQueryStub.new(entity)

	var context: Dictionary = builder.build(query, brain, {}, null, manager)
	var components_variant: Variant = context.get("components", {})

	assert_true(components_variant is Dictionary)
	if not (components_variant is Dictionary):
		return
	var components: Dictionary = components_variant as Dictionary
	assert_true(components.has(C_AIBrainComponent.COMPONENT_TYPE))
	assert_eq(components.get(C_AIBrainComponent.COMPONENT_TYPE, null), brain)

func test_handles_missing_store_gracefully() -> void:
	var builder_script: Script = _load_context_builder_script()
	if builder_script == null:
		return
	var builder: Variant = builder_script.new()
	var entity: Node3D = _new_entity()
	var brain: C_AIBrainComponent = _new_brain()
	var query: EntityQueryStub = EntityQueryStub.new(entity)

	var context: Dictionary = builder.build(query, brain, {}, null, null)

	assert_false(context.has("state_store"))
	assert_true(context.has("components"))
	var context_key: StringName = builder.context_key_for_context(context)
	assert_eq(context_key, &"testnpc")
