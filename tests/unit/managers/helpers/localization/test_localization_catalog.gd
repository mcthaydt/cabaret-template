extends GutTest

const U_LOCALIZATION_CATALOG := preload("res://scripts/managers/helpers/localization/u_localization_catalog.gd")
const RS_LOCALE_TRANSLATIONS := preload("res://scripts/resources/localization/rs_locale_translations.gd")

func test_load_catalog_merges_multiple_domains_for_locale() -> void:
	var catalog := U_LOCALIZATION_CATALOG.new([
		_build_locale_resource(&"en", &"ui", {"menu.main.title": "Main Menu"}),
		_build_locale_resource(&"en", &"hud", {"hud.signpost.default": "Press to interact"}),
	])

	var result: Dictionary = catalog.load_catalog(&"en")
	assert_eq(result.get("menu.main.title", ""), "Main Menu", "UI keys should be present")
	assert_eq(result.get("hud.signpost.default", ""), "Press to interact", "HUD keys should be present")

func test_load_catalog_uses_deterministic_last_wins_overwrite_for_duplicates() -> void:
	var catalog := U_LOCALIZATION_CATALOG.new([
		_build_locale_resource(&"en", &"ui", {"common.confirm": "First"}),
		_build_locale_resource(&"en", &"hud", {"common.confirm": "Second"}),
	])

	var result: Dictionary = catalog.load_catalog(&"en")
	assert_eq(result.get("common.confirm", ""), "Second", "Later resources should deterministically overwrite earlier keys")

func test_load_catalog_uses_fallback_locale_for_missing_requested_keys() -> void:
	var catalog := U_LOCALIZATION_CATALOG.new([
		_build_locale_resource(&"en", &"ui", {"fallback.only": "Fallback", "shared.key": "English"}),
		_build_locale_resource(&"es", &"ui", {"shared.key": "Espanol"}),
	])

	var result: Dictionary = catalog.load_catalog(&"es")
	assert_eq(result.get("shared.key", ""), "Espanol", "Requested locale should override fallback values")
	assert_eq(result.get("fallback.only", ""), "Fallback", "Missing requested keys should come from fallback locale")
	assert_eq(catalog.resolve(&"es", &"missing.key"), "missing.key", "Missing key should resolve to key string")

func test_load_catalog_unsupported_locale_returns_empty() -> void:
	var catalog := U_LOCALIZATION_CATALOG.new([
		_build_locale_resource(&"en", &"ui", {"menu.main.title": "Main Menu"}),
	])

	var result: Dictionary = catalog.load_catalog(&"xx")
	assert_eq(result.size(), 0, "Unsupported locales should return an empty catalog")

func test_clear_cache_refreshes_runtime_resource_changes() -> void:
	var locale_resource: RS_LocaleTranslations = _build_locale_resource(&"en", &"ui", {"dynamic.key": "v1"})
	var catalog := U_LOCALIZATION_CATALOG.new([locale_resource])

	var first: Dictionary = catalog.load_catalog(&"en")
	assert_eq(first.get("dynamic.key", ""), "v1")

	locale_resource.translations["dynamic.key"] = "v2"
	var cached: Dictionary = catalog.load_catalog(&"en")
	assert_eq(cached.get("dynamic.key", ""), "v1", "Cached result should remain stable until invalidated")

	catalog.clear_cache()
	var refreshed: Dictionary = catalog.load_catalog(&"en")
	assert_eq(refreshed.get("dynamic.key", ""), "v2", "After clear_cache, helper should re-read resources")

func test_load_catalog_returns_deep_copy_not_cache_alias() -> void:
	var catalog := U_LOCALIZATION_CATALOG.new([
		_build_locale_resource(&"en", &"ui", {"shared.key": "Original"}),
	])

	var first: Dictionary = catalog.load_catalog(&"en")
	first["shared.key"] = "Mutated"

	var second: Dictionary = catalog.load_catalog(&"en")
	assert_eq(second.get("shared.key", ""), "Original", "Callers should not mutate internal cached state")

func _build_locale_resource(locale: StringName, domain: StringName, translations: Dictionary) -> RS_LocaleTranslations:
	var resource: RS_LocaleTranslations = RS_LOCALE_TRANSLATIONS.new()
	resource.locale = locale
	resource.domain = domain
	resource.translations = translations.duplicate(true)
	return resource
