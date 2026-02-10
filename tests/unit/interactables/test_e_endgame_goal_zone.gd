extends BaseTest

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const RS_ENDGAME_GOAL_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_endgame_goal_interaction_config.gd")
const RS_VICTORY_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_victory_interaction_config.gd")

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
	add_child(_store)
	autofree(_store)
	await _pump_frames(3)

func after_each() -> void:
	U_ServiceLocator.clear()
	_store = null

func _create_controller(config: Resource) -> Inter_EndgameGoalZone:
	var controller := Inter_EndgameGoalZone.new()
	controller.config = config
	add_child(controller)
	autofree(controller)
	await _pump_frames(4)
	return controller

func _dispatch_mark_area_complete(area_id: String) -> void:
	var action := U_GAMEPLAY_ACTIONS.mark_area_complete(area_id)
	action["immediate"] = true
	_store.dispatch(action)

func test_endgame_goal_prefers_required_area_from_endgame_config() -> void:
	var config := RS_ENDGAME_GOAL_INTERACTION_CONFIG.new()
	config.required_area = "area_cfg"
	var controller := await _create_controller(config)

	assert_false(controller.is_enabled(), "Goal should start locked when required area is incomplete.")
	assert_false(controller.visible, "Locked goal should start hidden.")

	_dispatch_mark_area_complete("area_export")
	await _pump_frames(2)
	assert_false(controller.is_enabled(), "Non-config areas should not unlock the goal.")
	assert_false(controller.visible)

	_dispatch_mark_area_complete("area_cfg")
	await _pump_frames(2)
	assert_true(controller.is_enabled(), "Config required area should unlock goal once completed.")
	assert_true(controller.visible)

func test_non_matching_config_does_not_override_valid_endgame_config() -> void:
	var config := RS_ENDGAME_GOAL_INTERACTION_CONFIG.new()
	config.required_area = "area_cfg"
	var controller := await _create_controller(config)

	var wrong_config := RS_VICTORY_INTERACTION_CONFIG.new()
	controller.config = wrong_config
	await _pump_frames(1)

	var required_area := String(controller.call("_get_effective_required_area"))
	assert_eq(required_area, "area_cfg", "Incompatible config assignment should not replace endgame required_area.")

	_dispatch_mark_area_complete("area_cfg")
	await _pump_frames(2)
	assert_true(controller.is_enabled(), "Original endgame config should continue to control unlock gating.")
	assert_true(controller.visible)
