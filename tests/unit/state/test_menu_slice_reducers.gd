extends GutTest

## Tests for MenuReducer pure functions

const StateStoreEventBus := preload("res://scripts/state/state_event_bus.gd")
const StateHandoff := preload("res://scripts/state/u_state_handoff.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const U_MenuActions := preload("res://scripts/state/u_menu_actions.gd")
const MenuReducer := preload("res://scripts/state/reducers/u_menu_reducer.gd")

func before_each() -> void:
	StateStoreEventBus.reset()
	StateHandoff.clear_all()

func after_each() -> void:
	StateStoreEventBus.reset()
	StateHandoff.clear_all()

## T357: Test menu slice initializes with defaults
func test_menu_slice_initializes_with_defaults() -> void:
	var initial_state := RS_MenuInitialState.new()
	var state_dict: Dictionary = initial_state.to_dictionary()
	
	assert_eq(state_dict.get("active_screen"), "main_menu", "Initial active screen should be main_menu")
	assert_true(state_dict.has("pending_character"), "Should have pending_character field")
	assert_true(state_dict.has("pending_difficulty"), "Should have pending_difficulty field")
	assert_true(state_dict.has("available_saves"), "Should have available_saves field")

## T358: Test navigate to screen updates active screen
func test_navigate_to_screen_updates_active_screen() -> void:
	var state: Dictionary = {"active_screen": "main_menu", "pending_character": "", "pending_difficulty": "", "available_saves": []}
	var action: Dictionary = U_MenuActions.navigate_to_screen("settings")
	
	var result: Dictionary = MenuReducer.reduce(state, action)
	
	assert_eq(result["active_screen"], "settings", "Active screen should update to settings")
	assert_eq(state["active_screen"], "main_menu", "Original state should remain unchanged")

## T359: Test select character stores pending config
func test_select_character_stores_pending_config() -> void:
	var state: Dictionary = {"active_screen": "character_select", "pending_character": "", "pending_difficulty": "", "available_saves": []}
	var action: Dictionary = U_MenuActions.select_character("warrior")
	
	var result: Dictionary = MenuReducer.reduce(state, action)
	
	assert_eq(result["pending_character"], "warrior", "Pending character should be stored")
	assert_eq(state["pending_character"], "", "Original state should remain unchanged")

## T360: Test select difficulty stores pending config
func test_select_difficulty_stores_pending_config() -> void:
	var state: Dictionary = {"active_screen": "difficulty_select", "pending_character": "", "pending_difficulty": "", "available_saves": []}
	var action: Dictionary = U_MenuActions.select_difficulty("hard")
	
	var result: Dictionary = MenuReducer.reduce(state, action)
	
	assert_eq(result["pending_difficulty"], "hard", "Pending difficulty should be stored")
	assert_eq(state["pending_difficulty"], "", "Original state should remain unchanged")

## T361: Test load save files populates save list
func test_load_save_files_populates_save_list() -> void:
	var state: Dictionary = {"active_screen": "load_game", "pending_character": "", "pending_difficulty": "", "available_saves": []}
	var save_files: Array = ["save1.json", "save2.json", "save3.json"]
	var action: Dictionary = U_MenuActions.load_save_files(save_files)
	
	var result: Dictionary = MenuReducer.reduce(state, action)
	
	assert_eq(result["available_saves"], save_files, "Available saves should be populated")
	assert_eq(state["available_saves"], [], "Original state should remain unchanged")

## Test reducer is pure function
func test_reducer_is_pure_function() -> void:
	var state: Dictionary = {"active_screen": "main_menu", "pending_character": "", "pending_difficulty": "", "available_saves": []}
	var action: Dictionary = U_MenuActions.navigate_to_screen("settings")
	
	var result1: Dictionary = MenuReducer.reduce(state, action)
	var result2: Dictionary = MenuReducer.reduce(state, action)
	
	assert_eq(result1, result2, "Same inputs should produce same outputs (pure function)")

## Test reducer does not mutate original state
func test_reducer_does_not_mutate_original_state() -> void:
	var original_state: Dictionary = {"active_screen": "main_menu", "pending_character": "", "pending_difficulty": "", "available_saves": []}
	var action: Dictionary = U_MenuActions.navigate_to_screen("settings")
	
	var _new_state: Dictionary = MenuReducer.reduce(original_state, action)
	
	assert_eq(original_state["active_screen"], "main_menu", "Original active_screen should remain unchanged")

## Test unknown action returns state unchanged
func test_unknown_action_returns_state_unchanged() -> void:
	var state: Dictionary = {"active_screen": "main_menu", "pending_character": "", "pending_difficulty": "", "available_saves": []}
	var unknown_action: Dictionary = {"type": StringName("unknown/action"), "payload": null}
	
	var result: Dictionary = MenuReducer.reduce(state, unknown_action)
	
	assert_eq(result, state, "Unknown action should return state unchanged")

## Test initial state loads from resource
func test_initial_state_loads_from_resource() -> void:
	var store := M_StateStore.new()
	
	# Create and assign initial state
	var initial_state := RS_MenuInitialState.new()
	initial_state.active_screen = "options"
	initial_state.pending_character = "mage"
	store.menu_initial_state = initial_state
	
	# Explicitly assign settings to prevent warning
	store.settings = RS_StateStoreSettings.new()
	
	add_child(store)
	autofree(store)  # Use autofree for proper cleanup
	await get_tree().process_frame
	
	# Check that menu slice initialized with resource values
	var menu_slice: Dictionary = store.get_slice(StringName("menu"))
	assert_eq(menu_slice.get("active_screen"), "options", "Active screen should match resource")
	assert_eq(menu_slice.get("pending_character"), "mage", "Pending character should match resource")
