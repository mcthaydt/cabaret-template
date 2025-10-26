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
	assert_true(ActionRegistry.is_registered(U_GameplayActions.ACTION_PAUSE_GAME), 
		"PAUSE_GAME should be auto-registered")
	assert_true(ActionRegistry.is_registered(U_GameplayActions.ACTION_UNPAUSE_GAME), 
		"UNPAUSE_GAME should be auto-registered")

func test_created_actions_validate_successfully() -> void:
	var pause_action: Dictionary = U_GameplayActions.pause_game()
	var unpause_action: Dictionary = U_GameplayActions.unpause_game()
	
	assert_true(ActionRegistry.validate_action(pause_action), "pause_game action should validate")
	assert_true(ActionRegistry.validate_action(unpause_action), "unpause_game action should validate")

func test_action_constants_are_string_names() -> void:
	assert_true(U_GameplayActions.ACTION_PAUSE_GAME is StringName, "ACTION_PAUSE_GAME should be StringName")
	assert_true(U_GameplayActions.ACTION_UNPAUSE_GAME is StringName, "ACTION_UNPAUSE_GAME should be StringName")

## Phase 1d: New action creator tests

func test_update_health_action_creator() -> void:
	var action: Dictionary = U_GameplayActions.update_health(50)
	
	assert_true(action.has("type"), "Action should have type")
	assert_true(action.has("payload"), "Action should have payload")
	assert_eq(action.get("type"), U_GameplayActions.ACTION_UPDATE_HEALTH, "Type should be ACTION_UPDATE_HEALTH")
	assert_eq(action.get("payload").get("health"), 50, "Payload should contain health value")

func test_update_score_action_creator() -> void:
	var action: Dictionary = U_GameplayActions.update_score(1000)
	
	assert_true(action.has("type"), "Action should have type")
	assert_true(action.has("payload"), "Action should have payload")
	assert_eq(action.get("type"), U_GameplayActions.ACTION_UPDATE_SCORE, "Type should be ACTION_UPDATE_SCORE")
	assert_eq(action.get("payload").get("score"), 1000, "Payload should contain score value")

func test_set_level_action_creator() -> void:
	var action: Dictionary = U_GameplayActions.set_level(3)
	
	assert_true(action.has("type"), "Action should have type")
	assert_true(action.has("payload"), "Action should have payload")
	assert_eq(action.get("type"), U_GameplayActions.ACTION_SET_LEVEL, "Type should be ACTION_SET_LEVEL")
	assert_eq(action.get("payload").get("level"), 3, "Payload should contain level value")

func test_all_action_creators_return_typed_dictionary() -> void:
	var update_health_action: Dictionary = U_GameplayActions.update_health(75)
	var update_score_action: Dictionary = U_GameplayActions.update_score(500)
	var set_level_action: Dictionary = U_GameplayActions.set_level(2)
	
	assert_true(update_health_action is Dictionary, "update_health should return Dictionary")
	assert_true(update_score_action is Dictionary, "update_score should return Dictionary")
	assert_true(set_level_action is Dictionary, "set_level should return Dictionary")
