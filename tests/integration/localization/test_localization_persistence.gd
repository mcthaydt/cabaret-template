extends BaseTest

## Integration tests for localization settings persistence.
##
## Validates:
## - Dispatch locale action → save → reload → correct locale restored
## - Dispatch dyslexia action → save → reload → dyslexia state restored
## - is_global_settings_action() returns true for all localization/ actions

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_LOCALIZATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_localization_initial_state.gd")
const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")
const U_GLOBAL_SETTINGS_SERIALIZATION := preload("res://scripts/utils/u_global_settings_serialization.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

const TEST_SAVE_PATH := "user://test_localization_persistence.json"

var _store: M_StateStore

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = _make_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)
	await get_tree().process_frame

	_remove_test_file()

func after_each() -> void:
	_remove_test_file()
	U_STATE_HANDOFF.clear_all()
	super.after_each()

func _make_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.localization_initial_state = RS_LOCALIZATION_INITIAL_STATE.new()
	return store

func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

## Dispatch locale → save → reload → correct locale restored.
func test_locale_persists_across_save_reload() -> void:
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"es"))
	await get_tree().physics_frame
	await get_tree().process_frame

	var save_err := _store.save_state(TEST_SAVE_PATH)
	assert_eq(save_err, OK, "save_state should succeed")

	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"en"))
	await get_tree().physics_frame
	await get_tree().process_frame

	var load_err := _store.load_state(TEST_SAVE_PATH)
	assert_eq(load_err, OK, "load_state should succeed")

	var state: Dictionary = _store.get_state()
	assert_eq(
		U_LOCALIZATION_SELECTORS.get_locale(state),
		&"es",
		"Locale should be restored to es after load"
	)

## Dispatch dyslexia → save → reload → dyslexia state restored.
func test_dyslexia_persists_across_save_reload() -> void:
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(true))
	await get_tree().physics_frame
	await get_tree().process_frame

	var save_err := _store.save_state(TEST_SAVE_PATH)
	assert_eq(save_err, OK, "save_state should succeed")

	_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(false))
	await get_tree().physics_frame
	await get_tree().process_frame

	var load_err := _store.load_state(TEST_SAVE_PATH)
	assert_eq(load_err, OK, "load_state should succeed")

	var state: Dictionary = _store.get_state()
	assert_true(
		U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state),
		"Dyslexia setting should be restored to true after load"
	)

## is_global_settings_action() returns true for all localization/ action types.
func test_is_global_settings_action_recognizes_localization_prefix() -> void:
	assert_true(
		U_GLOBAL_SETTINGS_SERIALIZATION.is_global_settings_action(
			U_LOCALIZATION_ACTIONS.ACTION_SET_LOCALE
		),
		"set_locale should be a global settings action"
	)
	assert_true(
		U_GLOBAL_SETTINGS_SERIALIZATION.is_global_settings_action(
			U_LOCALIZATION_ACTIONS.ACTION_SET_DYSLEXIA_FONT_ENABLED
		),
		"set_dyslexia_font_enabled should be a global settings action"
	)
	assert_true(
		U_GLOBAL_SETTINGS_SERIALIZATION.is_global_settings_action(
			U_LOCALIZATION_ACTIONS.ACTION_SET_UI_SCALE_OVERRIDE
		),
		"set_ui_scale_override should be a global settings action"
	)
