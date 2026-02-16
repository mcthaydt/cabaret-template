extends GutTest

## Test suite for M_LocalizationManager lifecycle (Phase 1B)

const M_LOCALIZATION_MANAGER := preload("res://scripts/managers/m_localization_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const I_LOCALIZATION_MANAGER := preload("res://scripts/interfaces/i_localization_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _manager: Node
var _store: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_manager = null
	_store = null

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_manager = null
	_store = null

func test_manager_extends_i_localization_manager() -> void:
	_manager = M_LOCALIZATION_MANAGER.new()
	add_child_autofree(_manager)

	assert_true(_manager is I_LOCALIZATION_MANAGER, "M_LocalizationManager should extend I_LocalizationManager")

func test_manager_exposes_supported_locales() -> void:
	_manager = M_LOCALIZATION_MANAGER.new()
	add_child_autofree(_manager)

	var locales: Array[StringName] = _manager.get_supported_locales()
	assert_eq(locales, [&"en", &"es", &"pt", &"zh_CN", &"ja"], "Supported locales should match contract")

func test_manager_registers_with_service_locator() -> void:
	_manager = M_LOCALIZATION_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var service := U_SERVICE_LOCATOR.try_get_service(StringName("localization_manager"))
	assert_not_null(service, "Localization manager should register with ServiceLocator")
	assert_eq(service, _manager, "ServiceLocator should return the localization manager instance")

func test_manager_discovers_state_store() -> void:
	await _setup_manager_with_store({})

	var resolved_store: Node = _manager.get("_resolved_store") as Node
	assert_eq(resolved_store, _store, "Manager should discover StateStore via ServiceLocator")

func test_manager_subscribes_to_slice_updated() -> void:
	await _setup_manager_with_store({})

	var handler := Callable(_manager, "_on_slice_updated")
	assert_true(_store.slice_updated.is_connected(handler), "Manager should connect to StateStore slice_updated signal")

func test_settings_applied_on_ready() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	assert_eq(int(_manager.get("_apply_count")), 1, "Manager should apply localization settings on ready")

func test_hash_prevents_redundant_applies() -> void:
	var loc_state := {"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false}
	await _setup_manager_with_store(loc_state)

	var apply_count := int(_manager.get("_apply_count"))
	# Emit slice_updated with same content - hash should prevent re-apply
	_store.slice_updated.emit(StringName("localization"), loc_state)

	assert_eq(int(_manager.get("_apply_count")), apply_count, "Hash should prevent redundant apply calls")

func test_get_effective_settings_reflects_store_state() -> void:
	await _setup_manager_with_store({"current_locale": &"es", "dyslexia_font_enabled": true, "ui_scale_override": 1.1, "has_selected_language": false})

	var effective: Dictionary = _manager.get_effective_settings()
	assert_eq(effective.get("current_locale", &""), &"es", "Effective locale should reflect store state")
	assert_true(bool(effective.get("dyslexia_font_enabled", false)), "Effective dyslexia flag should reflect store state")
	assert_eq(float(effective.get("ui_scale_override", 0.0)), 1.1, "Effective UI scale should reflect store state")

func test_preview_state_flag_updates() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	assert_false(_manager.is_preview_active(), "Preview should start inactive")
	_manager.set_localization_preview({"locale": &"es", "dyslexia_font_enabled": false})
	assert_true(_manager.is_preview_active(), "Preview should be active after set_localization_preview")
	_manager.clear_localization_preview()
	assert_false(_manager.is_preview_active(), "Preview should be inactive after clear")

func test_preview_ignores_store_updates() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	_manager.set_localization_preview({"locale": &"es", "dyslexia_font_enabled": false})
	_store.set_slice(StringName("localization"), {"current_locale": &"ja", "dyslexia_font_enabled": false, "ui_scale_override": 1.1, "has_selected_language": false})
	_store.slice_updated.emit(StringName("localization"), {"current_locale": &"ja", "dyslexia_font_enabled": false, "ui_scale_override": 1.1, "has_selected_language": false})

	assert_eq(_manager.get_locale(), &"es", "Store updates should be ignored while preview is active")

func test_locale_changed_signal_emits_on_locale_change() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	var seen: Array[StringName] = []
	if _manager.has_signal("locale_changed"):
		_manager.locale_changed.connect(func(locale: StringName) -> void:
			seen.append(locale)
		)

	_store.set_slice(StringName("localization"), {"current_locale": &"es", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})
	_store.slice_updated.emit(StringName("localization"), {"current_locale": &"es", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	assert_eq(seen.size(), 1, "locale_changed should emit once on locale change")
	if not seen.is_empty():
		assert_eq(seen[0], &"es", "locale_changed should emit the new locale")

# --- Phase 3: Font + UI Root Registration Tests ---

func test_register_ui_root_adds_to_list() -> void:
	_manager = M_LOCALIZATION_MANAGER.new()
	add_child_autofree(_manager)

	var root := Control.new()
	add_child_autofree(root)
	_manager.register_ui_root(root)

	var ui_roots: Array = _manager.get("_ui_roots")
	assert_true(root in ui_roots, "register_ui_root should add root to internal list")

func test_unregister_ui_root_removes_from_list() -> void:
	_manager = M_LOCALIZATION_MANAGER.new()
	add_child_autofree(_manager)

	var root := Control.new()
	add_child_autofree(root)
	_manager.register_ui_root(root)
	_manager.unregister_ui_root(root)

	var ui_roots: Array = _manager.get("_ui_roots")
	assert_false(root in ui_roots, "unregister_ui_root should remove root from internal list")

func test_font_override_applied_on_register() -> void:
	_manager = M_LOCALIZATION_MANAGER.new()
	add_child_autofree(_manager)

	var root := Control.new()
	add_child_autofree(root)
	_manager.register_ui_root(root)

	# Default font should be applied immediately on register (if font loaded)
	var default_font: Font = _manager.get("_default_font")
	if default_font != null:
		var applied_font: Font = root.get_theme_font(&"font")
		assert_eq(applied_font, default_font, "register_ui_root should immediately apply current font")
	else:
		pass_test("Font not loaded in test environment — skipping font application check")

func test_dyslexia_font_applied_to_all_roots() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	var root := Control.new()
	add_child_autofree(root)
	_manager.register_ui_root(root)

	# Simulate dyslexia toggle
	_store.set_slice(StringName("localization"), {"current_locale": &"en", "dyslexia_font_enabled": true, "ui_scale_override": 1.0, "has_selected_language": false})
	_store.slice_updated.emit(StringName("localization"), {"current_locale": &"en", "dyslexia_font_enabled": true, "ui_scale_override": 1.0, "has_selected_language": false})

	var dyslexia_font: Font = _manager.get("_dyslexia_font")
	if dyslexia_font != null:
		var applied_font: Font = root.get_theme_font(&"font")
		assert_eq(applied_font, dyslexia_font, "Dyslexia font should be applied to all registered roots")
	else:
		pass_test("Font not loaded in test environment — skipping dyslexia font check")

func test_cjk_locale_overrides_dyslexia_toggle() -> void:
	await _setup_manager_with_store({"current_locale": &"ja", "dyslexia_font_enabled": true, "ui_scale_override": 1.1, "has_selected_language": false})

	var root := Control.new()
	add_child_autofree(root)
	_manager.register_ui_root(root)

	var cjk_font: Font = _manager.get("_cjk_font")
	if cjk_font != null:
		var applied_font: Font = root.get_theme_font(&"font")
		assert_eq(applied_font, cjk_font, "CJK locale should override dyslexia toggle and use CJK font")
	else:
		pass_test("Font not loaded in test environment — skipping CJK font check")

func test_register_root_while_dyslexia_active_applies_dyslexia_font() -> void:
	# Dyslexia is ALREADY enabled before the root registers.
	# The newly-registered root must receive the dyslexia font immediately,
	# not the default font.
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": true, "ui_scale_override": 1.0, "has_selected_language": false})

	var root := Control.new()
	add_child_autofree(root)
	_manager.register_ui_root(root)

	var dyslexia_font: Font = _manager.get("_dyslexia_font")
	if dyslexia_font != null:
		var applied_font: Font = root.get_theme_font(&"font")
		assert_eq(applied_font, dyslexia_font, "register_ui_root should apply dyslexia font when dyslexia is already active")
	else:
		pass_test("Font not loaded in test environment — skipping dyslexia font check")

func test_interface_declares_translate_method() -> void:
	# I_LocalizationManager must declare translate() so typed interface
	# variables can call it without casting to the concrete class.
	var iface: I_LocalizationManager = I_LOCALIZATION_MANAGER.new()
	add_child_autofree(iface)
	assert_true(iface.has_method("translate"), "I_LocalizationManager interface must declare translate()")

func test_interface_declares_contract_methods() -> void:
	var iface: I_LocalizationManager = I_LOCALIZATION_MANAGER.new()
	add_child_autofree(iface)
	assert_true(iface.has_method("get_supported_locales"), "Interface must declare get_supported_locales()")
	assert_true(iface.has_method("get_effective_settings"), "Interface must declare get_effective_settings()")
	assert_true(iface.has_method("is_preview_active"), "Interface must declare is_preview_active()")

func test_switching_from_cjk_to_latin_restores_default_font() -> void:
	await _setup_manager_with_store({"current_locale": &"ja", "dyslexia_font_enabled": false, "ui_scale_override": 1.1, "has_selected_language": false})

	var root := Control.new()
	add_child_autofree(root)
	_manager.register_ui_root(root)

	# Switch to English (Latin)
	_store.set_slice(StringName("localization"), {"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})
	_store.slice_updated.emit(StringName("localization"), {"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	var default_font: Font = _manager.get("_default_font")
	if default_font != null:
		var applied_font: Font = root.get_theme_font(&"font")
		assert_eq(applied_font, default_font, "Switching from CJK to Latin should restore default font")
	else:
		pass_test("Font not loaded in test environment — skipping restore font check")

# --- Phase 7: Theme cascade + preview mode tests ---

func test_theme_cascade_to_nested_label() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	var root := Control.new()
	add_child_autofree(root)

	var nested_label := Label.new()
	root.add_child(nested_label)

	_manager.register_ui_root(root)

	var default_font: Font = _manager.get("_default_font")
	if default_font != null:
		# Nested Label should inherit font from parent's Theme
		var label_font: Font = nested_label.get_theme_font(&"font", &"Label")
		assert_eq(label_font, default_font, "Nested Label should inherit font from parent Theme")
	else:
		pass_test("Font not loaded in test environment — skipping cascade check")

func test_preview_mode_applies_without_dispatch() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	_manager.set_localization_preview({"locale": &"es", "dyslexia_font_enabled": false})

	# Preview should change the active locale on the manager without dispatching to store
	assert_eq(_manager.get_locale(), &"es", "Preview should change manager locale")
	# Store should still have original locale
	var state: Dictionary = _store.get_state()
	var store_locale: StringName = state.get("localization", {}).get("current_locale", &"")
	assert_eq(store_locale, &"en", "Store locale should remain unchanged during preview")

func test_clear_preview_reverts_to_store_state() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	_manager.set_localization_preview({"locale": &"es", "dyslexia_font_enabled": false})
	_manager.clear_localization_preview()

	assert_eq(_manager.get_locale(), &"en", "Clearing preview should revert to store locale")

func test_translate_returns_populated_translation() -> void:
	await _setup_manager_with_store({"current_locale": &"en", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	var result: String = _manager.translate(&"menu.main.title")
	assert_eq(result, "Main Menu", "translate() should return populated English translation")

func test_translate_spanish_locale() -> void:
	await _setup_manager_with_store({"current_locale": &"es", "dyslexia_font_enabled": false, "ui_scale_override": 1.0, "has_selected_language": false})

	var result: String = _manager.translate(&"menu.main.title")
	assert_eq(result, "Menú Principal", "translate() should return Spanish translation for es locale")

# --- Helpers ---

func _setup_manager_with_store(localization_state: Dictionary) -> void:
	_store = MOCK_STATE_STORE.new()
	add_child_autofree(_store)
	_store.set_slice(StringName("localization"), localization_state)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_manager = M_LOCALIZATION_MANAGER.new()
	_manager.set("state_store", _store)
	add_child_autofree(_manager)
	await get_tree().process_frame
