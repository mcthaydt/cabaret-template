extends BaseTest

const BASE_SCENE := preload("res://scenes/templates/tmpl_base_scene.tscn")
const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")

var _state_store: M_StateStore = null

func before_each() -> void:
	# Clear ServiceLocator first to ensure clean state between tests
	U_ServiceLocator.clear()

	var existing := get_tree().root.find_child("HUDLayer", true, false)
	if existing == null:
		var hud_layer := CanvasLayer.new()
		hud_layer.name = "HUDLayer"
		add_child(hud_layer)
		autofree(hud_layer)

	# Create and add M_StateStore for systems that require it
	_state_store = M_StateStore.new()
	add_child(_state_store)
	autofree(_state_store)
	U_ServiceLocator.register(StringName("state_store"), _state_store)
	await get_tree().process_frame

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

func _setup_base_scene() -> Dictionary:
	await get_tree().process_frame
	var scene := BASE_SCENE.instantiate()
	add_child(scene)
	autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: M_ECSManager = scene.get_node("Managers/M_ECSManager") as M_ECSManager
	return {
		"scene": scene,
		"manager": manager,
	}

func _collect_systems_recursive(node: Node, systems: Array[BaseECSSystem]) -> void:
	for child in node.get_children():
		if child is BaseECSSystem:
			systems.append(child)
		# Recursively search children (for category groups)
		_collect_systems_recursive(child, systems)

func test_base_scene_systems_register_with_manager() -> void:
	var context := await _setup_base_scene()
	autofree_context(context)
	var scene: Node = context["scene"]
	var manager: M_ECSManager = context["manager"]

	assert_not_null(manager)

	var systems_root := scene.get_node("Systems")
	assert_not_null(systems_root)

	# Recursively find all systems (they may be nested in category groups)
	var all_systems: Array[BaseECSSystem] = []
	_collect_systems_recursive(systems_root, all_systems)

	assert_true(all_systems.size() > 0, "Should have at least one system")

	for system in all_systems:
		assert_eq(system.get_manager(), manager, "System %s must resolve M_ECSManager via U_ECSUtils" % system.name)

func test_base_scene_components_register_with_manager() -> void:
	var context := await _setup_base_scene()
	autofree_context(context)
	var scene: Node = context["scene"]
	var manager: M_ECSManager = context["manager"]

	var player_root: Node = get_player_root(scene)
	assert_not_null(player_root, "Base scene should expose the E_Player entity")

	var components_root: Node = player_root.get_node("Components")
	assert_not_null(components_root, "Player entity should expose a Components container")

	for child in components_root.get_children():
		assert_true(child is ECS_COMPONENT, "Component node %s should extend ECSComponent" % child.name)
		var component: BaseECSComponent = child
		var registered: Array = manager.get_components(component.get_component_type())
		assert_true(registered.has(component), "Manager should own component %s" % child.name)

func test_get_components_returns_non_null_entries() -> void:
	var context := await _setup_base_scene()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"]

	var tracked_types := [
		StringName("C_InputComponent"),
		StringName("C_MovementComponent"),
		StringName("C_JumpComponent"),
		StringName("C_FloatingComponent"),
		StringName("C_RotateToInputComponent"),
		StringName("C_AlignWithSurfaceComponent"),
		StringName("C_LandingIndicatorComponent"),
	]

	for type_name in tracked_types:
		var components := manager.get_components(type_name)
		assert_false(components.is_empty(), "Expected at least one component for %s" % String(type_name))
		for entry in components:
			assert_not_null(entry, "get_components should not include null entries for %s" % String(type_name))
			assert_true(entry is ECS_COMPONENT, "Entries for %s must be ECSComponents" % String(type_name))
