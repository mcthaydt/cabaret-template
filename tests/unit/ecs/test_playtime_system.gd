extends BaseTest

const S_PLAYTIME_SYSTEM := preload("res://scripts/ecs/systems/s_playtime_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")

var _system: BaseECSSystem
var _mock_store

func before_each() -> void:
	_mock_store = MOCK_STATE_STORE.new()
	add_child(_mock_store)
	autofree(_mock_store)

	_system = S_PLAYTIME_SYSTEM.new()
	_system.state_store = _mock_store
	add_child(_system)
	autofree(_system)

	# Set up initial state with gameplay shell
	_mock_store.set_slice("navigation", {
		"shell": "gameplay"
	})
	_mock_store.set_slice("gameplay", {
		"paused": false,
		"playtime_seconds": 0
	})
	_mock_store.set_slice("scene", {
		"is_transitioning": false
	})

	await get_tree().process_frame

	# Manually configure the system (on_configured is called by BaseECSSystem on _ready)
	_system.on_configured()

func test_playtime_increments_when_in_gameplay_and_not_paused() -> void:
	# Simulate 1.5 seconds of gameplay
	_system.process_tick(1.5)

	# Should dispatch increment_playtime with 1 second
	var actions: Array = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 1, "Should dispatch one action after 1 second accumulates")
	assert_eq(actions[0]["type"], U_GAMEPLAY_ACTIONS.ACTION_INCREMENT_PLAYTIME)
	assert_eq(actions[0]["payload"], 1, "Should increment by 1 second")

func test_playtime_carries_sub_second_remainder() -> void:
	# First tick: 0.7 seconds (no dispatch, accumulates)
	_system.process_tick(0.7)
	var actions: Array = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 0, "Should not dispatch when less than 1 second accumulated")

	# Second tick: 0.5 seconds (total 1.2 seconds, dispatch 1 second)
	_mock_store.clear_dispatched_actions()
	_system.process_tick(0.5)
	actions = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 1, "Should dispatch after accumulating 1+ seconds")
	assert_eq(actions[0]["payload"], 1, "Should dispatch 1 second")

	# Third tick: 0.9 seconds (with 0.2 remainder = 1.1 seconds, dispatch 1 second)
	_mock_store.clear_dispatched_actions()
	_system.process_tick(0.9)
	actions = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 1, "Should dispatch with carried remainder")
	assert_eq(actions[0]["payload"], 1, "Should dispatch 1 second")

func test_playtime_does_not_track_when_not_in_gameplay_shell() -> void:
	# Change shell to "menu"
	_mock_store.set_slice("navigation", {
		"shell": "menu"
	})

	_system.process_tick(2.0)

	var actions: Array = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 0, "Should not track playtime when not in gameplay shell")

func test_playtime_does_not_track_when_paused() -> void:
	# Set paused to true
	_mock_store.set_slice("navigation", {
		"shell": "gameplay",
		"overlay_stack": [StringName("pause_menu")]  # U_NavigationSelectors checks overlay_stack
	})

	_system.process_tick(2.0)

	var actions: Array = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 0, "Should not track playtime when paused")

func test_playtime_does_not_track_when_transitioning() -> void:
	# Set is_transitioning to true
	_mock_store.set_slice("scene", {
		"is_transitioning": true
	})

	_system.process_tick(2.0)

	var actions: Array = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 0, "Should not track playtime during scene transitions")

func test_playtime_dispatches_multiple_seconds() -> void:
	# Simulate 3.2 seconds in one tick
	_system.process_tick(3.2)

	var actions: Array = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 1, "Should dispatch one action")
	assert_eq(actions[0]["payload"], 3, "Should dispatch 3 whole seconds")

	# Next tick with 0.9 seconds (0.2 remainder + 0.9 = 1.1)
	_mock_store.clear_dispatched_actions()
	_system.process_tick(0.9)
	actions = _mock_store.get_dispatched_actions()
	assert_eq(actions.size(), 1, "Should dispatch with remainder")
	assert_eq(actions[0]["payload"], 1, "Should dispatch 1 second from remainder")

func test_system_has_low_priority() -> void:
	# Playtime tracking should be low priority (high number)
	assert_eq(_system.execution_priority, 200, "Playtime system should have low priority (200)")
