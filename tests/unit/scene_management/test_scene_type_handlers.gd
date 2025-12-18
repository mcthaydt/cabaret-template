extends GutTest

## Unit tests for scene type handlers (Phase 10B-3: T137a-T137b)
##
## Tests verify that each handler correctly implements the I_SCENE_TYPE_HANDLER interface
## with appropriate scene-type-specific behavior.

const U_SCENE_REGISTRY = preload("res://scripts/scene_management/u_scene_registry.gd")
const H_GameplaySceneHandler = preload("res://scripts/scene_management/handlers/h_gameplay_scene_handler.gd")
const H_MenuSceneHandler = preload("res://scripts/scene_management/handlers/h_menu_scene_handler.gd")
const H_UISceneHandler = preload("res://scripts/scene_management/handlers/h_ui_scene_handler.gd")
const H_EndGameSceneHandler = preload("res://scripts/scene_management/handlers/h_endgame_scene_handler.gd")

var gameplay_handler: H_GameplaySceneHandler
var menu_handler: H_MenuSceneHandler
var ui_handler: H_UISceneHandler
var endgame_handler: H_EndGameSceneHandler


func before_each() -> void:
	gameplay_handler = H_GameplaySceneHandler.new()
	menu_handler = H_MenuSceneHandler.new()
	ui_handler = H_UISceneHandler.new()
	endgame_handler = H_EndGameSceneHandler.new()


## ============================================================================
## Gameplay Handler Tests
## ============================================================================

func test_gameplay_handler_returns_correct_scene_type() -> void:
	assert_eq(gameplay_handler.get_scene_type(), U_SCENE_REGISTRY.SceneType.GAMEPLAY,
		"Gameplay handler should return GAMEPLAY scene type")


func test_gameplay_handler_returns_gameplay_shell() -> void:
	assert_eq(gameplay_handler.get_shell_id(), StringName("gameplay"),
		"Gameplay handler should return 'gameplay' shell")


func test_gameplay_handler_does_not_track_history() -> void:
	assert_false(gameplay_handler.should_track_history(),
		"Gameplay handler should NOT track in history (clears stack)")


func test_gameplay_handler_requires_spawn_manager() -> void:
	var required := gameplay_handler.get_required_managers()
	assert_true(required.has(StringName("spawn_manager")),
		"Gameplay handler should require spawn_manager")


func test_gameplay_handler_requires_state_store() -> void:
	var required := gameplay_handler.get_required_managers()
	assert_true(required.has(StringName("state_store")),
		"Gameplay handler should require state_store")


func test_gameplay_handler_returns_start_game_action() -> void:
	var action := gameplay_handler.get_navigation_action(StringName("gameplay_base"))
	assert_true(action.has("type"), "Navigation action should have 'type' field")
	assert_eq(action["type"], StringName("navigation/start_game"),
		"Gameplay handler should return start_game action")


## ============================================================================
## Menu Handler Tests
## ============================================================================

func test_menu_handler_returns_correct_scene_type() -> void:
	assert_eq(menu_handler.get_scene_type(), U_SCENE_REGISTRY.SceneType.MENU,
		"Menu handler should return MENU scene type")


func test_menu_handler_returns_main_menu_shell() -> void:
	assert_eq(menu_handler.get_shell_id(), StringName("main_menu"),
		"Menu handler should return 'main_menu' shell")


func test_menu_handler_tracks_history() -> void:
	assert_true(menu_handler.should_track_history(),
		"Menu handler should track in history (enables back button)")


func test_menu_handler_does_not_require_spawn_manager() -> void:
	var required := menu_handler.get_required_managers()
	assert_false(required.has(StringName("spawn_manager")),
		"Menu handler should NOT require spawn_manager")


func test_menu_handler_requires_state_store() -> void:
	var required := menu_handler.get_required_managers()
	assert_true(required.has(StringName("state_store")),
		"Menu handler should require state_store")


func test_menu_handler_returns_set_shell_action() -> void:
	var action := menu_handler.get_navigation_action(StringName("main_menu"))
	assert_true(action.has("type"), "Navigation action should have 'type' field")
	assert_eq(action["type"], StringName("navigation/set_shell"),
		"Menu handler should return set_shell action")


## ============================================================================
## UI Handler Tests
## ============================================================================

func test_ui_handler_returns_correct_scene_type() -> void:
	assert_eq(ui_handler.get_scene_type(), U_SCENE_REGISTRY.SceneType.UI,
		"UI handler should return UI scene type")


func test_ui_handler_returns_main_menu_shell() -> void:
	assert_eq(ui_handler.get_shell_id(), StringName("main_menu"),
		"UI handler should return 'main_menu' shell (same as MENU)")


func test_ui_handler_tracks_history() -> void:
	assert_true(ui_handler.should_track_history(),
		"UI handler should track in history (enables back button)")


func test_ui_handler_does_not_require_spawn_manager() -> void:
	var required := ui_handler.get_required_managers()
	assert_false(required.has(StringName("spawn_manager")),
		"UI handler should NOT require spawn_manager")


func test_ui_handler_requires_state_store() -> void:
	var required := ui_handler.get_required_managers()
	assert_true(required.has(StringName("state_store")),
		"UI handler should require state_store")


func test_ui_handler_returns_set_shell_action() -> void:
	var action := ui_handler.get_navigation_action(StringName("settings_menu"))
	assert_true(action.has("type"), "Navigation action should have 'type' field")
	assert_eq(action["type"], StringName("navigation/set_shell"),
		"UI handler should return set_shell action")


## ============================================================================
## EndGame Handler Tests
## ============================================================================

func test_endgame_handler_returns_correct_scene_type() -> void:
	assert_eq(endgame_handler.get_scene_type(), U_SCENE_REGISTRY.SceneType.END_GAME,
		"EndGame handler should return END_GAME scene type")


func test_endgame_handler_returns_endgame_shell() -> void:
	assert_eq(endgame_handler.get_shell_id(), StringName("endgame"),
		"EndGame handler should return 'endgame' shell")


func test_endgame_handler_does_not_track_history() -> void:
	assert_false(endgame_handler.should_track_history(),
		"EndGame handler should NOT track in history (end state)")


func test_endgame_handler_does_not_require_spawn_manager() -> void:
	var required := endgame_handler.get_required_managers()
	assert_false(required.has(StringName("spawn_manager")),
		"EndGame handler should NOT require spawn_manager")


func test_endgame_handler_requires_state_store() -> void:
	var required := endgame_handler.get_required_managers()
	assert_true(required.has(StringName("state_store")),
		"EndGame handler should require state_store")


func test_endgame_handler_returns_set_shell_action() -> void:
	var action := endgame_handler.get_navigation_action(StringName("game_over"))
	assert_true(action.has("type"), "Navigation action should have 'type' field")
	assert_eq(action["type"], StringName("navigation/set_shell"),
		"EndGame handler should return set_shell action")


## ============================================================================
## Handler Behavior Comparison Tests
## ============================================================================

func test_menu_and_ui_handlers_have_same_shell() -> void:
	assert_eq(menu_handler.get_shell_id(), ui_handler.get_shell_id(),
		"MENU and UI handlers should use the same shell ('main_menu')")


func test_menu_and_ui_handlers_both_track_history() -> void:
	assert_true(menu_handler.should_track_history() and ui_handler.should_track_history(),
		"MENU and UI handlers should both track history")


func test_gameplay_and_endgame_handlers_both_clear_history() -> void:
	assert_false(gameplay_handler.should_track_history() or endgame_handler.should_track_history(),
		"GAMEPLAY and END_GAME handlers should both NOT track history")


func test_only_gameplay_requires_spawn_manager() -> void:
	assert_true(gameplay_handler.get_required_managers().has(StringName("spawn_manager")),
		"Only GAMEPLAY handler should require spawn_manager")
	assert_false(menu_handler.get_required_managers().has(StringName("spawn_manager")),
		"MENU handler should not require spawn_manager")
	assert_false(ui_handler.get_required_managers().has(StringName("spawn_manager")),
		"UI handler should not require spawn_manager")
	assert_false(endgame_handler.get_required_managers().has(StringName("spawn_manager")),
		"END_GAME handler should not require spawn_manager")


func test_all_handlers_require_state_store() -> void:
	assert_true(gameplay_handler.get_required_managers().has(StringName("state_store")),
		"GAMEPLAY handler should require state_store")
	assert_true(menu_handler.get_required_managers().has(StringName("state_store")),
		"MENU handler should require state_store")
	assert_true(ui_handler.get_required_managers().has(StringName("state_store")),
		"UI handler should require state_store")
	assert_true(endgame_handler.get_required_managers().has(StringName("state_store")),
		"END_GAME handler should require state_store")
