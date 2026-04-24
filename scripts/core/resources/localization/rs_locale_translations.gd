extends Resource
class_name RS_LocaleTranslations

## Resource holding translations for a single locale + domain pair.
## Used as mobile-safe preloaded resources instead of runtime JSON file loading.

@export var locale: StringName = &"en"
@export var domain: StringName = &"ui"
@export var translations: Dictionary = {}
