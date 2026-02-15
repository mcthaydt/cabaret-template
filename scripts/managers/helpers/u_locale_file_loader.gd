class_name U_LocaleFileLoader
extends RefCounted

## Helper for loading locale translations from preloaded .tres resources.
## Mobile-safe: uses const preload arrays instead of runtime FileAccess.

const _LOCALE_RESOURCES: Array = [
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

## Load all translation resources for the given locale and merge them.
## Returns an empty Dictionary if locale is unsupported.
static func load_locale(locale: StringName) -> Dictionary:
	var merged: Dictionary = {}
	for res: RS_LocaleTranslations in _LOCALE_RESOURCES:
		if res.locale == locale:
			merged.merge(res.translations, true)
	return merged
