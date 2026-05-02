extends BaseTest

const ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const STATE_STORE := preload("res://scripts/core/state/m_state_store.gd")
const STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const GAME_EVENT_SYSTEM := preload("res://scripts/core/ecs/systems/s_game_event_system.gd")
const VICTORY_HANDLER_SYSTEM := preload("res://scripts/core/ecs/systems/s_victory_handler_system.gd")
const VICTORY_TRIGGER_COMPONENT := preload("res://scripts/core/ecs/components/c_victory_trigger_component.gd")
const PLAYER_TAG_COMPONENT := preload("res://scripts/core/ecs/components/c_player_tag_component.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	super.after_each()

func test_victory_zone_enter_pipeline_updates_state_and_publishes_execution_event() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var store: M_StateStore = fixture["store"] as M_StateStore
	var root: Node3D = fixture["root"] as Node3D
	var player_body: CharacterBody3D = fixture["player_body"] as CharacterBody3D

	var trigger := VICTORY_TRIGGER_COMPONENT.new()
	trigger.objective_id = StringName("obj_pipeline")
	trigger.area_id = "exterior"
	trigger.victory_type = C_VictoryTriggerComponent.VictoryType.LEVEL_COMPLETE

	var area := Area3D.new()
	area.name = "VictoryArea"
	trigger.add_child(area)
	autofree(area)

	var trigger_entity := Node3D.new()
	trigger_entity.name = "E_VictoryTrigger"
	trigger_entity.add_child(trigger)
	root.add_child(trigger_entity)
	autofree(trigger)
	autofree(trigger_entity)
	await _pump_physics()

	area.body_entered.emit(player_body)
	await _pump_physics()

	var gameplay: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(
		gameplay.get("last_victory_objective", StringName()),
		trigger.objective_id,
		"Victory handler should write gameplay.last_victory_objective"
	)
	var completed_variant: Variant = gameplay.get("completed_areas", [])
	assert_true(completed_variant is Array)
	var completed_areas: Array = completed_variant as Array
	assert_true(
		completed_areas.has(trigger.area_id),
		"Victory handler should append trigger area to gameplay.completed_areas"
	)
	assert_true(trigger.is_triggered, "Victory trigger should be marked triggered by handler")

	var history: Array = U_ECS_EVENT_BUS.get_event_history()
	var execution_requests: Array = _filter_events(history, U_ECS_EVENT_NAMES.EVENT_VICTORY_EXECUTION_REQUESTED)
	assert_eq(execution_requests.size(), 1, "Game event system should publish victory_execution_requested")
	if execution_requests.is_empty():
		return

	var request_payload: Dictionary = execution_requests[0].get("payload", {})
	assert_eq(request_payload.get("trigger_node", null), trigger)
	assert_eq(request_payload.get("body", null), player_body)

	var executed_events: Array = _filter_events(history, U_ECS_EVENT_NAMES.EVENT_VICTORY_EXECUTED)
	assert_eq(executed_events.size(), 1, "Victory handler should publish victory_executed")
	if executed_events.is_empty():
		return

	var executed_payload: Dictionary = executed_events[0].get("payload", {})
	assert_eq(executed_payload.get("trigger_node", null), trigger)
	assert_eq(executed_payload.get("body", null), player_body)

func _setup_fixture() -> Dictionary:
	var root := Node3D.new()
	root.name = "IntegrationRoot"
	add_child(root)
	autofree(root)
	await _pump()

	var store := STATE_STORE.new()
	store.settings = STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = GAMEPLAY_INITIAL_STATE.new()
	root.add_child(store)
	autofree(store)
	await _pump_physics()

	var manager := ECS_MANAGER.new()
	root.add_child(manager)
	autofree(manager)
	await _pump_physics()

	var game_event_system := GAME_EVENT_SYSTEM.new()
	game_event_system.state_store = store
	game_event_system.ecs_manager = manager
	manager.add_child(game_event_system)
	autofree(game_event_system)

	var victory_handler_system := VICTORY_HANDLER_SYSTEM.new()
	victory_handler_system.state_store = store
	victory_handler_system.ecs_manager = manager
	manager.add_child(victory_handler_system)
	autofree(victory_handler_system)
	await _pump_physics()

	var player_entity := Node3D.new()
	player_entity.name = "E_Player"
	root.add_child(player_entity)
	autofree(player_entity)

	var player_body := CharacterBody3D.new()
	player_body.name = "Body"
	player_entity.add_child(player_body)
	autofree(player_body)

	var player_tag := PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)
	autofree(player_tag)
	await _pump_physics()

	return {
		"root": root,
		"store": store,
		"manager": manager,
		"player_body": player_body,
	}

func _filter_events(history: Array, event_name: StringName) -> Array:
	return history.filter(func(entry: Dictionary) -> bool:
		return entry.get("name", StringName()) == event_name
	)

func _pump() -> void:
	await get_tree().process_frame

func _pump_physics() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
