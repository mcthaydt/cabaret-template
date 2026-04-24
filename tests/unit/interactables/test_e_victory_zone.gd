extends BaseTest

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_scene_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const RS_OBJECTIVES_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_objectives_initial_state.gd")
const U_OBJECTIVES_ACTIONS := preload("res://scripts/state/actions/u_objectives_actions.gd")
const RS_VICTORY_INTERACTION_CONFIG := preload("res://scripts/core/resources/interactions/rs_victory_interaction_config.gd")
const RS_HAZARD_INTERACTION_CONFIG := preload("res://scripts/core/resources/interactions/rs_hazard_interaction_config.gd")
const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/core/resources/ecs/rs_scene_trigger_settings.gd")

class TestVictoryComponent:
	extends C_VictoryTriggerComponent

	var resolve_called: bool = false

	func _resolve_area() -> void:
		resolve_called = true
		super._resolve_area()

var _store: M_StateStore = null

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func before_each() -> void:
	U_ServiceLocator.clear()
	_store = M_STATE_STORE.new()
	_store.settings = RS_STATE_STORE_SETTINGS.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_global_settings_persistence = false
	_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_store.objectives_initial_state = RS_OBJECTIVES_INITIAL_STATE.new()
	add_child(_store)
	autofree(_store)
	await _pump_frames(3)

func after_each() -> void:
	U_ServiceLocator.clear()
	_store = null

func _create_controller(visibility_objective_id: StringName = StringName("")) -> Inter_VictoryZone:
	var controller := Inter_VictoryZone.new()
	controller.component_factory = Callable(self, "_create_victory_stub")
	var config := RS_VICTORY_INTERACTION_CONFIG.new()
	config.objective_id = StringName("objective_test")
	config.visibility_objective_id = visibility_objective_id
	config.area_id = "area_test"
	config.victory_type = C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE
	config.trigger_once = false
	controller.config = config
	add_child(controller)
	autofree(controller)
	await _pump_frames(4)
	return controller

func _create_victory_stub() -> TestVictoryComponent:
	return TestVictoryComponent.new()

func _dispatch_objective_action(action: Dictionary) -> void:
	action["immediate"] = true
	_store.dispatch(action)

func test_victory_component_configured() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller) as TestVictoryComponent
	assert_not_null(component, "Victory controller should create component.")

	assert_eq(component.objective_id, StringName("objective_test"))
	assert_eq(component.area_id, "area_test")
	assert_eq(component.victory_type, C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE)
	assert_false(component.trigger_once, "Trigger once flag should reflect controller export.")
	assert_true(component.resolve_called, "Component should resolve area using controller volume.")

	var area := controller.get_trigger_area()
	assert_not_null(area)
	assert_true(component.get_trigger_area() == area, "Component should reuse controller area.")

func test_config_resource_overrides_export_values() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)
	assert_not_null(component, "Victory component should exist before config assignment.")

	var config := RS_VICTORY_INTERACTION_CONFIG.new()
	config.objective_id = StringName("objective_cfg")
	config.area_id = "area_cfg"
	config.victory_type = C_VictoryTriggerComponent.VictoryType.LEVEL_COMPLETE
	config.trigger_once = true
	var trigger_settings := RS_SCENE_TRIGGER_SETTINGS.new()
	trigger_settings.ignore_initial_overlap = true
	config.trigger_settings = trigger_settings

	controller.config = config
	await _pump_frames(1)

	assert_eq(component.objective_id, StringName("objective_cfg"))
	assert_eq(component.area_id, "area_cfg")
	assert_eq(component.victory_type, C_VictoryTriggerComponent.VictoryType.LEVEL_COMPLETE)
	assert_true(component.trigger_once)
	assert_true(controller.settings == trigger_settings, "Victory should use config trigger settings when provided.")
	assert_false(trigger_settings.ignore_initial_overlap, "Victory should force passive overlap semantics.")

func test_non_matching_config_does_not_override_valid_config() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)
	assert_not_null(component, "Victory component should exist before config type mismatch check.")

	var wrong_config := RS_HAZARD_INTERACTION_CONFIG.new()
	controller.config = wrong_config
	await _pump_frames(1)

	assert_eq(component.objective_id, StringName("objective_test"))
	assert_eq(component.area_id, "area_test")
	assert_eq(component.victory_type, C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE)
	assert_false(component.trigger_once)

func test_visibility_objective_gate_requires_active_status() -> void:
	var controller := await _create_controller(StringName("bar_complete"))

	assert_false(controller.is_enabled(), "Objective-gated victory zone should be locked while objective is inactive.")
	assert_false(controller.visible, "Objective-gated victory zone should hide visuals while objective is inactive.")

	_dispatch_objective_action(U_OBJECTIVES_ACTIONS.activate(StringName("bar_complete")))
	await _pump_frames(2)
	assert_true(controller.is_enabled(), "Objective-gated victory zone should unlock while objective is active.")
	assert_true(controller.visible, "Objective-gated victory zone should show visuals while objective is active.")

	_dispatch_objective_action(U_OBJECTIVES_ACTIONS.complete(StringName("bar_complete")))
	await _pump_frames(2)
	assert_false(controller.is_enabled(), "Objective-gated victory zone should lock once objective is completed.")
	assert_false(controller.visible, "Objective-gated victory zone should hide once objective is completed.")

func _find_component(controller: Node) -> C_VictoryTriggerComponent:
	for child in controller.get_children():
		if child is C_VictoryTriggerComponent:
			return child as C_VictoryTriggerComponent
	return null
