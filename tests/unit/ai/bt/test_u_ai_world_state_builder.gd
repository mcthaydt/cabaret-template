extends GutTest

const U_AI_WORLD_STATE_BUILDER_PATH := "res://scripts/core/utils/ai/u_ai_world_state_builder.gd"
const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/core/ecs/components/c_movement_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/demo/ecs/components/c_needs_component.gd")
const C_HEALTH_COMPONENT := preload("res://scripts/core/ecs/components/c_health_component.gd")

class EntityQueryStub extends RefCounted:
	var entity: Node = null
	var _components: Dictionary = {}

	func _init(next_entity: Node, next_components: Dictionary) -> void:
		entity = next_entity
		_components = next_components

	func get_all_components() -> Dictionary:
		return _components

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to load: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_builder() -> Object:
	var builder_script: Script = _load_script(U_AI_WORLD_STATE_BUILDER_PATH)
	if builder_script == null:
		return null
	var builder_variant: Variant = builder_script.new()
	assert_not_null(builder_variant, "Expected U_AIWorldStateBuilder.new() to succeed")
	if builder_variant == null or not (builder_variant is Object):
		return null
	return builder_variant as Object

func _new_entity(name: String = "E_TestNPC") -> Node3D:
	var entity := Node3D.new()
	entity.name = name
	autofree(entity)
	return entity

func _build_world_state(builder: Object, query: EntityQueryStub) -> Dictionary:
	var state_variant: Variant = builder.call("build", query)
	assert_true(state_variant is Dictionary, "build() should return a Dictionary")
	if not (state_variant is Dictionary):
		return {}
	return state_variant as Dictionary

func test_build_reads_selected_components_into_flat_world_state_dictionary() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return

	var entity: Node3D = _new_entity("E_PatrolDrone")
	var brain := C_AI_BRAIN_COMPONENT.new()
	autofree(brain)
	brain.active_goal_id = &"investigate"
	brain.evaluation_timer = 1.25

	var movement := C_MOVEMENT_COMPONENT.new()
	autofree(movement)
	movement.set_horizontal_dynamics_velocity(Vector2(3.0, 4.0))

	var detection := C_DETECTION_COMPONENT.new()
	autofree(detection)
	detection.is_player_in_range = true
	detection.last_detected_player_entity_id = &"player"

	var needs := C_NEEDS_COMPONENT.new()
	autofree(needs)
	needs.hunger = 0.35

	var health := C_HEALTH_COMPONENT.new()
	autofree(health)
	health.current_health = 72.0
	health.max_health = 100.0

	var components: Dictionary = {
		C_AI_BRAIN_COMPONENT.COMPONENT_TYPE: brain,
		C_MOVEMENT_COMPONENT.COMPONENT_TYPE: movement,
		C_DETECTION_COMPONENT.COMPONENT_TYPE: detection,
		C_NEEDS_COMPONENT.COMPONENT_TYPE: needs,
		C_HEALTH_COMPONENT.COMPONENT_TYPE: health,
	}
	var query := EntityQueryStub.new(entity, components)
	var world_state: Dictionary = _build_world_state(builder, query)

	assert_eq(world_state.get(&"active_goal_id"), &"investigate")
	assert_almost_eq(float(world_state.get(&"evaluation_timer", -1.0)), 1.25, 0.0001)
	assert_almost_eq(float(world_state.get(&"movement_speed", -1.0)), 5.0, 0.0001)
	assert_eq(world_state.get(&"is_player_in_range"), true)
	assert_eq(world_state.get(&"last_detected_player_entity_id"), &"player")
	assert_almost_eq(float(world_state.get(&"hunger", -1.0)), 0.35, 0.0001)
	assert_almost_eq(float(world_state.get(&"current_health", -1.0)), 72.0, 0.0001)
	assert_almost_eq(float(world_state.get(&"max_health", -1.0)), 100.0, 0.0001)

	for key_variant in world_state.keys():
		assert_true(key_variant is StringName, "World-state keys must be StringName values")
	for value_variant in world_state.values():
		assert_false(value_variant is Dictionary, "World state must be flat (no nested dictionaries)")

func test_build_omits_keys_for_missing_components_instead_of_returning_null_values() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return

	var entity: Node3D = _new_entity()
	var brain := C_AI_BRAIN_COMPONENT.new()
	autofree(brain)
	var components: Dictionary = {
		C_AI_BRAIN_COMPONENT.COMPONENT_TYPE: brain,
	}
	var query := EntityQueryStub.new(entity, components)
	var world_state: Dictionary = _build_world_state(builder, query)

	assert_false(world_state.has(&"movement_speed"))
	assert_false(world_state.has(&"is_player_in_range"))
	assert_false(world_state.has(&"last_detected_player_entity_id"))
	assert_false(world_state.has(&"hunger"))
	assert_false(world_state.has(&"current_health"))
	assert_false(world_state.has(&"max_health"))

func test_build_returns_immutable_snapshots_across_calls() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return

	var entity: Node3D = _new_entity()
	var brain := C_AI_BRAIN_COMPONENT.new()
	autofree(brain)
	brain.active_goal_id = &"wander"
	var needs := C_NEEDS_COMPONENT.new()
	autofree(needs)
	needs.hunger = 0.5
	var components: Dictionary = {
		C_AI_BRAIN_COMPONENT.COMPONENT_TYPE: brain,
		C_NEEDS_COMPONENT.COMPONENT_TYPE: needs,
	}
	var query := EntityQueryStub.new(entity, components)

	var first_state: Dictionary = _build_world_state(builder, query)
	first_state[&"hunger"] = 0.99
	first_state[&"active_goal_id"] = &"tampered"

	var second_state: Dictionary = _build_world_state(builder, query)
	assert_almost_eq(float(second_state.get(&"hunger", -1.0)), 0.5, 0.0001)
	assert_eq(second_state.get(&"active_goal_id"), &"wander")
