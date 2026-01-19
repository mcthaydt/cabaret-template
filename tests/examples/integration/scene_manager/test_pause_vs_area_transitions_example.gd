extends GutTest

## Integration tests covering pause actions during door-triggered scene transitions
##
## T074: Updated from ESC input tests to navigation action tests
## Focus:
## - Pause action during a fade transition triggered by a door should not open the pause overlay (deferred by reconciliation)
## - Pause action on the same frame as an AUTO door trigger should be ignored
## - Pause action while a transition is already in progress should be deferred

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/state/resources/rs_navigation_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

var _root: Node
var _store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer

func before_each() -> void:
	# Root node
	_root = Node.new()
	add_child_autofree(_root)

	# State store (scene + gameplay + navigation slices)
	_store = M_STATE_STORE.new()
	_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	_root.add_child(_store)

	# Containers
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	_root.add_child(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	_ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_ui_overlay_stack)

	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	color_rect.modulate.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.add_child(color_rect)
	_root.add_child(_transition_overlay)

	# Scene manager
	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root.add_child(_scene_manager)

	# Register managers with ServiceLocator (Phase 10B-7: T141c)
	U_ServiceLocator.register(StringName("state_store"), _store)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager)

	await get_tree().process_frame

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

	_scene_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_root = null

## Helper: Recursively find a node by exact name under given root
func _find_in_tree(root: Node, target_name: StringName) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_in_tree(child, target_name)
		if found != null:
			return found
	return null

## Helper: Load gameplay scene by ID via the scene manager (instant transition)
func _load_gameplay_scene(scene_id: StringName) -> void:
	_scene_manager.transition_to_scene(scene_id, "instant", _scene_manager.Priority.HIGH)
	await wait_physics_frames(2)

## Test: ESC is ignored while a door-triggered fade transition is in progress
func _test_esc_ignored_during_door_fade_transition_DISABLED() -> void:
	# Given: Start in exterior (gameplay) with no overlays
	await _load_gameplay_scene(StringName("exterior"))
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "No overlays at start")

	# Ensure door trigger area and player body exist (scene content provides both)
	var exterior_scene: Node = _active_scene_container.get_child(0) if _active_scene_container.get_child_count() > 0 else null
	assert_not_null(exterior_scene, "Exterior scene should be loaded")

	# Allow trigger component to create its Area3D
	await wait_physics_frames(4)

	var trigger_area: Area3D = _find_in_tree(exterior_scene, StringName("TriggerArea")) as Area3D
	assert_not_null(trigger_area, "Door TriggerArea should exist")

	var player_body: CharacterBody3D = _find_in_tree(exterior_scene, StringName("Player_Body")) as CharacterBody3D
	assert_not_null(player_body, "Player_Body should exist")

	# Ensure ECS manager has registered the player entity components
	var ecs_mgr := U_ServiceLocator.try_get_service(StringName("ecs_manager"))
	if ecs_mgr != null:
		var player_entity: Node = _find_in_tree(exterior_scene, StringName("E_Player"))
		var comp_map: Dictionary = (ecs_mgr.call("get_components_for_entity", player_entity) if ecs_mgr.has_method("get_components_for_entity") else {})
		assert_true(comp_map.has(StringName("C_PlayerTagComponent")), "Player entity should have player tag component")

	# When: Player enters AUTO trigger and ESC is pressed during the fade
	# Pre-check: verify the SceneManager instance used by triggers is our instance
	var registered_mgr := U_ServiceLocator.try_get_service(StringName("scene_manager"))
	assert_eq(registered_mgr, _scene_manager, "SceneManager instance should match ServiceLocator registration")

	# Resolve door controller and ensure we emit on its TriggerArea
	var door_controller: Node = _find_in_tree(exterior_scene, StringName("E_DoorTrigger"))
	if door_controller != null:
		var controller_area: Area3D = null
		if door_controller.has_method("get_trigger_area"):
			controller_area = door_controller.call("get_trigger_area") as Area3D
		assert_true(controller_area == trigger_area, "Must emit body_entered on the door's TriggerArea")

		var comp: Node = door_controller.get("_component") if door_controller.has_method("get") else null
		if comp != null:
			var area_path_val: Variant = comp.get("area_path")
			var trig_mode: Variant = comp.get("trigger_mode")
			assert_true(String(area_path_val) != "", "Component area_path should be set")

	var ctrl_armed := false
	var arm_frames := 0
	if door_controller.has_method("get"):
		ctrl_armed = bool(door_controller.get("_is_armed"))
		arm_frames = int(door_controller.get("_arming_frames_remaining"))
	assert_true(ctrl_armed, "Controller should be armed before emitting body_entered")

	# Emit trigger and immediately send ESC key event to scene manager
	print("[TEST] Emitting body_entered on door trigger area")
	print("[TEST] Player body: ", player_body.name)
	print("[TEST] Trigger area: ", trigger_area.name)
	print("[TEST] Door controller armed: ", ctrl_armed)
	trigger_area.body_entered.emit(player_body)
	await wait_physics_frames(2)

	# Inspect transition state right after trigger (queue may be popped immediately)
	var scene_state_now: Dictionary = _store.get_state().get("scene", {})
	print("[TEST] Scene state after door trigger: ", scene_state_now)
	print("[TEST] is_transitioning: ", scene_state_now.get("is_transitioning", false))
	print("[TEST] current_scene_id: ", scene_state_now.get("current_scene_id", StringName("")))
	assert_true(scene_state_now.get("is_transitioning", false), "Transition should be in progress after door trigger")

	# T074: Dispatch pause action during transition (should be deferred by reconciliation)
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame

	# Then: No pause overlay should be pushed while transitioning (reconciliation defers)
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Pause action should be deferred during transition (no pause overlay)")

	# Wait for fade (0.2s) to complete
	await wait_physics_frames(15)

	# And: Still no pause overlay after transition completes
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "No pause overlay after transition completion")

	# And: Scene should now be interior_house
	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("current_scene_id", StringName("")), StringName("interior_house"), "Should arrive at interior_house")

## Test: ESC pressed on the same frame as AUTO door trigger does not open pause
func _test_esc_same_frame_as_auto_trigger_is_ignored_DISABLED() -> void:
	# Given: Exterior scene active
	await _load_gameplay_scene(StringName("exterior"))
	await wait_physics_frames(2)

	var exterior_scene: Node = _active_scene_container.get_child(0) if _active_scene_container.get_child_count() > 0 else null
	assert_not_null(exterior_scene)

	var trigger_area: Area3D = _find_in_tree(exterior_scene, StringName("TriggerArea")) as Area3D
	var player_body: CharacterBody3D = _find_in_tree(exterior_scene, StringName("Player_Body")) as CharacterBody3D
	assert_not_null(trigger_area)
	assert_not_null(player_body)

	# When: Emit body_entered and pause action on the same frame
	trigger_area.body_entered.emit(player_body)
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame

	# Then: Pause overlay should not appear (reconciliation defers during transition)
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Pause overlay must not be pushed when door trigger fires")

	# Allow transition to complete
	await wait_physics_frames(15)
	assert_eq(_ui_overlay_stack.get_child_count(), 0)

## Test: Pause action deferred when a transition is already in progress (T074)
func test_pause_action_deferred_while_transitioning_general_case() -> void:
	# T074: Updated to use navigation actions instead of ESC input
	# Given: Already in a gameplay scene
	await _load_gameplay_scene(StringName("exterior"))

	# When: Start a fade transition programmatically and dispatch pause action during it
	_scene_manager.transition_to_scene(StringName("interior_house"), "fade", _scene_manager.Priority.HIGH)
	await get_tree().process_frame
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame

	# Then: No pause overlay is pushed while transitioning (reconciliation defers)
	assert_eq(_ui_overlay_stack.get_child_count(), 0)

	# And: Transition completes to interior_house
	await wait_physics_frames(15)
	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("current_scene_id", StringName("")), StringName("interior_house"))
