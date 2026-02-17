extends BaseTest

## Integration tests for UI_LocalizationSettingsTab preview + apply/cancel/confirm flow.

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_LOCALIZATION_MANAGER := preload("res://scripts/managers/m_localization_manager.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_LOCALIZATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_localization_initial_state.gd")
const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

const LOCALIZATION_SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn")

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

func _instantiate_overlay() -> UI_LocalizationSettingsOverlay:
	var overlay := LOCALIZATION_SETTINGS_OVERLAY_SCENE.instantiate() as UI_LocalizationSettingsOverlay
	add_child_autofree(overlay)
	await _await_overlay_ready(overlay)
	return overlay

func _await_overlay_ready(overlay: UI_LocalizationSettingsOverlay, max_frames: int = 30) -> void:
	for _i in range(max_frames):
		await get_tree().process_frame
		var tab := _get_tab(overlay)
		if overlay != null and overlay.get_store() != null and tab != null and tab._state_store != null:
			return

func _get_tab(overlay: Node) -> UI_LocalizationSettingsTab:
	return overlay.get_node_or_null("CenterContainer/Panel/VBox/LocalizationSettingsTab") as UI_LocalizationSettingsTab

func _collect_localization_action_types(actions: Array[Dictionary]) -> Array[StringName]:
	var types: Array[StringName] = []
	for action: Dictionary in actions:
		var action_type: Variant = action.get("type", StringName(""))
		if action_type is StringName and String(action_type).begins_with("localization/"):
			types.append(action_type)
	return types

func test_preview_updates_manager_without_dispatch_until_apply() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._dyslexia_toggle.button_pressed = true
	await get_tree().process_frame

	assert_true(_loc_manager.is_preview_active(), "Editing should enable localization preview mode")
	var state: Dictionary = _store.get_state()
	assert_false(U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state), "State should not update until Apply")
	assert_eq(
		_collect_localization_action_types(dispatched).size(),
		0,
		"Preview edits should not dispatch localization actions"
	)

func test_apply_same_locale_dispatches_and_clears_preview() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._dyslexia_toggle.button_pressed = true
	await get_tree().process_frame
	assert_true(_loc_manager.is_preview_active(), "Preview should be active after local edit")

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_false(_loc_manager.is_preview_active(), "Apply should clear preview mode")
	var state: Dictionary = _store.get_state()
	assert_true(U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state), "Apply should persist dyslexia toggle")
	assert_false(tab._language_confirm_active, "Applying same locale should not enter confirm flow")
	assert_eq(
		_collect_localization_action_types(dispatched).size(),
		2,
		"Apply should dispatch locale and dyslexia actions"
	)

func test_cancel_discards_changes_and_clears_preview() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._dyslexia_toggle.button_pressed = true
	await get_tree().process_frame
	assert_true(_loc_manager.is_preview_active(), "Preview should be active after local edit")

	tab._cancel_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_false(_loc_manager.is_preview_active(), "Cancel should clear preview mode")
	var state: Dictionary = _store.get_state()
	assert_false(U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state), "Cancel should not persist dyslexia toggle")
	assert_eq(
		_collect_localization_action_types(dispatched).size(),
		0,
		"Cancel should not dispatch localization actions"
	)

func test_reset_restores_defaults_and_persists_immediately() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"ja"))
	_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(true))
	await get_tree().physics_frame
	await get_tree().process_frame

	var dispatched: Array[Dictionary] = []
	_store.action_dispatched.connect(func(action: Dictionary) -> void:
		dispatched.append(action)
	)

	tab._reset_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_false(_loc_manager.is_preview_active(), "Reset should clear preview mode")
	var state: Dictionary = _store.get_state()
	assert_eq(U_LOCALIZATION_SELECTORS.get_locale(state), &"en", "Reset should restore default locale")
	assert_false(
		U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state),
		"Reset should restore default dyslexia toggle"
	)
	assert_eq(
		_collect_localization_action_types(dispatched).size(),
		2,
		"Reset should dispatch locale and dyslexia actions"
	)

func test_apply_locale_change_requires_confirm_and_keep_persists_selection() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	var es_index: int = tab.SUPPORTED_LOCALES.find(&"es")
	assert_true(es_index >= 0, "Spanish locale option should exist")
	tab._language_option.select(es_index)
	tab._language_option.emit_signal("item_selected", es_index)
	await get_tree().process_frame

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_true(tab._language_confirm_active, "Locale changes should activate confirm dialog flow")
	assert_true(tab._language_confirm_dialog.visible, "Confirm dialog should be visible after locale change apply")
	assert_eq(
		tab._language_confirm_dialog.title,
		"Confirmar Cambio de Idioma",
		"Confirm dialog title should localize to pending locale"
	)
	var ok_button := tab._get_language_confirm_ok_button()
	var cancel_button := tab._get_language_confirm_cancel_button()
	assert_not_null(ok_button, "Confirm dialog should expose an OK button")
	assert_not_null(cancel_button, "Confirm dialog should expose a Cancel button")
	assert_eq(ok_button.text, "Mantener", "Confirm OK button should localize to pending locale")
	assert_eq(cancel_button.text, "Revertir", "Confirm cancel button should localize to pending locale")
	assert_true(
		tab._language_confirm_dialog.dialog_text.find("Mantener este idioma") >= 0,
		"Confirm dialog body text should localize to pending locale"
	)
	assert_eq(
		U_LOCALIZATION_SELECTORS.get_locale(_store.get_state()),
		&"es",
		"Pending locale should be applied before confirmation countdown"
	)

	tab._language_confirm_dialog.emit_signal("confirmed")
	await get_tree().process_frame

	assert_false(tab._language_confirm_active, "Keep should finalize confirm flow")
	assert_false(_loc_manager.is_preview_active(), "Keep should clear preview mode")
	assert_eq(
		U_LOCALIZATION_SELECTORS.get_locale(_store.get_state()),
		&"es",
		"Keep should preserve the newly selected locale"
	)

func test_language_confirm_cancel_reverts_to_previous_locale_and_dyslexia() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	tab._dyslexia_toggle.button_pressed = true
	await get_tree().process_frame

	var es_index: int = tab.SUPPORTED_LOCALES.find(&"es")
	assert_true(es_index >= 0, "Spanish locale option should exist")
	tab._language_option.select(es_index)
	tab._language_option.emit_signal("item_selected", es_index)
	await get_tree().process_frame

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame
	assert_true(tab._language_confirm_active, "Confirm flow should start for locale changes")
	assert_eq(U_LOCALIZATION_SELECTORS.get_locale(_store.get_state()), &"es", "Pending locale should be active")

	tab._language_confirm_dialog.emit_signal("canceled")
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_false(tab._language_confirm_active, "Cancel should finalize confirm flow")
	assert_false(_loc_manager.is_preview_active(), "Cancel should clear preview mode")
	assert_eq(
		U_LOCALIZATION_SELECTORS.get_locale(_store.get_state()),
		&"en",
		"Cancel should revert locale to pre-change value"
	)
	assert_false(
		U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(_store.get_state()),
		"Cancel should revert dyslexia setting to pre-change value"
	)

func test_language_confirm_timer_reverts_to_previous_locale_and_dyslexia() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	tab._dyslexia_toggle.button_pressed = true
	await get_tree().process_frame

	var pt_index: int = tab.SUPPORTED_LOCALES.find(&"pt")
	assert_true(pt_index >= 0, "Portuguese locale option should exist")
	tab._language_option.select(pt_index)
	tab._language_option.emit_signal("item_selected", pt_index)
	await get_tree().process_frame

	tab._apply_button.emit_signal("pressed")
	await get_tree().process_frame
	assert_true(tab._language_confirm_active, "Confirm flow should start for locale changes")
	assert_eq(U_LOCALIZATION_SELECTORS.get_locale(_store.get_state()), &"pt", "Pending locale should be active")

	tab._language_confirm_seconds_left = 1
	tab._on_language_confirm_timer_timeout()
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_false(tab._language_confirm_active, "Timer expiry should finalize confirm flow")
	assert_false(_loc_manager.is_preview_active(), "Timer revert should clear preview mode")
	assert_eq(
		U_LOCALIZATION_SELECTORS.get_locale(_store.get_state()),
		&"en",
		"Timer expiry should revert locale to pre-change value"
	)
	assert_false(
		U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(_store.get_state()),
		"Timer expiry should revert dyslexia setting to pre-change value"
	)

func test_state_changes_refresh_ui_when_not_editing() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"pt"))
	await get_tree().physics_frame
	await get_tree().process_frame

	var pt_index: int = tab.SUPPORTED_LOCALES.find(&"pt")
	assert_eq(tab._language_option.selected, pt_index, "Language option should update from store state")

func test_state_changes_do_not_override_local_edits() -> void:
	var overlay := await _instantiate_overlay()
	var tab := _get_tab(overlay)
	assert_not_null(tab, "LocalizationSettingsTab should exist")

	var es_index: int = tab.SUPPORTED_LOCALES.find(&"es")
	assert_true(es_index >= 0, "Spanish locale option should exist")
	tab._language_option.select(es_index)
	tab._language_option.emit_signal("item_selected", es_index)
	await get_tree().process_frame

	_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(&"pt"))
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_eq(
		tab._language_option.selected,
		es_index,
		"Store updates should not override unsaved local edits"
	)
