extends Node

## Test scene for User Story 4 (Menu Slice)
##
## Demonstrates menu navigation state management

@onready var state_display: Label = $UI/StateDisplay

var store: M_StateStore

func _ready() -> void:
	# Unlock cursor for UI interaction (test scene needs mouse)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Make sure UI can receive input (not paused)
	$UI.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wait for store to be ready
	await get_tree().process_frame
	
	store = U_StateUtils.get_store(self)
	if not store:
		print("[TEST] ERROR: Could not find M_StateStore")
		return
	
	# Unpause the game in case it starts paused
	if store:
		store.dispatch(U_GameplayActions.unpause_game())
	
	print("[TEST] Menu slice test scene starting...")
	
	# Connect button signals
	$UI/MenuButtons/BtnMainMenu.pressed.connect(_on_navigate.bind("main_menu"))
	$UI/MenuButtons/BtnSettings.pressed.connect(_on_navigate.bind("settings"))
	$UI/MenuButtons/BtnCharacterSelect.pressed.connect(_on_navigate.bind("character_select"))
	$UI/MenuButtons/BtnSelectWarrior.pressed.connect(_on_select_character.bind("warrior"))
	$UI/MenuButtons/BtnSelectMage.pressed.connect(_on_select_character.bind("mage"))
	$UI/MenuButtons/BtnSelectEasy.pressed.connect(_on_select_difficulty.bind("easy"))
	$UI/MenuButtons/BtnSelectHard.pressed.connect(_on_select_difficulty.bind("hard"))
	
	# Subscribe to state changes
	store.slice_updated.connect(_on_menu_slice_updated)
	
	# Display initial state
	_update_display()
	
	print("[TEST] Menu slice test ready - click buttons to test navigation!")

func _on_navigate(screen_name: String) -> void:
	print("[TEST] Navigating to: ", screen_name)
	store.dispatch(U_MenuActions.navigate_to_screen(screen_name))

func _on_select_character(character_id: String) -> void:
	print("[TEST] Selecting character: ", character_id)
	store.dispatch(U_MenuActions.select_character(character_id))

func _on_select_difficulty(difficulty: String) -> void:
	print("[TEST] Selecting difficulty: ", difficulty)
	store.dispatch(U_MenuActions.select_difficulty(difficulty))

func _on_menu_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name == StringName("menu"):
		_update_display()

func _update_display() -> void:
	var menu_state: Dictionary = store.get_slice(StringName("menu"))
	
	var active_screen: String = MenuSelectors.get_active_screen(menu_state)
	var pending_char: String = MenuSelectors.get_pending_character(menu_state)
	var pending_diff: String = MenuSelectors.get_pending_difficulty(menu_state)
	var is_config_complete: bool = MenuSelectors.is_game_config_complete(menu_state)
	
	var display_text := "Menu State:\n\n"
	display_text += "Active Screen: %s\n\n" % active_screen
	display_text += "Pending Character: %s\n" % (pending_char if not pending_char.is_empty() else "(none)")
	display_text += "Pending Difficulty: %s\n\n" % (pending_diff if not pending_diff.is_empty() else "(none)")
	display_text += "Config Complete: %s\n\n" % ("YES" if is_config_complete else "NO")
	display_text += "Full State:\n%s" % JSON.stringify(menu_state, "  ")
	
	state_display.text = display_text
