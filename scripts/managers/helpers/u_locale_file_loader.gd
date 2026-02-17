class_name U_LocaleFileLoader
extends RefCounted

## Compatibility shim around U_LocalizationCatalog.
## Kept temporarily to avoid breaking existing call sites during the refactor.

const U_LOCALIZATION_CATALOG := preload("res://scripts/managers/helpers/localization/u_localization_catalog.gd")

static var _catalog := U_LOCALIZATION_CATALOG.new()

## Returns requested locale catalog merged with fallback locale entries.
static func load_locale(locale: StringName) -> Dictionary:
	return _catalog.load_catalog(locale)

static func clear_cache() -> void:
	_catalog.clear_cache()
