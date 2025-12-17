extends BaseTest

const BASE_SCENE := preload("res://templates/tmpl_base_scene.tscn")
const MOVEMENT_TYPE := StringName("C_MovementComponent")
const INPUT_TYPE := StringName("C_InputComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")

const MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const MOVEMENT_SETTINGS := preload("res://resources/settings/movement_default.tres")
const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")

var _state_store: M_StateStore = null

func before_each() -> void:
	# Clear ServiceLocator first to ensure clean state between tests
	U_ServiceLocator.clear()

	# Create and add M_StateStore for systems that require it
	_state_store = M_StateStore.new()
	add_child(_state_store)
	autofree(_state_store)
	U_ServiceLocator.register(StringName("state_store"), _state_store)
	await get_tree().process_frame

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

func _setup_scene() -> Dictionary:
	await get_tree().process_frame
	var scene := BASE_SCENE.instantiate()
	add_child(scene)
	autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: M_ECSManager = scene.get_node("Managers/M_ECSManager") as M_ECSManager
	var player_root: Node = get_player_root(scene)
	assert_not_null(player_root, "Base scene should expose the E_Player entity")

	var components_root: Node = player_root.get_node("Components")

	var player_components := {}
	for child in components_root.get_children():
		player_components[child.get_component_type()] = child

	return {
		"scene": scene,
		"manager": manager,
		"player_components": player_components,
	}

func test_query_entities_returns_player_components() -> void:
	var context := await _setup_scene()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"]
	var player_components: Dictionary = context["player_components"]

	var results: Array = manager.query_entities([
		MOVEMENT_TYPE,
		INPUT_TYPE,
	], [FLOATING_TYPE])

	assert_eq(results.size(), 1, "Expected exactly one player entity to match movement+input query")
	var query: U_EntityQuery = results[0]
	assert_not_null(query.get_component(MOVEMENT_TYPE))
	assert_not_null(query.get_component(INPUT_TYPE))

	var movement_component: C_MovementComponent = query.get_component(MOVEMENT_TYPE)
	var input_component: C_InputComponent = query.get_component(INPUT_TYPE)
	assert_eq(movement_component, player_components[MOVEMENT_TYPE])
	assert_eq(input_component, player_components[INPUT_TYPE])

	if query.has_component(FLOATING_TYPE):
		var floating_component := query.get_component(FLOATING_TYPE)
		assert_eq(floating_component, player_components[FLOATING_TYPE])

func test_query_entities_includes_runtime_entities() -> void:
	var context := await _setup_scene()
	autofree_context(context)
	var scene: Node = context["scene"]
	var manager: M_ECSManager = context["manager"]

	var entities_root := scene.get_node("Entities")
	var runtime_entity := Node3D.new()
	runtime_entity.name = "E_RuntimeEntity"
	entities_root.add_child(runtime_entity)
	autofree(runtime_entity)
	await get_tree().process_frame

	var components := Node.new()
	components.name = "Components"
	runtime_entity.add_child(components)
	autofree(components)

	var movement_component: C_MovementComponent = MOVEMENT_COMPONENT.new()
	movement_component.settings = MOVEMENT_SETTINGS.duplicate(true)
	components.add_child(movement_component)
	autofree(movement_component)

	var input_component: C_InputComponent = INPUT_COMPONENT.new()
	components.add_child(input_component)
	autofree(input_component)

	await get_tree().process_frame
	await get_tree().process_frame

	var results: Array = manager.query_entities([
		MOVEMENT_TYPE,
		INPUT_TYPE,
	])

	assert_eq(results.size(), 2, "Query should now return both the template player and runtime entity")

	var runtime_found := false
	for query in results:
		var eq: U_EntityQuery = query
		if eq.entity == runtime_entity:
			runtime_found = true
			assert_eq(eq.get_component(MOVEMENT_TYPE), movement_component)
			assert_eq(eq.get_component(INPUT_TYPE), input_component)
	assert_true(runtime_found, "Runtime entity should be present in query results")

func test_query_entities_updates_when_component_removed() -> void:
	var context := await _setup_scene()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"]
	var player_components: Dictionary = context["player_components"]

	var initial := manager.query_entities([
		MOVEMENT_TYPE,
		INPUT_TYPE,
	])
	assert_eq(initial.size(), 1)

	var input_component: C_InputComponent = player_components[INPUT_TYPE]
	manager.unregister_component(input_component)
	input_component.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var results := manager.query_entities([
		MOVEMENT_TYPE,
		INPUT_TYPE,
	])
	assert_true(results.is_empty(), "Removing input component should remove entity from movement+input query")

	var movement_only := manager.query_entities([MOVEMENT_TYPE])
	assert_eq(movement_only.size(), 1, "Entity should still be returned when only querying for movement")

func test_player_scene_stays_stable_over_multiple_frames() -> void:
	var context := await _setup_scene()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"]

	manager.set_physics_process(false)
	var frames := 300
	for _i in range(frames):
		manager._physics_process(1.0 / 60.0)

	var queries := manager.query_entities([
		MOVEMENT_TYPE,
		INPUT_TYPE,
	], [FLOATING_TYPE])
	assert_eq(queries.size(), 1, "Player entity should remain discoverable after extended simulation")

	var systems := manager.get_systems()
	assert_true(systems.size() >= 8, "All core systems should remain registered after extended simulation")
