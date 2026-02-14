extends Node
class_name I_LocalizationManager

## Minimal interface for M_LocalizationManager
##
## Implementations:
## - M_LocalizationManager (production)

func set_locale(_locale: StringName) -> void:
	push_error("I_LocalizationManager.set_locale not implemented")

func get_locale() -> StringName:
	push_error("I_LocalizationManager.get_locale not implemented")
	return &""

func set_dyslexia_font_enabled(_enabled: bool) -> void:
	push_error("I_LocalizationManager.set_dyslexia_font_enabled not implemented")

func register_ui_root(_root: Node) -> void:
	push_error("I_LocalizationManager.register_ui_root not implemented")

func unregister_ui_root(_root: Node) -> void:
	push_error("I_LocalizationManager.unregister_ui_root not implemented")
