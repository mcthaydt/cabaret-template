@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_LocalizationInitialState

## Localization Initial State Resource (Phase 0 - Task 0A.2)
##
## Defines default localization settings for the localization slice.

@export_group("Language")
@export_enum("en", "es", "pt", "zh_CN", "ja") var current_locale: String = "en"

@export_group("First-Run")
@export var has_selected_language: bool = false

@export_group("Accessibility")
@export var dyslexia_font_enabled: bool = false

@export_group("UI")
@export_range(0.5, 2.0, 0.05) var ui_scale_override: float = 1.0

## Convert resource to Dictionary for state store.
## current_locale is stored as StringName for efficient Redux comparisons.
func to_dictionary() -> Dictionary:
	return {
		"current_locale": StringName(current_locale),
		"dyslexia_font_enabled": dyslexia_font_enabled,
		"ui_scale_override": ui_scale_override,
		"has_selected_language": has_selected_language,
	}
