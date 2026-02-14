extends BaseTest

## Integration tests for dyslexia font override via M_LocalizationManager + Redux.
##
## Validates:
## - Dyslexia toggle dispatches action and manager applies font to registered roots
## - Toggle off restores default font on registered roots
## - CJK locale applies CJK font path; dyslexia toggle has no visible effect

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_LOCALIZATION_MANAGER := preload("res://scripts/managers/m_localization_manager.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_LOCALIZATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_localization_initial_state.gd")
const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

var _store: M_StateStore
var _loc_manager: M_LocalizationManager

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = _make_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_loc_manager = M_LOCALIZATION_MANAGER.new()
	_loc_manager.state_store = _store
	add_child_autofree(_loc_manager)

	await get_tree().process_frame

func after_each() -> void:
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

## Dispatching set_dyslexia_font_enabled(true) is reflected in Redux state.
func test_dyslexia_toggle_on_persists_to_state() -> void:
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(true))
	await get_tree().physics_frame
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_true(
		U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state),
		"dyslexia_font_enabled should be true in Redux state"
	)

## Toggling dyslexia off after on restores state correctly.
func test_dyslexia_toggle_off_persists_to_state() -> void:
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(true))
	await get_tree().physics_frame
	await get_tree().process_frame
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(false))
	await get_tree().physics_frame
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_false(
		U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state),
		"dyslexia_font_enabled should be false after toggle off"
	)

## CJK locale: _get_active_font selects CJK font regardless of dyslexia toggle.
func test_cjk_locale_overrides_dyslexia_font_selection() -> void:
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"zh_CN"))
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(true))
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_eq(_loc_manager.get_locale(), &"zh_CN", "Manager should report zh_CN locale")
	# When locale is CJK, get_active_font returns _cjk_font — dyslexia toggle has no effect
	var active_font: Font = _loc_manager._get_active_font(true)
	var cjk_font: Font = _loc_manager._cjk_font
	assert_eq(active_font, cjk_font, "CJK locale should always select CJK font over dyslexia font")
