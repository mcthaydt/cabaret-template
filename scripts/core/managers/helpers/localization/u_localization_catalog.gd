class_name U_LocalizationCatalog
extends RefCounted

## Loads and caches translation catalogs from preloaded locale resources.
## Fallback chain: requested locale -> fallback locale (en) -> key string.

const FALLBACK_LOCALE := &"en"
const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]

## Mobile-safe: const preload list (no runtime file scanning).
const _LOCALE_RESOURCES: Array[RS_LocaleTranslations] = [
	preload("res://resources/localization/cfg_locale_en_ui.tres"),
	preload("res://resources/localization/cfg_locale_en_hud.tres"),
	preload("res://resources/localization/cfg_locale_es_ui.tres"),
	preload("res://resources/localization/cfg_locale_es_hud.tres"),
	preload("res://resources/localization/cfg_locale_pt_ui.tres"),
	preload("res://resources/localization/cfg_locale_pt_hud.tres"),
	preload("res://resources/localization/cfg_locale_zh_CN_ui.tres"),
	preload("res://resources/localization/cfg_locale_zh_CN_hud.tres"),
	preload("res://resources/localization/cfg_locale_ja_ui.tres"),
	preload("res://resources/localization/cfg_locale_ja_hud.tres"),
]

var _locale_resources: Array[RS_LocaleTranslations] = []
var _raw_catalog_cache: Dictionary = {}
var _effective_catalog_cache: Dictionary = {}

func _init(locale_resources: Array[RS_LocaleTranslations] = []) -> void:
	if locale_resources.is_empty():
		_locale_resources = _LOCALE_RESOURCES.duplicate()
	else:
		_locale_resources = locale_resources.duplicate()

func get_supported_locales() -> Array[StringName]:
	return SUPPORTED_LOCALES.duplicate()

func is_supported_locale(locale: StringName) -> bool:
	return locale in SUPPORTED_LOCALES

## Invalidates all cached catalogs. Use this if resources are reloaded at runtime.
func clear_cache() -> void:
	_raw_catalog_cache.clear()
	_effective_catalog_cache.clear()

## Returns the merged catalog for `locale`, falling back to English for missing keys.
## Unsupported locales return an empty dictionary.
func load_catalog(locale: StringName, force_refresh: bool = false) -> Dictionary:
	if not is_supported_locale(locale):
		return {}
	if force_refresh:
		clear_cache()
	if _effective_catalog_cache.has(locale):
		return (_effective_catalog_cache.get(locale, {}) as Dictionary).duplicate(true)

	var effective_catalog: Dictionary = _load_raw_catalog(FALLBACK_LOCALE)
	if locale != FALLBACK_LOCALE:
		var locale_catalog: Dictionary = _load_raw_catalog(locale)
		effective_catalog.merge(locale_catalog, true)
	_effective_catalog_cache[locale] = effective_catalog.duplicate(true)
	return effective_catalog.duplicate(true)

func resolve(locale: StringName, key: StringName) -> String:
	var catalog: Dictionary = load_catalog(locale)
	return String(catalog.get(String(key), String(key)))

func _load_raw_catalog(locale: StringName) -> Dictionary:
	if _raw_catalog_cache.has(locale):
		return (_raw_catalog_cache.get(locale, {}) as Dictionary).duplicate(true)

	var merged: Dictionary = {}
	for locale_resource: RS_LocaleTranslations in _locale_resources:
		if locale_resource == null:
			continue
		if locale_resource.locale != locale:
			continue
		merged.merge(locale_resource.translations, true)
	_raw_catalog_cache[locale] = merged.duplicate(true)
	return merged.duplicate(true)
