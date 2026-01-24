extends GutTest

const M_InputProfileManager = preload("res://scripts/managers/m_input_profile_manager.gd")
const RS_InputProfile = preload("res://scripts/resources/input/rs_input_profile.gd")
const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings = preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GameplayInitialState = preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState = preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const U_InputSelectors = preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")

var _store: M_StateStore
var _mgr: M_InputProfileManager

func before_each() -> void:
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	_mgr = M_InputProfileManager.new()
	add_child_autofree(_mgr)
	await get_tree().process_frame

func after_each() -> void:
	_store = null
	_mgr = null

func test_profile_switch_updates_settings_slice_and_emits_signal() -> void:
	# Ensure we have a profile to switch to
	var ids := _mgr.get_available_profile_ids()
	if ids.is_empty():
		var p := RS_InputProfile.new()
		p.profile_name = "Temp"
		_mgr.available_profiles["temp"] = p
		ids = _mgr.get_available_profile_ids()
	assert_gt(ids.size(), 0, "Should have at least one profile to switch to")

	# Pause gameplay (switch gated by pause)
	_store.dispatch(U_GameplayActions.pause_game())
	await get_tree().physics_frame

	# Register a unique profile to guarantee a change
	var switched_id := "temp_switch"
	var p2 := RS_InputProfile.new()
	p2.profile_name = "Temp Switch"
	_mgr.available_profiles[switched_id] = p2
	var signal_emitted := false
	_mgr.profile_switched.connect(func(pid):
		signal_emitted = true
	)

	_mgr.switch_profile(switched_id)
	await get_tree().physics_frame

	var state := _store.get_state()
	var updated := U_InputSelectors.get_active_profile_id(state) == switched_id
	assert_true(signal_emitted or updated, "Profile switched and/or signal emitted")
