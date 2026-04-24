extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const S_RESOURCE_REGROW_SYSTEM := preload("res://scripts/demo/ecs/systems/s_resource_regrow_system.gd")
const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/demo/ecs/components/c_resource_node_component.gd")
const RS_RESOURCE_NODE_SETTINGS := preload("res://scripts/demo/resources/ai/world/rs_resource_node_settings.gd")

func _pump() -> void:
	await get_tree().process_frame

func _setup_context() -> Dictionary:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(store)
	autofree(store)
	await _pump()

	var manager := ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_RegrowNode"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var settings := RS_RESOURCE_NODE_SETTINGS.new()
	settings.initial_amount = 4
	settings.regrow_seconds = 0.1

	var resource_node := C_RESOURCE_NODE_COMPONENT.new()
	resource_node.settings = settings
	entity.add_child(resource_node)
	autofree(resource_node)
	await _pump()

	var system := S_RESOURCE_REGROW_SYSTEM.new()
	manager.add_child(system)
	autofree(system)
	await _pump()

	return {
		"manager": manager,
		"resource_node": resource_node,
	}

func test_regrow_clears_stale_reservation_when_node_refills() -> void:
	var context := await _setup_context()
	var manager: M_ECSManager = context["manager"]
	var resource_node: C_ResourceNodeComponent = context["resource_node"]
	resource_node.current_amount = 0
	resource_node.regrow_timer = 0.0
	resource_node.reserved_by_entity_id = &"builder"

	manager._physics_process(0.2)

	assert_eq(resource_node.current_amount, resource_node.settings.initial_amount)
	assert_eq(resource_node.reserved_by_entity_id, StringName(""))
