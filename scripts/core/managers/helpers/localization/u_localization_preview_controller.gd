extends RefCounted
class_name U_LocalizationPreviewController

## Owns temporary preview settings for localization UI workflows.
## Preview mode is visual-only and should not dispatch Redux actions.

var _preview_active: bool = false
var _preview_settings: Dictionary = {}

func start_preview(preview: Dictionary) -> void:
	_preview_active = true
	_preview_settings = preview.duplicate(true)

func clear_preview() -> bool:
	if not _preview_active:
		return false
	_preview_active = false
	_preview_settings.clear()
	return true

func is_preview_active() -> bool:
	return _preview_active

func should_ignore_store_updates() -> bool:
	return _preview_active

func get_preview_settings() -> Dictionary:
	return _preview_settings.duplicate(true)

func resolve_locale(fallback_locale: StringName) -> StringName:
	return StringName(str(_preview_settings.get("locale", fallback_locale)))

func resolve_dyslexia_enabled(fallback_enabled: bool) -> bool:
	return bool(_preview_settings.get("dyslexia_font_enabled", fallback_enabled))

func get_effective_ui_scale(store_ui_scale: float) -> float:
	if _preview_settings.has("ui_scale_override"):
		return float(_preview_settings.get("ui_scale_override", store_ui_scale))
	return store_ui_scale
