extends Node

## Test scene for User Story 5 (State Transitions)
##
## Demonstrates complete state flow: Boot → Menu → Gameplay → Menu

@onready var flow_display: Label = $UI/FlowDisplay
@onready var start_button: Button = $UI/StartButton

var store: M_StateStore
var current_step := 0
var flow_log: Array[String] = []

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
	
	print("[TEST] Full flow test scene starting...")
	
	# Connect button
	start_button.pressed.connect(_on_start_flow)
	
	# Subscribe to all slice updates
	store.slice_updated.connect(_on_slice_updated)
	
	_update_display()

func _on_start_flow() -> void:
	print("[TEST] Starting full flow test...")
	flow_log.clear()
	current_step = 0
	start_button.disabled = true
	
	_add_log("=== FULL FLOW TEST START ===")
	_add_log("")
	
	# Start the flow
	await _run_flow()
	
	_add_log("")
	_add_log("=== FLOW TEST COMPLETE ===")
	start_button.disabled = false

func _run_flow() -> void:
	# Step 1: Boot sequence
	_add_log("STEP 1: BOOT SEQUENCE")
	_add_log("- Simulating asset loading...")
	
	store.dispatch(U_BootActions.update_loading_progress(0.25))
	await get_tree().create_timer(0.3).timeout
	_add_log("  Loading: 25%")
	
	store.dispatch(U_BootActions.update_loading_progress(0.5))
	await get_tree().create_timer(0.3).timeout
	_add_log("  Loading: 50%")
	
	store.dispatch(U_BootActions.update_loading_progress(0.75))
	await get_tree().create_timer(0.3).timeout
	_add_log("  Loading: 75%")
	
	store.dispatch(U_BootActions.update_loading_progress(1.0))
	await get_tree().create_timer(0.3).timeout
	_add_log("  Loading: 100%")
	
	store.dispatch(U_BootActions.boot_complete())
	await get_tree().create_timer(0.3).timeout
	
	var boot_state: Dictionary = store.get_slice(StringName("boot"))
	_add_log("- Boot complete! is_ready = %s" % boot_state.get("is_ready"))
	_add_log("")
	
	# Step 2: Transition to menu
	_add_log("STEP 2: TRANSITION TO MENU")
	store.dispatch(U_TransitionActions.transition_to_menu())
	await get_tree().create_timer(0.5).timeout
	
	var menu_state: Dictionary = store.get_slice(StringName("menu"))
	_add_log("- Menu active! Screen: %s" % menu_state.get("active_screen"))
	_add_log("")
	
	# Step 3: Configure game
	_add_log("STEP 3: MENU CONFIGURATION")
	_add_log("- Navigating to character select...")
	store.dispatch(U_MenuActions.navigate_to_screen("character_select"))
	await get_tree().create_timer(0.3).timeout
	
	_add_log("- Selecting character: Warrior")
	store.dispatch(U_MenuActions.select_character("warrior"))
	await get_tree().create_timer(0.3).timeout
	
	_add_log("- Selecting difficulty: Hard")
	store.dispatch(U_MenuActions.select_difficulty("hard"))
	await get_tree().create_timer(0.3).timeout
	
	menu_state = store.get_slice(StringName("menu"))
	_add_log("- Config complete: %s @ %s" % [
		menu_state.get("pending_character"),
		menu_state.get("pending_difficulty")
	])
	_add_log("")
	
	# Step 4: Transition to gameplay
	_add_log("STEP 4: TRANSITION TO GAMEPLAY")
	var config: Dictionary = {
		"character": menu_state.get("pending_character"),
		"difficulty": menu_state.get("pending_difficulty")
	}
	store.dispatch(U_TransitionActions.transition_to_gameplay(config))
	await get_tree().create_timer(0.5).timeout
	
	var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
	_add_log("- Gameplay started!")
	_add_log("  Character: %s" % gameplay_state.get("character"))
	_add_log("  Difficulty: %s" % gameplay_state.get("difficulty"))
	_add_log("  Health: %s" % gameplay_state.get("health"))
	_add_log("  Score: %s" % gameplay_state.get("score"))
	_add_log("")
	
	# Step 5: Play game
	_add_log("STEP 5: GAMEPLAY")
	_add_log("- Simulating gameplay...")
	
	await get_tree().create_timer(0.3).timeout
	store.dispatch(U_GameplayActions.add_score(100))
	_add_log("  Score: +100")
	
	await get_tree().create_timer(0.3).timeout
	store.dispatch(U_GameplayActions.take_damage(20))
	_add_log("  Health: -20")
	
	await get_tree().create_timer(0.3).timeout
	store.dispatch(U_GameplayActions.add_score(250))
	_add_log("  Score: +250")
	
	await get_tree().create_timer(0.3).timeout
	store.dispatch(U_GameplayActions.set_level(2))
	_add_log("  Level: 2")
	
	gameplay_state = store.get_slice(StringName("gameplay"))
	_add_log("- Final stats: Health=%s, Score=%s, Level=%s" % [
		gameplay_state.get("health"),
		gameplay_state.get("score"),
		gameplay_state.get("level")
	])
	_add_log("")
	
	# Step 6: Return to menu
	_add_log("STEP 6: TRANSITION BACK TO MENU")
	store.dispatch(U_TransitionActions.transition_to_menu())
	await get_tree().create_timer(0.5).timeout
	
	menu_state = store.get_slice(StringName("menu"))
	_add_log("- Back in menu! Screen: %s" % menu_state.get("active_screen"))
	_add_log("")
	
	# Step 7: Verify all state preserved
	_add_log("STEP 7: VERIFICATION")
	boot_state = store.get_slice(StringName("boot"))
	gameplay_state = store.get_slice(StringName("gameplay"))
	
	_add_log("- Boot state preserved: is_ready = %s" % boot_state.get("is_ready"))
	_add_log("- Gameplay state preserved:")
	_add_log("  Character: %s" % gameplay_state.get("character"))
	_add_log("  Score: %s" % gameplay_state.get("score"))
	_add_log("  Level: %s" % gameplay_state.get("level"))
	_add_log("  Health: %s" % gameplay_state.get("health"))

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	_update_display()

func _add_log(message: String) -> void:
	flow_log.append(message)
	print("[FLOW] ", message)
	_update_display()

func _update_display() -> void:
	var display_text := "Full Flow Test: Boot → Menu → Gameplay → Menu\n\n"
	
	# Show log
	for line in flow_log:
		display_text += line + "\n"
	
	flow_display.text = display_text
