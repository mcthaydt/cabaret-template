extends GutTest

## Tests for U_LocalizationUtils static helper (Phase 2B)
## NOTE: U_LocalizationUtils.localize() is called via class name (not preloaded const) to avoid
## a Godot 4.6 parse error where calling .tr() on a Script variable collides with Object.tr().

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

func test_tr_returns_key_when_manager_unavailable() -> void:
	# No manager registered — should fall back to key string
	var result: String = U_LocalizationUtils.localize(&"some.key")
	assert_eq(result, "some.key", "localize() should return key string when manager unavailable")

func test_tr_returns_translated_string() -> void:
	var mock_mgr := MockLocalizationManager.new()
	mock_mgr.add_translation(&"hello", "Hello World")
	add_child_autofree(mock_mgr)
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), mock_mgr)

	var result: String = U_LocalizationUtils.localize(&"hello")
	assert_eq(result, "Hello World", "localize() should return translated string when manager available")

func test_tr_returns_key_on_missing_key() -> void:
	var mock_mgr := MockLocalizationManager.new()
	add_child_autofree(mock_mgr)
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), mock_mgr)

	var result: String = U_LocalizationUtils.localize(&"missing.key")
	assert_eq(result, "missing.key", "localize() should return key string when key missing from translations")

func test_tr_fmt_substitutes_positional_args() -> void:
	var mock_mgr := MockLocalizationManager.new()
	mock_mgr.add_translation(&"greeting", "Hello {0}, you have {1} messages")
	add_child_autofree(mock_mgr)
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), mock_mgr)

	var result: String = U_LocalizationUtils.localize_fmt(&"greeting", ["Alice", 5])
	assert_eq(result, "Hello Alice, you have 5 messages", "localize_fmt() should substitute positional args")

func test_tr_fmt_handles_missing_args_gracefully() -> void:
	var mock_mgr := MockLocalizationManager.new()
	mock_mgr.add_translation(&"template", "Hello {0} and {1}")
	add_child_autofree(mock_mgr)
	U_SERVICE_LOCATOR.register(StringName("localization_manager"), mock_mgr)

	# Only one arg provided — {1} stays as-is, no crash
	var result: String = U_LocalizationUtils.localize_fmt(&"template", ["Alice"])
	assert_eq(result, "Hello Alice and {1}", "localize_fmt() should leave unresolved placeholders unchanged")

# --- Inline mock manager ---

class MockLocalizationManager extends Node:
	var _translations: Dictionary = {}

	func add_translation(key: StringName, value: String) -> void:
		_translations[String(key)] = value

	func translate(key: StringName) -> String:
		return _translations.get(String(key), String(key))

	func register_ui_root(_root: Node) -> void:
		pass

	func unregister_ui_root(_root: Node) -> void:
		pass
