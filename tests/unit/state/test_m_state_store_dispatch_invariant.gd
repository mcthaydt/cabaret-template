extends GutTest

## Tests for M_StateStore dispatch invariants (F3).
##
## Verifies that:
## 1. _sync_navigation_initial_scene dispatches an action (not direct mutation).
## 2. Every dispatch produces paired action_dispatched + slice_updated signals.
## 3. _sync_navigation_initial_scene is recorded in action history.


var store: M_StateStore

func before_each() -> void:
	U_StateEventBus.reset()
	U_ServiceLocator.clear()

	store = M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.time_initial_state = RS_TimeInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()

func after_each() -> void:
	store = null
	U_StateEventBus.reset()
	U_ServiceLocator.clear()


func _register_test_action(action_type: StringName) -> void:
	if not U_ActionRegistry.is_registered(action_type):
		U_ActionRegistry.register_action(action_type)


func test_sync_initial_scene_dispatches_action() -> void:
	"""_sync_navigation_initial_scene must dispatch a navigation/sync_initial_scene
	action instead of directly mutating _state["navigation"].

	This test FAILS in the current codebase because _sync_navigation_initial_scene
	writes _state["navigation"] directly without going through dispatch().
	After Commit 2, it will dispatch U_NavigationActions.sync_initial_scene().
	"""
	# Set up localization slice with has_selected_language = false
	# so the sync will target "language_selector"
	var localization_state := RS_LocalizationInitialState.new()
	store.localization_initial_state = localization_state

	# Set up navigation slice with default main_menu shell
	store.navigation_initial_state = RS_NavigationInitialState.new()

	# Register the action we expect to be dispatched
	_register_test_action(U_NavigationActions.ACTION_SYNC_INITIAL_SCENE)

	# Track action_dispatched signals. Must connect BEFORE add_child
	# because _ready() runs synchronously and dispatches during initialization.
	var dispatched_actions: Array[Dictionary] = []
	var on_action_dispatched: Callable = func(action: Dictionary) -> void:
		dispatched_actions.append(action)
	store.action_dispatched.connect(on_action_dispatched)

	# Add the store to the scene tree, which triggers _ready() and
	# _sync_navigation_initial_scene()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	# Verify that ACTION_SYNC_INITIAL_SCENE was dispatched
	var found_sync_action: bool = false
	for action in dispatched_actions:
		if action.get("type") == U_NavigationActions.ACTION_SYNC_INITIAL_SCENE:
			found_sync_action = true
			# Verify payload: base_scene_id should be "language_selector"
			# (because has_selected_language defaults to false)
			assert_eq(
				action.get("base_scene_id"),
				StringName("language_selector"),
				"sync_initial_scene action should target language_selector when no language selected"
			)
			# clear_overlays should be true when has_selected_language is false
			assert_eq(
				action.get("clear_overlays"),
				true,
				"sync_initial_scene action should clear overlays when no language selected"
			)
			break

	assert_true(found_sync_action,
		"_sync_navigation_initial_scene should dispatch ACTION_SYNC_INITIAL_SCENE")


func test_dispatch_produces_paired_action_and_slice_signals() -> void:
	"""Every dispatch should produce both action_dispatched and slice_updated
	signals. action_dispatched is emitted synchronously during dispatch();
	slice_updated is batched and flushed on the next physics frame.

	This test establishes the pairing invariant for regression testing.
	It should PASS even before Commit 2 because it tests the normal
	dispatch path (not the _sync_navigation_initial_scene bypass).

	Uses an immediate action to get synchronous slice_updated emission,
	which avoids the need for physics-frame flushing in the test.
	"""
	_register_test_action(&"navigation/set_shell")

	# Create store with standard setup
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.localization_initial_state = RS_LocalizationInitialState.new()

	add_child(store)
	autofree(store)
	await get_tree().process_frame

	var action_received: Array[bool] = [false]
	var slice_received: Array[bool] = [false]
	var action_order: Array[int] = [0]
	var slice_order: Array[int] = [0]
	var order_counter: Array[int] = [0]

	var on_action_dispatched: Callable = func(_action: Dictionary) -> void:
		action_received[0] = true
		order_counter[0] += 1
		action_order[0] = order_counter[0]

	var on_slice_updated: Callable = func(slice_name: StringName, _slice_state: Dictionary) -> void:
		if slice_name == StringName("navigation"):
			slice_received[0] = true
			order_counter[0] += 1
			slice_order[0] = order_counter[0]

	store.action_dispatched.connect(on_action_dispatched)
	store.slice_updated.connect(on_slice_updated)

	# Dispatch an immediate set_shell action to force synchronous slice_updated emission.
	# Regular (non-immediate) actions batch slice_updated for the next physics frame,
	# which is hard to await in unit tests. Immediate actions emit slice_updated right
	# after the dispatch, making the pairing testable in a single frame.
	var action: Dictionary = U_NavigationActions.set_shell(
		StringName("gameplay"),
		StringName("alleyway")
	)
	action["immediate"] = true
	store.dispatch(action)

	assert_true(action_received[0],
		"action_dispatched should be emitted for set_shell dispatch")
	assert_true(slice_received[0],
		"slice_updated should be emitted for navigation slice after set_shell")
	# action_dispatched is emitted synchronously during dispatch(),
	# slice_updated is flushed immediately for immediate actions.
	assert_lt(action_order[0], slice_order[0],
		"action_dispatched should fire before slice_updated (synchronous vs batched)")


func test_sync_initial_scene_recorded_in_action_history() -> void:
	"""_sync_navigation_initial_scene should be recorded in action history
	because it goes through dispatch().

	This test FAILS in the current codebase because _sync_navigation_initial_scene
	directly mutates _state without going through dispatch(), so no history
	entry is created. After Commit 2, the dispatch will be recorded.
	"""
	# Enable action history
	store.settings.enable_history = true
	store.settings.max_history_size = 50

	# Set up localization so sync will target "language_selector"
	var localization_state := RS_LocalizationInitialState.new()
	store.localization_initial_state = localization_state
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()

	# Register the action we expect to be recorded
	_register_test_action(U_NavigationActions.ACTION_SYNC_INITIAL_SCENE)

	add_child(store)
	autofree(store)
	await get_tree().process_frame

	# Check action history for the sync_initial_scene action
	var history: Array = store.get_action_history()
	var found_sync_in_history: bool = false
	for entry in history:
		var action: Dictionary = entry.get("action", {})
		if action.get("type") == U_NavigationActions.ACTION_SYNC_INITIAL_SCENE:
			found_sync_in_history = true
			break

	assert_true(found_sync_in_history,
		"_sync_navigation_initial_scene should be recorded in action history via dispatch()")