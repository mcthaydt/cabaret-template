extends GutTest

## Tests for U_GameplayActions action creators

func before_each() -> void:
	# Actions auto-register via _static_init()
	pass

func test_pause_game_returns_correct_structure() -> void:
	var action: Dictionary = U_GameplayActions.pause_game()
	
	assert_true(action.has("type"), "Action should have type")
	assert_true(action.has("payload"), "Action should have payload")
	assert_eq(action.get("type"), U_GameplayActions.ACTION_PAUSE_GAME, "Type should be ACTION_PAUSE_GAME")

func test_unpause_game_returns_correct_structure() -> void:
	var action: Dictionary = U_GameplayActions.unpause_game()
	
	assert_true(action.has("type"), "Action should have type")
	assert_true(action.has("payload"), "Action should have payload")
	assert_eq(action.get("type"), U_GameplayActions.ACTION_UNPAUSE_GAME, "Type should be ACTION_UNPAUSE_GAME")

func test_action_type_is_string_name() -> void:
	var action: Dictionary = U_GameplayActions.pause_game()
	var action_type: Variant = action.get("type")
	
	assert_true(action_type is StringName, "Action type should be StringName")

func test_action_creators_return_typed_dictionary() -> void:
	var pause_action: Dictionary = U_GameplayActions.pause_game()
	var unpause_action: Dictionary = U_GameplayActions.unpause_game()
	
	assert_true(pause_action is Dictionary, "pause_game should return Dictionary")
	assert_true(unpause_action is Dictionary, "unpause_game should return Dictionary")

func test_actions_are_registered_automatically() -> void:
	# _static_init() should have registered these
	assert_true(U_ActionRegistry.is_registered(U_GameplayActions.ACTION_PAUSE_GAME), 
		"PAUSE_GAME should be auto-registered")
	assert_true(U_ActionRegistry.is_registered(U_GameplayActions.ACTION_UNPAUSE_GAME), 
		"UNPAUSE_GAME should be auto-registered")

func test_created_actions_validate_successfully() -> void:
	var pause_action: Dictionary = U_GameplayActions.pause_game()
	var unpause_action: Dictionary = U_GameplayActions.unpause_game()
	
	assert_true(U_ActionRegistry.validate_action(pause_action), "pause_game action should validate")
	assert_true(U_ActionRegistry.validate_action(unpause_action), "unpause_game action should validate")

func test_action_constants_are_string_names() -> void:
	assert_true(U_GameplayActions.ACTION_PAUSE_GAME is StringName, "ACTION_PAUSE_GAME should be StringName")
	assert_true(U_GameplayActions.ACTION_UNPAUSE_GAME is StringName, "ACTION_UNPAUSE_GAME should be StringName")

## Phase 16.5: Mock action creator tests removed
## Tests for entity actions are in test_entity_coordination.gd
