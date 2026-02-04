extends BaseTest

const M_AUTOSAVE_SCHEDULER := preload("res://scripts/managers/helpers/u_autosave_scheduler.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_SAVE_MANAGER := preload("res://tests/mocks/mock_save_manager.gd")

var _scheduler: Node
var _mock_store: MockStateStore
var _mock_save_manager

# Priority constants (duplicated from scheduler for testing)
enum Priority {
	NORMAL = 0,
	HIGH = 1,
	CRITICAL = 2
}

func before_each() -> void:
	# Reset ECS event bus to prevent subscription leaks
	U_ECSEventBus.reset()

	# Clear ServiceLocator to prevent warnings
	U_ServiceLocator.clear()

	# Create mock state store
	_mock_store = MOCK_STATE_STORE.new()
	add_child(_mock_store)
	autofree(_mock_store)

	# Create mock save manager
	_mock_save_manager = MOCK_SAVE_MANAGER.new()
	add_child(_mock_save_manager)
	autofree(_mock_save_manager)

	# Register mocks with ServiceLocator
	U_ServiceLocator.register(StringName("state_store"), _mock_store)
	U_ServiceLocator.register(StringName("save_manager"), _mock_save_manager)

	await get_tree().process_frame

func after_each() -> void:
	pass

## Phase 6: Autosave Scheduler Tests

func test_scheduler_extends_node() -> void:
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	assert_true(_scheduler is Node, "Scheduler should extend Node")
	autofree(_scheduler)

func test_scheduler_discovers_dependencies() -> void:
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	await get_tree().process_frame

	# Scheduler should have discovered state store and save manager
	assert_true(_scheduler.has_method("_get_state_store"), "Scheduler should have _get_state_store method")
	assert_true(_scheduler.has_method("_get_save_manager"), "Scheduler should have _get_save_manager method")

func test_checkpoint_event_triggers_autosave_request() -> void:
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	# Set up state to allow autosave
	_mock_store.set_slice(StringName("navigation"), {"shell": "gameplay"})
	_mock_store.set_slice(StringName("gameplay"), {"death_in_progress": false})
	_mock_store.set_slice(StringName("scene"), {"is_transitioning": false})

	await get_tree().process_frame

	# Emit checkpoint event
	U_ECSEventBus.publish(StringName("checkpoint_activated"), {"checkpoint_id": "test_checkpoint"})

	await get_tree().process_frame

	# Verify autosave was requested
	assert_gt(_mock_save_manager.autosave_request_count, 0, "Checkpoint should trigger autosave request")

func test_area_complete_action_does_not_trigger_autosave() -> void:
	# Area complete alone should NOT trigger autosave - we wait for scene transition instead
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	# Set up state to allow autosave
	_mock_store.set_slice(StringName("navigation"), {"shell": "gameplay"})
	_mock_store.set_slice(StringName("gameplay"), {"death_in_progress": false})
	_mock_store.set_slice(StringName("scene"), {"is_transitioning": false})

	await get_tree().process_frame

	# Dispatch area complete action
	_mock_store.dispatch({
		"type": StringName("gameplay/mark_area_complete"),
		"payload": "test_area"
	})

	await get_tree().process_frame

	# Verify autosave was NOT requested
	assert_eq(_mock_save_manager.autosave_request_count, 0, "Area complete action should NOT trigger autosave - we wait for scene transition instead")

func test_scene_transition_completed_triggers_autosave_request() -> void:
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	# Set up state to allow autosave
	_mock_store.set_slice(StringName("navigation"), {"shell": "gameplay"})
	_mock_store.set_slice(StringName("gameplay"), {"death_in_progress": false})
	_mock_store.set_slice(StringName("scene"), {"is_transitioning": false})

	await get_tree().process_frame

	# Dispatch scene transition completed action
	_mock_store.dispatch({
		"type": StringName("scene/transition_completed"),
		"payload": {"scene_id": StringName("gameplay_base")}
	})

	await get_tree().process_frame

	# Verify autosave was requested
	assert_gt(_mock_save_manager.autosave_request_count, 0, "Scene transition completed should trigger autosave request")

func test_endgame_transition_completed_does_not_trigger_autosave() -> void:
	# Endgame transitions (e.g., game_over) should NOT overwrite autosaves,
	# otherwise Main Menu "Continue" can load back into game_over.
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	# Set up state to allow autosave (gameplay shell, not dead, not transitioning)
	_mock_store.set_slice(StringName("navigation"), {"shell": "gameplay"})
	_mock_store.set_slice(StringName("gameplay"), {"death_in_progress": false})
	_mock_store.set_slice(StringName("scene"), {"is_transitioning": false})

	await get_tree().process_frame

	_mock_store.dispatch({
		"type": StringName("scene/transition_completed"),
		"payload": {"scene_id": StringName("game_over")}
	})

	await get_tree().process_frame

	assert_eq(_mock_save_manager.autosave_request_count, 0,
		"Transitioning to game_over should not trigger autosave")

func test_autosave_blocked_when_death_in_progress() -> void:
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	# Set death_in_progress to true
	_mock_store.set_slice(StringName("gameplay"), {"death_in_progress": true})
	_mock_store.set_slice(StringName("scene"), {"is_transitioning": false})

	await get_tree().process_frame

	# Emit checkpoint event
	U_ECSEventBus.publish(StringName("checkpoint_activated"), {"checkpoint_id": "test_checkpoint"})

	await get_tree().process_frame

	# Verify autosave was NOT requested
	assert_eq(_mock_save_manager.autosave_request_count, 0, "Autosave should be blocked when death_in_progress is true")

func test_autosave_blocked_when_scene_transitioning() -> void:
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	# Set scene transitioning to true
	_mock_store.set_slice(StringName("gameplay"), {"death_in_progress": false})
	_mock_store.set_slice(StringName("scene"), {"is_transitioning": true})

	await get_tree().process_frame

	# Emit checkpoint event
	U_ECSEventBus.publish(StringName("checkpoint_activated"), {"checkpoint_id": "test_checkpoint"})

	await get_tree().process_frame

	# Verify autosave was NOT requested
	assert_eq(_mock_save_manager.autosave_request_count, 0, "Autosave should be blocked when scene is transitioning")

func test_coalescing_multiple_requests_into_one_write() -> void:
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	# Set up state to allow autosave (not in gameplay shell for transition test)
	_mock_store.set_slice(StringName("navigation"), {"shell": "main_menu"})
	_mock_store.set_slice(StringName("gameplay"), {"death_in_progress": false})
	_mock_store.set_slice(StringName("scene"), {"is_transitioning": false})

	await get_tree().process_frame

	# Emit multiple events rapidly (within same frame)
	# Two transition_completed events to gameplay scenes
	_mock_store.dispatch({
		"type": StringName("scene/transition_completed"),
		"payload": {"scene_id": StringName("alleyway")}
	})
	_mock_store.dispatch({
		"type": StringName("scene/transition_completed"),
		"payload": {"scene_id": StringName("interior_house")}
	})

	await get_tree().process_frame

	# Verify only one autosave was requested (coalesced)
	assert_eq(_mock_save_manager.autosave_request_count, 1, "Multiple events in same frame should coalesce into one autosave")

func test_autosave_blocked_when_not_in_gameplay_shell() -> void:
	# Autosaves should only happen during gameplay, not in menus
	_scheduler = M_AUTOSAVE_SCHEDULER.new()
	add_child(_scheduler)
	autofree(_scheduler)

	# Set up state in main menu (not gameplay)
	_mock_store.set_slice(StringName("navigation"), {"shell": "main_menu"})
	_mock_store.set_slice(StringName("gameplay"), {"death_in_progress": false})
	_mock_store.set_slice(StringName("scene"), {"is_transitioning": false})

	await get_tree().process_frame

	# Try to trigger autosave with checkpoint
	U_ECSEventBus.publish(StringName("checkpoint_activated"), {"checkpoint_id": "test_checkpoint"})

	await get_tree().process_frame

	# Verify autosave was NOT requested (blocked by shell check)
	assert_eq(_mock_save_manager.autosave_request_count, 0, "Autosave should be blocked when not in gameplay shell")
