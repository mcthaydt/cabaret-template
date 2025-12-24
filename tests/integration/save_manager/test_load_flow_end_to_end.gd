extends BaseTest

## End-to-end integration tests for Save Manager load flows.
##
## Covers the Phase 7 "manual testing requirements" by exercising:
## - Main menu Load Game → slot select → correct scene loads
## - Pause menu context Load Game → slot select → correct scene loads
## - Continue button after restart loads correct scene + spawn + HUD + physics
## - Bug #6: overlays do not reopen after load
## - Bug #5: first Continue loads correct location
## - Loading-screen transition used when scene requires it

const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_SpawnManager := preload("res://scripts/managers/m_spawn_manager.gd")
const M_PauseManager := preload("res://scripts/managers/m_pause_manager.gd")

const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_SaveInitialState := preload("res://scripts/state/resources/rs_save_initial_state.gd")

const U_SaveManager := preload("res://scripts/state/utils/u_save_manager.gd")
const U_SaveEnvelope := preload("res://scripts/state/utils/u_save_envelope.gd")
const RS_SaveSlotMetadata := preload("res://scripts/state/resources/rs_save_slot_metadata.gd")
const U_SaveActions := preload("res://scripts/state/actions/u_save_actions.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")

const C_InputComponent := preload("res://scripts/ecs/components/c_input_component.gd")
const C_FloatingComponent := preload("res://scripts/ecs/components/c_floating_component.gd")

const DEFAULT_BOOT_INITIAL := preload("res://resources/state/default_boot_initial_state.tres")
const DEFAULT_MENU_INITIAL := preload("res://resources/state/default_menu_initial_state.tres")
const DEFAULT_NAVIGATION_INITIAL := preload("res://resources/state/navigation_initial_state.tres")
const DEFAULT_GAMEPLAY_INITIAL := preload("res://resources/state/default_gameplay_initial_state.tres")
const DEFAULT_SCENE_INITIAL := preload("res://resources/state/default_scene_initial_state.tres")
const DEFAULT_SETTINGS_INITIAL := preload("res://resources/state/default_settings_initial_state.tres")
const DEFAULT_DEBUG_INITIAL := preload("res://resources/state/default_debug_initial_state.tres")

const OVERLAY_META_SCENE_ID := StringName("_scene_manager_overlay_scene_id")
const LEGACY_SAVE_PATH := "user://savegame.json"

var _root_scene: Node
var _store: M_StateStore
var _scene_manager: M_SceneManager
var _spawn_manager: M_SpawnManager
var _pause_manager: M_PauseManager

var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer
var _loading_overlay: CanvasLayer

func before_each() -> void:
	U_StateHandoff.clear_all()
	_cleanup_save_files()

	_root_scene = Node.new()
	_root_scene.name = "Root"
	add_child_autofree(_root_scene)

	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	_root_scene.add_child(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	_ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_scene.add_child(_ui_overlay_stack)

	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	color_rect.modulate.a = 0.0
	_transition_overlay.add_child(color_rect)
	_root_scene.add_child(_transition_overlay)

	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.visible = false
	_loading_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_scene.add_child(_loading_overlay)

	# Register overlays for SceneManager discovery in test environments.
	U_ServiceLocator.register(StringName("transition_overlay"), _transition_overlay)
	U_ServiceLocator.register(StringName("loading_overlay"), _loading_overlay)

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false  # Avoid legacy autoload (Bug #5 regression surface)
	_store.settings.auto_save_interval = 0.0
	_store.settings.enable_debug_logging = false
	_store.settings.enable_debug_overlay = false
	_store.boot_initial_state = DEFAULT_BOOT_INITIAL
	_store.menu_initial_state = DEFAULT_MENU_INITIAL
	_store.navigation_initial_state = DEFAULT_NAVIGATION_INITIAL
	_store.gameplay_initial_state = DEFAULT_GAMEPLAY_INITIAL
	_store.scene_initial_state = DEFAULT_SCENE_INITIAL
	_store.settings_initial_state = DEFAULT_SETTINGS_INITIAL
	_store.debug_initial_state = DEFAULT_DEBUG_INITIAL
	_store.save_initial_state = RS_SaveInitialState.new()
	_root_scene.add_child(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	_spawn_manager = M_SpawnManager.new()
	_root_scene.add_child(_spawn_manager)
	U_ServiceLocator.register(StringName("spawn_manager"), _spawn_manager)
	await get_tree().process_frame

	_pause_manager = M_PauseManager.new()
	_root_scene.add_child(_pause_manager)
	U_ServiceLocator.register(StringName("pause_manager"), _pause_manager)
	await get_tree().process_frame

	_scene_manager = M_SceneManager.new()
	_scene_manager.initial_scene_id = StringName("main_menu")
	_root_scene.add_child(_scene_manager)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager)
	await get_tree().process_frame

func after_each() -> void:
	get_tree().paused = false
	_cleanup_save_files()
	U_StateHandoff.clear_all()
	_root_scene = null
	_store = null
	_scene_manager = null
	_spawn_manager = null
	_pause_manager = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_loading_overlay = null
	super.after_each()

func test_load_from_main_menu_load_game_button_loads_correct_scene() -> void:
	_write_save_slot(
		1,
		StringName("scene2"),
		{
			"play_time_seconds": 12.0,
			"player_health": 88.0,
			"player_max_health": 100.0,
			"death_count": 2,
		}
	)

	var menu_ready := await _await_scene_and_settled(StringName("main_menu"), 120)
	assert_true(menu_ready, "Setup failed: main_menu did not finish loading")

	var main_menu := _get_active_scene_root()
	assert_not_null(main_menu, "Active scene should be main_menu instance")
	if main_menu == null:
		return

	var load_button: Button = main_menu.get_node_or_null("%LoadGameButton") as Button
	assert_not_null(load_button, "Main menu should have LoadGameButton")
	if load_button == null:
		return

	var load_connected := await _await_button_connected(load_button, main_menu, StringName("_on_load_pressed"), 60)
	assert_true(load_connected, "Main menu should connect LoadGameButton before interaction")
	if not load_connected:
		return

	load_button.pressed.emit()
	await wait_physics_frames(2)

	var selector := await _await_top_overlay_scene_id(StringName("ui_save_slot_selector"), 120)
	assert_not_null(selector, "Save slot selector overlay should open from main menu")
	if selector == null:
		return

	var slot_1: Button = selector.get_node_or_null("%Slot1") as Button
	assert_not_null(slot_1, "Save slot selector should have Slot1 button")
	if slot_1 == null:
		return

	slot_1.pressed.emit()

	var scene_ready := await _await_scene_and_settled(StringName("scene2"), 240)
	assert_true(scene_ready, "Should load scene2 from main menu load flow")
	var active_loaded := await _await_active_scene_root_named("TestScene2", 240)
	assert_true(active_loaded, "ActiveSceneContainer should load TestScene2")

	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Bug #6: No overlays should remain after load")
	var nav: Dictionary = _store.get_slice(StringName("navigation"))
	var overlay_stack_variant: Variant = nav.get("overlay_stack", [])
	var overlay_stack: Array = overlay_stack_variant if overlay_stack_variant is Array else []
	assert_true(overlay_stack.is_empty(), "Bug #6: navigation.overlay_stack should be empty after load")

func test_load_from_pause_menu_context_loads_correct_scene() -> void:
	_write_save_slot(
		1,
		StringName("scene3"),
		{
			"play_time_seconds": 34.0,
			"player_health": 55.0,
			"player_max_health": 100.0,
			"death_count": 4,
		}
	)

	_store.dispatch(U_NavigationActions.start_game(StringName("scene1")))
	var gameplay_ready := await _await_scene_and_settled(StringName("scene1"), 120)
	assert_true(gameplay_ready, "Setup failed: scene1 did not finish loading")

	_store.dispatch(U_NavigationActions.open_pause())
	await wait_physics_frames(5)
	assert_true(get_tree().paused, "Tree should pause when pause overlay opens")

	# Open the save slot selector in LOAD mode while paused (pause-menu context).
	_store.dispatch(U_SaveActions.set_save_mode(1)) # UI_SaveSlotSelector.Mode.LOAD
	_store.dispatch(U_NavigationActions.open_overlay(StringName("save_slot_selector_overlay")))

	var selector := await _await_top_overlay_scene_id(StringName("ui_save_slot_selector"), 120)
	assert_not_null(selector, "Save slot selector overlay should open from pause-menu context")

	var slot_1: Button = selector.get_node_or_null("%Slot1") as Button
	assert_not_null(slot_1, "Save slot selector should have Slot1 button")
	slot_1.pressed.emit()

	var scene_ready := await _await_scene_and_settled(StringName("scene3"), 240)
	assert_true(scene_ready, "Should load scene3 from pause-menu load flow")
	var active_loaded := await _await_active_scene_root_named("TestScene3", 240)
	assert_true(active_loaded, "ActiveSceneContainer should load TestScene3")

	assert_false(get_tree().paused, "Tree should be unpaused after load completes")
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Bug #6: overlays should not reopen after load")

func test_continue_after_restart_loads_spawn_health_physics_and_loading_screen() -> void:
	# Saved gameplay state
	_write_save_slot(
		1,
		StringName("exterior"),
		{
			"play_time_seconds": 99.0,
			"player_health": 42.0,
			"player_max_health": 100.0,
			"death_count": 7,
			"target_spawn_point": StringName("sp_exit_from_house"),
			"last_checkpoint": StringName("sp_checkpoint_safe"),
		}
	)

	var menu_ready := await _await_scene_and_settled(StringName("main_menu"), 120)
	assert_true(menu_ready, "Setup failed: main_menu did not finish loading")

	var main_menu := _get_active_scene_root()
	assert_not_null(main_menu, "Active scene should be main_menu instance")
	if main_menu == null:
		return

	# Wait for deferred visibility update.
	await wait_physics_frames(2)

	var continue_button: Button = main_menu.get_node_or_null("%ContinueButton") as Button
	assert_not_null(continue_button, "Main menu should have ContinueButton")
	if continue_button == null:
		return

	var continue_connected := await _await_button_connected(continue_button, main_menu, StringName("_on_continue_pressed"), 60)
	assert_true(continue_connected, "Main menu should connect ContinueButton before interaction")
	if not continue_connected:
		return

	var continue_visible := await _await_control_visible(continue_button, 60)
	assert_true(continue_visible, "Continue should be visible when a save exists")
	if not continue_visible:
		return

	continue_button.pressed.emit()

	# Verify loading transition is used for exterior and loading overlay becomes visible.
	var saw_loading_type := false
	var saw_loading_overlay := false
	for _i in range(60):
		await wait_physics_frames(1)
		var scene_state: Dictionary = _store.get_slice(StringName("scene"))
		if scene_state.get("is_transitioning", false) and StringName(scene_state.get("transition_type", "")) == StringName("loading"):
			saw_loading_type = true
		if _loading_overlay != null and _loading_overlay.visible:
			saw_loading_overlay = true
		if saw_loading_type and saw_loading_overlay:
			break
	assert_true(saw_loading_type, "Transition type should be 'loading' for exterior")
	assert_true(saw_loading_overlay, "LoadingOverlay should become visible during loading transition")

	var gameplay_ready := await _await_scene_and_settled(StringName("exterior"), 360)
	assert_true(gameplay_ready, "Continue should load exterior on first press (Bug #5)")

	# Bug #6: Ensure no overlays remain after load.
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "No overlays should remain after Continue load")

	# Spawn + checkpoint state
	var gameplay: Dictionary = _store.get_slice(StringName("gameplay"))
	assert_eq(gameplay.get("death_count", -1), 7, "Death count should restore from save")
	assert_eq(gameplay.get("last_checkpoint", StringName("")), StringName("sp_checkpoint_safe"), "Checkpoint should restore from save")

	var exterior_scene := _get_active_scene_root()
	assert_not_null(exterior_scene, "Active scene should be exterior instance")
	if exterior_scene == null:
		return

	var spawn_point: Node3D = exterior_scene.get_node_or_null("Entities/SP_SpawnPoints/sp_exit_from_house") as Node3D
	assert_not_null(spawn_point, "Exterior scene should have spawn point sp_exit_from_house")
	if spawn_point == null:
		return

	var player_body: CharacterBody3D = exterior_scene.get_node_or_null("Entities/E_Player/Player_Body") as CharacterBody3D
	assert_not_null(player_body, "Player_Body should exist after load")
	if player_body == null:
		return

	# Player should be near the saved spawn point (do not require exact match; physics may settle)
	var spawn_distance: float = player_body.global_position.distance_to(spawn_point.global_position)
	assert_lt(spawn_distance, 0.5, "Player should spawn near saved spawn point (distance %.3f)" % spawn_distance)

	# Ensure the player is not stuck: can move and jump.
	var input_component: C_InputComponent = exterior_scene.get_node_or_null("Entities/E_Player/Components/C_InputComponent") as C_InputComponent
	assert_not_null(input_component, "Player should have C_InputComponent")
	if input_component == null:
		return

	# HUD health bar reflects saved value (validate early before regeneration can tick).
	var hud := get_tree().get_first_node_in_group("hud_layers") as CanvasLayer
	assert_not_null(hud, "HUD should exist in gameplay scene")
	if hud == null:
		return
	var health_bar: ProgressBar = hud.get_node_or_null("MarginContainer/VBoxContainer/HealthBar") as ProgressBar
	assert_not_null(health_bar, "HUD should have HealthBar")
	if health_bar == null:
		return

	var saw_saved_health := await _await_health_bar_value(health_bar, 42, 60)
	assert_true(saw_saved_health, "Health bar value should restore to saved health shortly after load")

	# Ensure the player is not stuck: wait for stable support (floor OR floating support).
	var floating_component: C_FloatingComponent = exterior_scene.get_node_or_null("Entities/E_Player/Components/C_FloatingComponent") as C_FloatingComponent
	var supported := await _await_player_supported(player_body, floating_component, 180)
	assert_true(supported, "Player should have support after load (not stuck in air)")

	var start_pos: Vector3 = player_body.global_position
	input_component.set_move_vector(Vector2(1.0, 0.0))
	await wait_physics_frames(30)
	input_component.set_move_vector(Vector2.ZERO)

	var moved_distance: float = Vector2(
		player_body.global_position.x - start_pos.x,
		player_body.global_position.z - start_pos.z
	).length()
	assert_gt(moved_distance, 0.1, "Player should be able to move after load")

	var before_jump_y: float = player_body.global_position.y
	input_component.set_jump_pressed(true)
	await wait_physics_frames(6)
	input_component.set_jump_pressed(false)
	var after_jump_y: float = player_body.global_position.y
	assert_gt(after_jump_y, before_jump_y + 0.1, "Player should be able to jump after load")


# ==============================================================================
# Helpers
# ==============================================================================

func _cleanup_save_files() -> void:
	for i in range(1, 4):
		U_SaveManager.delete_slot(i)

	var auto_path := U_SaveManager.get_auto_slot_path()
	if FileAccess.file_exists(auto_path):
		DirAccess.remove_absolute(auto_path)

	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(LEGACY_SAVE_PATH)
	if FileAccess.file_exists(U_SaveManager.DEFAULT_LEGACY_BACKUP_PATH):
		DirAccess.remove_absolute(U_SaveManager.DEFAULT_LEGACY_BACKUP_PATH)

func _build_base_state() -> Dictionary:
	return {
		"boot": DEFAULT_BOOT_INITIAL.to_dictionary(),
		"menu": DEFAULT_MENU_INITIAL.to_dictionary(),
		"navigation": DEFAULT_NAVIGATION_INITIAL.to_dictionary(),
		"gameplay": DEFAULT_GAMEPLAY_INITIAL.to_dictionary(),
		"scene": DEFAULT_SCENE_INITIAL.to_dictionary(),
		"settings": DEFAULT_SETTINGS_INITIAL.to_dictionary(),
		"debug": DEFAULT_DEBUG_INITIAL.to_dictionary(),
		"save": RS_SaveInitialState.new().to_dictionary(),
	}

func _write_save_slot(slot_index: int, scene_id: StringName, gameplay_patch: Dictionary) -> void:
	var state := _build_base_state()

	var scene_slice: Dictionary = state.get("scene", {})
	scene_slice["current_scene_id"] = scene_id
	scene_slice["is_transitioning"] = false
	scene_slice["transition_type"] = ""
	state["scene"] = scene_slice

	var gameplay_slice: Dictionary = state.get("gameplay", {})
	for key in gameplay_patch.keys():
		gameplay_slice[key] = gameplay_patch[key]
	state["gameplay"] = gameplay_slice

	var metadata := RS_SaveSlotMetadata.new()
	metadata.slot_id = slot_index
	metadata.slot_type = RS_SaveSlotMetadata.SlotType.MANUAL
	metadata.is_empty = false
	metadata.timestamp = Time.get_unix_time_from_system()
	metadata.scene_id = scene_id
	metadata.scene_name = String(scene_id)
	metadata.play_time_seconds = float(gameplay_slice.get("play_time_seconds", 0.0))
	metadata.player_health = float(gameplay_slice.get("player_health", 0.0))
	metadata.player_max_health = float(gameplay_slice.get("player_max_health", 0.0))
	metadata.death_count = int(gameplay_slice.get("death_count", 0))

	var path := U_SaveManager.get_manual_slot_path(slot_index)
	var err := U_SaveEnvelope.write_envelope(path, metadata, state)
	assert_eq(err, OK, "Test setup: failed to write save envelope")

func _get_active_scene_root() -> Node:
	if _active_scene_container == null or _active_scene_container.get_child_count() == 0:
		return null
	return _active_scene_container.get_child(0)

func _await_scene_and_settled(scene_id: StringName, timeout_frames: int) -> bool:
	for i in range(timeout_frames):
		await wait_physics_frames(1)
		var scene_state: Dictionary = _store.get_slice(StringName("scene"))
		if scene_state.get("current_scene_id", StringName("")) == scene_id \
				and not scene_state.get("is_transitioning", false):
			return true
	return false

func _await_scene_transition_type(transition_type: StringName, timeout_frames: int) -> bool:
	for i in range(timeout_frames):
		await wait_physics_frames(1)
		var scene_state: Dictionary = _store.get_slice(StringName("scene"))
		if scene_state.get("is_transitioning", false) and StringName(scene_state.get("transition_type", "")) == transition_type:
			return true
	return false

func _await_loading_overlay_visible(timeout_frames: int) -> bool:
	for i in range(timeout_frames):
		await wait_physics_frames(1)
		if _loading_overlay != null and _loading_overlay.visible:
			return true
	return false

func _await_top_overlay_scene_id(scene_id: StringName, timeout_frames: int) -> Node:
	for i in range(timeout_frames):
		await wait_physics_frames(1)
		if _ui_overlay_stack == null or _ui_overlay_stack.get_child_count() == 0:
			continue
		var top: Node = _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1)
		var meta: Variant = top.get_meta(OVERLAY_META_SCENE_ID, null)
		var resolved: StringName = StringName("")
		if meta is StringName:
			resolved = meta as StringName
		elif meta is String:
			resolved = StringName(meta)
		if resolved == scene_id:
			return top
	return null

func _await_on_floor(body: CharacterBody3D, timeout_frames: int) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	for i in range(timeout_frames):
		await wait_physics_frames(1)
		if not is_instance_valid(body):
			return false
		if body.is_on_floor():
			return true
	return false

func _await_player_supported(body: CharacterBody3D, floating_component: C_FloatingComponent, timeout_frames: int) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	for _i in range(timeout_frames):
		await wait_physics_frames(1)
		if not is_instance_valid(body):
			return false

		var supported := body.is_on_floor()
		if not supported and floating_component != null and is_instance_valid(floating_component):
			supported = floating_component.grounded_stable or floating_component.is_supported
		if supported:
			return true
	return false

func _await_health_bar_value(health_bar: ProgressBar, expected_value: float, timeout_frames: int) -> bool:
	if health_bar == null:
		return false
	for _i in range(timeout_frames):
		await wait_physics_frames(1)
		if not health_bar.visible:
			continue
		if int(round(health_bar.max_value)) != 100:
			continue
		if int(round(health_bar.value)) == int(round(expected_value)):
			return true
	return false

func _await_active_scene_root_named(expected_name: String, timeout_frames: int) -> bool:
	for _i in range(timeout_frames):
		await wait_physics_frames(1)
		var scene := _get_active_scene_root()
		if scene != null and scene.name == expected_name:
			return true
	return false

func _await_button_connected(button: Button, target: Object, method: StringName, timeout_frames: int) -> bool:
	if button == null or target == null:
		return false
	var callable := Callable(target, String(method))
	for _i in range(timeout_frames):
		await wait_physics_frames(1)
		if button.pressed.is_connected(callable):
			return true
	return false

func _await_control_visible(control: Control, timeout_frames: int) -> bool:
	if control == null:
		return false
	for _i in range(timeout_frames):
		await wait_physics_frames(1)
		if control.visible:
			return true
	return false
