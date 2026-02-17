extends BaseTest

## Integration tests for locale switching via M_LocalizationManager + Redux.
##
## Validates:
## - Dispatching set_locale updates manager's active locale
## - U_LocalizationUtils.localize() returns correct translation for active locale
## - CJK locale auto-sets ui_scale_override to 1.1 in Redux state
## - Missing keys fall back to key string (no crash)
## - Signpost key resolves through localize() before HUD display

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_LOCALIZATION_MANAGER := preload("res://scripts/managers/m_localization_manager.gd")
const M_DISPLAY_MANAGER := preload("res://scripts/managers/m_display_manager.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_LOCALIZATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_localization_initial_state.gd")
const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/utils/localization/u_localization_utils.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

var _store: M_StateStore
var _loc_manager: M_LocalizationManager
var _display_manager: M_DisplayManager

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = _make_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	var game_viewport := SubViewport.new()
	game_viewport.name = "GameViewport"
	add_child_autofree(game_viewport)

	_loc_manager = M_LOCALIZATION_MANAGER.new()
	_loc_manager.state_store = _store
	add_child_autofree(_loc_manager)

	_display_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_display_manager)

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

## Dispatching set_locale updates the manager and localize() returns correct translation.
func test_locale_switch_updates_localize_result() -> void:
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"es"))
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_eq(_loc_manager.get_locale(), &"es", "Manager active locale should switch to es")
	var state: Dictionary = _store.get_state()
	assert_eq(U_LOCALIZATION_SELECTORS.get_locale(state), &"es", "Redux state locale should be es")

	# Verify localize() returns actual Spanish translation
	var result: String = U_LOCALIZATION_UTILS.localize(&"menu.main.title")
	assert_eq(result, "Menú Principal", "localize() should return Spanish translation after locale switch")

## CJK locale dispatches auto-sets ui_scale_override to 1.1 via reducer.
func test_cjk_locale_sets_ui_scale_override() -> void:
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"zh_CN"))
	await get_tree().physics_frame
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_almost_eq(
		U_LOCALIZATION_SELECTORS.get_ui_scale_override(state),
		1.1,
		0.001,
		"CJK locale should auto-set ui_scale_override to 1.1"
	)

## Japanese locale also sets ui_scale_override to 1.1.
func test_ja_locale_sets_ui_scale_override() -> void:
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"ja"))
	await get_tree().physics_frame
	await get_tree().process_frame

	var state: Dictionary = _store.get_state()
	assert_almost_eq(
		U_LOCALIZATION_SELECTORS.get_ui_scale_override(state),
		1.1,
		0.001,
		"Japanese locale should auto-set ui_scale_override to 1.1"
	)

## Locale-driven CJK scaling is applied by DisplayManager without dispatching display actions.
func test_cjk_locale_updates_display_scale_without_display_dispatch() -> void:
	var display_dispatch_count: int = 0
	if _store.has_signal("action_dispatched"):
		_store.action_dispatched.connect(func(action: Dictionary) -> void:
			var action_type := String(action.get("type", ""))
			if action_type.begins_with("display/"):
				display_dispatch_count += 1
		)

	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	root.add_child(label)
	_display_manager.register_ui_scale_root(root)

	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"zh_CN"))
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_eq(label.get_theme_font_size("font_size"), 22, "CJK locale should apply effective 1.1 UI scale through DisplayManager")
	assert_eq(display_dispatch_count, 0, "Locale switching should not dispatch display/* actions")

## Missing translation key returns the key string unchanged — no crash.
func test_missing_key_returns_key_string() -> void:
	var result := U_LOCALIZATION_UTILS.localize(&"missing.key.that.does.not.exist")
	assert_eq(result, "missing.key.that.does.not.exist", "Missing key should return key string unchanged")
