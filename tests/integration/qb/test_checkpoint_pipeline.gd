extends BaseTest

const ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const STATE_STORE := preload("res://scripts/core/state/m_state_store.gd")
const STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const GAME_EVENT_SYSTEM := preload("res://scripts/core/ecs/systems/s_game_event_system.gd")
const CHECKPOINT_HANDLER_SYSTEM := preload("res://scripts/core/ecs/systems/s_checkpoint_handler_system.gd")
const CHECKPOINT_COMPONENT := preload("res://scripts/core/ecs/components/c_checkpoint_component.gd")
const PLAYER_TAG_COMPONENT := preload("res://scripts/core/ecs/components/c_player_tag_component.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	super.after_each()

func test_checkpoint_zone_enter_pipeline_updates_state_and_publishes_typed_event() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var store: M_StateStore = fixture["store"] as M_StateStore
	var root: Node3D = fixture["root"] as Node3D
	var player_body: CharacterBody3D = fixture["player_body"] as CharacterBody3D

	var spawn_point_id := StringName("sp_pipeline_checkpoint")
	var spawn_point := Node3D.new()
	spawn_point.name = String(spawn_point_id)
	root.add_child(spawn_point)
	autofree(spawn_point)
	await _pump()
	spawn_point.global_position = Vector3(6.0, 2.0, -3.0)

	var checkpoint := CHECKPOINT_COMPONENT.new()
	checkpoint.checkpoint_id = StringName("cp_pipeline")
	checkpoint.spawn_point_id = spawn_point_id
	var area := Area3D.new()
	area.name = "CheckpointArea"
	checkpoint.add_child(area)
	autofree(area)

	var checkpoint_entity := Node3D.new()
	checkpoint_entity.name = "E_Checkpoint"
	checkpoint_entity.add_child(checkpoint)
	root.add_child(checkpoint_entity)
	autofree(checkpoint)
	autofree(checkpoint_entity)
	await _pump_physics()

	area.body_entered.emit(player_body)
	await _pump_physics()

	var gameplay: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(
		gameplay.get("last_checkpoint", StringName()),
		spawn_point_id,
		"Checkpoint handler should write gameplay.last_checkpoint via forwarded request"
	)

	var history: Array = U_ECS_EVENT_BUS.get_event_history()
	var activation_requests: Array = _filter_events(history, U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATION_REQUESTED)
	assert_eq(activation_requests.size(), 1, "Game event system should publish checkpoint_activation_requested")
	if activation_requests.is_empty():
		return

	var request_payload: Dictionary = activation_requests[0].get("payload", {})
	assert_eq(request_payload.get("checkpoint", null), checkpoint)
	assert_eq(request_payload.get("spawn_point_id", StringName()), spawn_point_id)
	assert_eq(request_payload.get("body", null), player_body)

	var activated_events: Array = _filter_events(history, U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATED)
	assert_eq(activated_events.size(), 1, "Checkpoint handler should publish checkpoint_activated typed event")
	if activated_events.is_empty():
		return

	var activated_payload: Dictionary = activated_events[0].get("payload", {})
	assert_eq(activated_payload.get("checkpoint_id", StringName()), checkpoint.checkpoint_id)
	assert_eq(activated_payload.get("spawn_point_id", StringName()), spawn_point_id)
	assert_eq(activated_payload.get("position", Vector3.ZERO), spawn_point.global_position)

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

	var checkpoint_handler_system := CHECKPOINT_HANDLER_SYSTEM.new()
	checkpoint_handler_system.state_store = store
	checkpoint_handler_system.ecs_manager = manager
	manager.add_child(checkpoint_handler_system)
	autofree(checkpoint_handler_system)
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
