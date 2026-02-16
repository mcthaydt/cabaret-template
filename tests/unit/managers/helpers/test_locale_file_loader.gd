extends GutTest

## Tests for U_LocaleFileLoader helper (Phase 2A)

const U_LOCALE_FILE_LOADER := preload("res://scripts/managers/helpers/u_locale_file_loader.gd")

func test_load_locale_returns_dictionary() -> void:
	var result: Dictionary = U_LOCALE_FILE_LOADER.load_locale(&"en")
	assert_true(result is Dictionary, "load_locale should return a Dictionary")

func test_load_locale_unsupported_returns_empty() -> void:
	var result: Dictionary = U_LOCALE_FILE_LOADER.load_locale(&"xx")
	assert_eq(result.size(), 0, "Unsupported locale should return empty Dictionary")

func test_load_locale_merges_multiple_resources() -> void:
	var result: Dictionary = U_LOCALE_FILE_LOADER.load_locale(&"en")
	assert_true(result is Dictionary, "Merging multiple resources should return Dictionary")
	assert_true(result.has("menu.main.title"), "UI translations should be merged for locale")
	assert_true(result.has("hud.signpost.default"), "HUD translations should be merged for locale")
