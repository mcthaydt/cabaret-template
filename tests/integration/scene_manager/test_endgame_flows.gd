extends GutTest

## Integration tests for end-game flows (Phase 9)
##
## Covers:
## - Death → ragdoll → Game Over scene transition (T165.5, T170)
## - Victory trigger gating + scene transitions (T165.4, T171, T172)
## - UI flows: Retry, Continue, Credits buttons (T167, T168, T175)
## - Credits auto-return to main menu (T169, T176)
##
## Tests are authored up-front (T162) and currently fail until
## implementation work for Phase 9 is complete.

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

const PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const HEALTH_COMPONENT := preload("res://scripts/ecs/components/c_health_component.gd")
const HEALTH_SYSTEM := preload("res://scripts/ecs/systems/s_health_system.gd")
const HEALTH_SETTINGS_RESOURCE := preload("res://resources/base_settings/gameplay/health_settings.tres")

const VICTORY_COMPONENT := preload("res://scripts/ecs/components/c_victory_trigger_component.gd")
const VICTORY_SYSTEM := preload("res://scripts/ecs/systems/s_victory_system.gd")

var _root: Node
var _state_store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer
var _loading_overlay: CanvasLayer
var _test_scene: Node3D
var _ecs_manager: M_ECS_MANAGER
var _entities_root: Node3D
var _systems_core: Node

func before_each() -> void:
	U_STATE_HANDOFF.clear_all()

	_root = Node.new()
	add_child_autofree(_root)

	_state_store = M_STATE_STORE.new()
	_state_store.settings = RS_STATE_STORE_SETTINGS.new()
	_state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_root.add_child(_state_store)

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
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = Color.BLACK
	color_rect.modulate.a = 0.0
	_transition_overlay.add_child(color_rect)
	_root.add_child(_transition_overlay)

	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.visible = false
	_loading_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_loading_overlay)

	# Create gameplay scene scaffold inside ActiveSceneContainer
	_test_scene = Node3D.new()
	_test_scene.name = "TestScene"
	_active_scene_container.add_child(_test_scene)

	_entities_root = Node3D.new()
	_entities_root.name = "Entities"
	_test_scene.add_child(_entities_root)

	var systems_root := Node.new()
	systems_root.name = "Systems"
	_test_scene.add_child(systems_root)

	_systems_core = Node.new()
	_systems_core.name = "Core"
	systems_root.add_child(_systems_core)

	_ecs_manager = M_ECS_MANAGER.new()
	_ecs_manager.name = "M_ECSManager"
	_test_scene.add_child(_ecs_manager)

	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_scene_manager.initial_scene_id = StringName("exterior")
	_root.add_child(_scene_manager)

	# Register managers with ServiceLocator (Phase 10B-7: T141c)
	U_ServiceLocator.register(StringName("state_store"), _state_store)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager)

	await get_tree().process_frame
	await wait_physics_frames(1)

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

	_root = null
	_state_store = null
	_scene_manager = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_loading_overlay = null
	_test_scene = null
	_ecs_manager = null
	_entities_root = null
	_systems_core = null

func _prepare_player_with_health() -> Dictionary:
	var player_entity := Node3D.new()
	player_entity.name = "E_Player"
	_entities_root.add_child(player_entity)

	var body := CharacterBody3D.new()
	body.name = "Body"
	player_entity.add_child(body)

	var player_tag := PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)

	var health_component := HEALTH_COMPONENT.new()
	health_component.name = "C_HealthComponent"

	if HEALTH_SETTINGS_RESOURCE != null:
		var settings := HEALTH_SETTINGS_RESOURCE.duplicate() as Resource
		if settings != null:
			if settings.has_method("duplicate_settings"):
				settings.death_animation_duration = 0.25
			health_component.set("settings", settings)

	if health_component.has_method("set_character_body_path"):
		health_component.set_character_body_path(NodePath("Body"))
	elif health_component.has_method("set"):
		health_component.set("character_body_path", NodePath("Body"))

	player_entity.add_child(health_component)

	var health_system := HEALTH_SYSTEM.new()
	health_system.name = "S_HealthSystem"
	_systems_core.add_child(health_system)

	await wait_physics_frames(2)

	return {
		"player": player_entity,
		"body": body,
		"health": health_component,
		"system": health_system
	}

func _prepare_victory_system() -> Dictionary:
	var victory_entity := Node3D.new()
	victory_entity.name = "E_VictoryTrigger"
	_entities_root.add_child(victory_entity)

	var victory_component := VICTORY_COMPONENT.new()
	victory_component.name = "C_VictoryTriggerComponent"
	victory_component.trigger_once = false
	victory_entity.add_child(victory_component)

	var victory_system := VICTORY_SYSTEM.new()
	victory_system.name = "S_VictorySystem"
	_systems_core.add_child(victory_system)

	await wait_physics_frames(2)

	return {
		"entity": victory_entity,
		"component": victory_component,
		"system": victory_system
	}

func _get_active_scene_instance() -> Node:
	if _active_scene_container == null:
		return null
	var scene_children: int = _active_scene_container.get_child_count()
	if scene_children == 0:
		return null
	return _active_scene_container.get_child(scene_children - 1)

func test_death_spawns_ragdoll_and_transitions_to_game_over() -> void:
	var fixture := await _prepare_player_with_health()
	if fixture.is_empty():
		return

	var health_component: Node = fixture["health"]
	assert_true(health_component.has_method("queue_instant_death"), "Health component must support instant death")
	health_component.call("queue_instant_death")

	await wait_physics_frames(2)

	var health_system: S_HealthSystem = fixture["system"]
	var ragdoll := health_system.get_ragdoll_for_entity(StringName("E_Player"))
	assert_not_null(ragdoll, "Ragdoll instance should spawn on death")

	await wait_seconds(0.6)

	assert_eq(_scene_manager.get_current_scene(), StringName("game_over"),
		"Game Over scene should load after death sequence completes")
	var nav_state: Dictionary = _state_store.get_state().get("navigation", {})
	assert_eq(nav_state.get("shell"), StringName("endgame"),
		"Navigation shell should switch to endgame when game_over loads")
	assert_eq(nav_state.get("base_scene_id"), StringName("game_over"),
		"Navigation base scene should point to game_over when game_over loads")

func test_game_over_retry_resets_health_and_returns_to_exterior() -> void:
	_scene_manager.transition_to_scene(StringName("game_over"), "instant")
	await wait_physics_frames(3)

	var nav_state: Dictionary = _state_store.get_state().get("navigation", {})
	assert_eq(nav_state.get("shell"), StringName("endgame"),
		"Navigation shell should switch to endgame for game_over screen")
	assert_eq(nav_state.get("base_scene_id"), StringName("game_over"),
		"Navigation base scene should point to game_over for game_over screen")

	var scene_instance: Control = _get_active_scene_instance() as Control
	assert_not_null(scene_instance, "Game Over scene should load into ActiveSceneContainer")

	var retry_button: Button = scene_instance.find_child("RetryButton", true, false) as Button
	assert_not_null(retry_button, "RetryButton must exist in game_over scene")

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.take_damage("E_Player", 999.0))
	await wait_physics_frames(1)

	retry_button.emit_signal("pressed")
	await wait_seconds(0.3)

	var gameplay_state: Dictionary = _state_store.get_state().get("gameplay", {})
	assert_almost_eq(float(gameplay_state.get("player_health", 0.0)),
		float(gameplay_state.get("player_max_health", 100.0)), 0.01,
		"Retry should restore player health to max")
	assert_eq(_scene_manager.get_current_scene(), StringName("exterior"),
		"Retry should transition back to exterior scene")

func test_victory_triggers_victory_scene_when_area_completed() -> void:
	var setup := await _prepare_victory_system()
	if setup.is_empty():
		return

	var player_fixture := await _prepare_player_with_health()
	if player_fixture.is_empty():
		return

	var victory_component: C_VictoryTriggerComponent = setup["component"]
	victory_component.victory_type = C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE

	var body: CharacterBody3D = player_fixture["body"]
	victory_component.call("_on_body_entered", body)
	await wait_physics_frames(1)

	if is_instance_valid(setup["system"]):
		setup["system"].call("process_tick", 0.016)
	await wait_physics_frames(2)

	assert_true(_scene_manager.get_current_scene() != StringName("victory"),
		"Victory should be gated until interior completion")

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.mark_area_complete("interior_house"))
	await wait_physics_frames(1)

	# It is possible for the Area3D to re-emit body_entered on the next
	# physics frame due to persistent overlap. If that already triggered
	# the transition, the component may have been freed by scene swap.
	if is_instance_valid(victory_component):
		victory_component.call("_on_body_entered", body)
		await wait_physics_frames(1)
		if is_instance_valid(setup["system"]):
			setup["system"].call("process_tick", 0.016)
	await wait_seconds(0.3)

	assert_eq(_scene_manager.get_current_scene(), StringName("victory"),
		"Victory scene should load once prerequisites satisfied")

func test_victory_continue_and_credits_buttons_route_correctly() -> void:
	_scene_manager.transition_to_scene(StringName("victory"), "instant")
	await wait_physics_frames(3)

	var scene_instance: Control = _get_active_scene_instance() as Control
	assert_not_null(scene_instance, "Victory scene should load into ActiveSceneContainer")

	var continue_button: Button = scene_instance.find_child("ContinueButton", true, false) as Button
	var credits_button: Button = scene_instance.find_child("CreditsButton", true, false) as Button
	var menu_button: Button = scene_instance.find_child("MenuButton", true, false) as Button

	assert_not_null(continue_button, "Continue button required")
	assert_not_null(credits_button, "Credits button required")
	assert_not_null(menu_button, "Menu button required")

	await wait_seconds(0.1)
	# Ensure clean state before test (clear any persisted state from previous runs)
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.reset_progress())
	await wait_physics_frames(2)

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.mark_area_complete("interior_house"))
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.trigger_victory(StringName("final_goal")))
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.increment_death_count())
	await wait_physics_frames(2)
	var gameplay_state: Dictionary = _state_store.get_state().get("gameplay", {})
	assert_false(bool(gameplay_state.get("game_completed", false)),
		"Game completed should be false before unlock")
	assert_false(credits_button.visible, "Credits button hidden until game_completed true")

	_state_store.dispatch(U_GAMEPLAY_ACTIONS.game_complete())
	await wait_physics_frames(2)
	await wait_seconds(0.1)
	assert_true(credits_button.visible, "Credits button visible once game completed")

	continue_button.emit_signal("pressed")
	await wait_seconds(0.4)
	assert_eq(_scene_manager.get_current_scene(), StringName("exterior"),
		"Continue should return to exterior hub")
	await wait_physics_frames(2)
	gameplay_state = _state_store.get_state().get("gameplay", {})
	assert_false(bool(gameplay_state.get("game_completed", true)),
		"Reset should clear game_completed flag")
	var post_reset_areas: Variant = gameplay_state.get("completed_areas", [])
	assert_true(post_reset_areas.is_empty(),
		"Reset should clear completed areas")
	assert_eq(int(gameplay_state.get("death_count", -1)), 0,
		"Reset should clear death count")
	assert_eq(gameplay_state.get("last_victory_objective", StringName("sentinel")), StringName(""),
		"Reset should clear last victory objective")
	assert_eq(gameplay_state.get("target_spawn_point", StringName("sentinel")), StringName(""),
		"Reset should clear pending spawn point")
	assert_eq(float(gameplay_state.get("player_health", -1.0)), float(gameplay_state.get("player_max_health", -1.0)),
		"Reset should restore player health to max")
	var entity_snapshots: Variant = gameplay_state.get("entities", {})
	var player_entity_id: String = String(gameplay_state.get("player_entity_id", "player"))
	if entity_snapshots is Dictionary:
		var snapshot_dict: Dictionary = entity_snapshots as Dictionary
		if snapshot_dict.has(player_entity_id):
			var player_snapshot: Dictionary = snapshot_dict[player_entity_id]
			assert_eq(float(player_snapshot.get("health", -1.0)), float(gameplay_state.get("player_max_health", -1.0)),
				"Reset should restore snapshot health")
			assert_false(player_snapshot.get("is_dead", true),
				"Reset should clear snapshot is_dead flag")
			assert_eq(snapshot_dict.size(), 1, "Reset should remove non-player snapshots")
		else:
			assert_true(snapshot_dict.is_empty(),
				"Reset should not retain non-player snapshots")

	_scene_manager.transition_to_scene(StringName("victory"), "instant")
	await wait_physics_frames(3)
	scene_instance = _get_active_scene_instance() as Control
	menu_button = scene_instance.find_child("MenuButton", true, false) as Button
	assert_not_null(menu_button, "Menu button should exist after reload")
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.mark_area_complete("interior_house"))
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.game_complete())
	await wait_physics_frames(2)
	await wait_seconds(0.1)
	menu_button.emit_signal("pressed")
	await wait_seconds(0.4)
	assert_eq(_scene_manager.get_current_scene(), StringName("main_menu"),
		"Menu button should return to main menu")
	await wait_physics_frames(2)
	gameplay_state = _state_store.get_state().get("gameplay", {})
	assert_false(bool(gameplay_state.get("game_completed", true)),
		"Menu reset should clear game_completed flag")
	assert_true(gameplay_state.get("completed_areas", []).is_empty(),
		"Menu reset should clear completed areas")

	_scene_manager.transition_to_scene(StringName("victory"), "instant")
	await wait_physics_frames(3)
	scene_instance = _get_active_scene_instance() as Control
	credits_button = scene_instance.find_child("CreditsButton", true, false) as Button
	assert_not_null(credits_button, "Credits button should exist on reload")
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.mark_area_complete("interior_house"))
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.game_complete())
	await wait_physics_frames(2)
	await wait_seconds(0.1)
	assert_true(credits_button.visible, "Credits button should be visible post-completion")

	credits_button.emit_signal("pressed")
	await wait_seconds(0.4)
	assert_eq(_scene_manager.get_current_scene(), StringName("credits"),
		"Credits button should open credits scene")
	await wait_physics_frames(2)
	gameplay_state = _state_store.get_state().get("gameplay", {})
	assert_false(bool(gameplay_state.get("game_completed", true)),
		"Credits navigation should clear game_completed flag")
	assert_true(gameplay_state.get("completed_areas", []).is_empty(),
		"Credits navigation should clear completed areas")

func test_credits_auto_return_to_main_menu() -> void:
	_scene_manager.transition_to_scene(StringName("credits"), "instant")
	await wait_physics_frames(3)

	var scene_instance: Control = _get_active_scene_instance() as Control
	assert_not_null(scene_instance, "Credits scene should load into ActiveSceneContainer")

	if scene_instance.has_method("set_test_durations"):
		scene_instance.call("set_test_durations", 0.2, 0.25)

	await wait_seconds(0.7)

	assert_eq(_scene_manager.get_current_scene(), StringName("main_menu"),
		"Credits should auto-return to main menu after timer expires")
