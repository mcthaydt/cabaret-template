class_name U_LocaleFileLoader
extends RefCounted

## Helper for loading locale translation JSON files.
## Uses FileAccess.open() — NOT preload() (preload on .json is a compile error).

const _LOCALE_FILE_PATHS: Dictionary = {
	&"en":    ["res://resources/localization/en/ui.json",
			   "res://resources/localization/en/hud.json"],
	&"es":    ["res://resources/localization/es/ui.json",
			   "res://resources/localization/es/hud.json"],
	&"pt":    ["res://resources/localization/pt/ui.json",
			   "res://resources/localization/pt/hud.json"],
	&"zh_CN": ["res://resources/localization/zh_CN/ui.json",
			   "res://resources/localization/zh_CN/hud.json"],
	&"ja":    ["res://resources/localization/ja/ui.json",
			   "res://resources/localization/ja/hud.json"],
}

## Load all translation files for the given locale and merge them.
## Returns an empty Dictionary if locale is unsupported or files are missing.
static func load_locale(locale: StringName) -> Dictionary:
	var merged: Dictionary = {}
	var paths: Array = _LOCALE_FILE_PATHS.get(locale, [])
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("U_LocaleFileLoader: could not open %s" % path)
			continue
		var text: String = file.get_as_text()
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			merged.merge(parsed, true)
		else:
			push_error("U_LocaleFileLoader: invalid JSON in %s" % path)
	return merged
