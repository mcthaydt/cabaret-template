@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_localization_manager.gd"
class_name M_LocalizationManager

## Localization Manager - applies locale and font settings from Redux localization slice.
## Uses Theme resources for font cascade (Godot's theme inheritance).

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")
const U_LOCALIZATION_CATALOG := preload("res://scripts/managers/helpers/localization/u_localization_catalog.gd")
const U_LOCALIZATION_FONT_APPLIER := preload("res://scripts/managers/helpers/localization/u_localization_font_applier.gd")
const U_LOCALIZATION_PREVIEW_CONTROLLER := preload("res://scripts/managers/helpers/localization/u_localization_preview_controller.gd")
const U_LOCALIZATION_ROOT_REGISTRY := preload("res://scripts/managers/helpers/localization/u_localization_root_registry.gd")
const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/ui/utils/u_ui_theme_builder.gd")
const U_UI_THEME_DEBUG := preload("res://scripts/ui/utils/u_ui_theme_debug.gd")

const SERVICE_NAME := StringName("localization_manager")
const LOCALIZATION_SLICE_NAME := StringName("localization")

## Injected dependency for tests
@export var state_store: I_StateStore = null

var _resolved_store: I_StateStore = null
var _catalog := U_LOCALIZATION_CATALOG.new()
var _font_applier := U_LOCALIZATION_FONT_APPLIER.new()
var _preview_controller := U_LOCALIZATION_PREVIEW_CONTROLLER.new()
var _root_registry := U_LOCALIZATION_ROOT_REGISTRY.new()
var _active_locale: StringName = &""
var _translations: Dictionary = {}
var _last_localization_hash: int = 0

var _dyslexia_enabled: bool = false

var _default_font: Font = null
var _dyslexia_font: Font = null
var _cjk_font: Font = null

var _font_theme: Theme = null

var _applying_settings: bool = false

# For test inspection
var _apply_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_SERVICE_LOCATOR.register(SERVICE_NAME, self)
	_theme_debug_log("ready: service registered")
	_load_fonts()
	_initialize_store_async()

func _exit_tree() -> void:
	if _resolved_store != null and _resolved_store.has_signal("slice_updated"):
		if _resolved_store.slice_updated.is_connected(_on_slice_updated):
			_resolved_store.slice_updated.disconnect(_on_slice_updated)
	_root_registry.clear()
	_resolved_store = null

func _initialize_store_async() -> void:
	if state_store != null:
		_theme_debug_log("initialize_store_async: using injected state_store")
		_on_store_ready(state_store)
		return
	_theme_debug_log("initialize_store_async: awaiting store")
	var store := await _await_store_ready_soft()
	if store != null:
		_theme_debug_log("initialize_store_async: store resolved")
		_on_store_ready(store)
	else:
		_theme_debug_log("initialize_store_async: store missing, fallback locale=en")
		print_verbose("M_LocalizationManager: StateStore not found. Loading default locale.")
		_load_locale(&"en")
		_apply_font_override(false)

func _on_store_ready(store: I_StateStore) -> void:
	_resolved_store = store
	_theme_debug_log("store ready: applying localization settings")
	if _resolved_store.has_signal("slice_updated"):
		_resolved_store.slice_updated.connect(_on_slice_updated)
	var state: Dictionary = _resolved_store.get_state()
	_apply_localization_settings(state)

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
	if _resolved_store == null:
		return
	if _preview_controller.should_ignore_store_updates():
		return
	if _applying_settings:
		return
	if slice_name != LOCALIZATION_SLICE_NAME:
		return
	var state: Dictionary = _resolved_store.get_state()
	var loc_slice: Dictionary = state.get("localization", {})
	var loc_hash: int = loc_slice.hash()
	if loc_hash != _last_localization_hash:
		_apply_localization_settings(state)
		_last_localization_hash = loc_hash

func _apply_localization_settings(state: Dictionary) -> void:
	_applying_settings = true
	var locale: StringName = U_LOCALIZATION_SELECTORS.get_locale(state)
	var dyslexia: bool = U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state)
	_dyslexia_enabled = dyslexia
	if locale != _active_locale:
		_load_locale(locale)
	_apply_font_override(dyslexia)
	_apply_count += 1
	var loc_slice: Dictionary = state.get("localization", {})
	_last_localization_hash = loc_slice.hash()
	_applying_settings = false

func _load_locale(locale: StringName) -> void:
	if not _catalog.is_supported_locale(locale):
		print_verbose("M_LocalizationManager: Unsupported locale request ignored: %s" % str(locale))
		return
	_translations = _catalog.load_catalog(locale)
	_active_locale = locale
	locale_changed.emit(locale)
	_notify_ui_roots()

func translate(key: StringName) -> String:
	return _translations.get(String(key), String(key))

func get_locale() -> StringName:
	return _active_locale

func get_supported_locales() -> Array[StringName]:
	return _catalog.get_supported_locales()

func get_effective_settings() -> Dictionary:
	var ui_scale := 1.0
	if _resolved_store != null:
		var state: Dictionary = _resolved_store.get_state()
		ui_scale = U_LOCALIZATION_SELECTORS.get_ui_scale_override(state)
	ui_scale = _preview_controller.get_effective_ui_scale(ui_scale)
	return {
		"current_locale": _active_locale,
		"dyslexia_font_enabled": _dyslexia_enabled,
		"ui_scale_override": ui_scale,
	}

func is_preview_active() -> bool:
	return _preview_controller.is_preview_active()

func set_locale(locale: StringName) -> void:
	if _resolved_store != null:
		_resolved_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(locale))
	else:
		_load_locale(locale)

func set_dyslexia_font_enabled(enabled: bool) -> void:
	if _resolved_store != null:
		_resolved_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(enabled))
	else:
		_apply_font_override(enabled)

func register_ui_root(root: Node) -> void:
	if _root_registry.register_root(root):
		var has_theme := _font_theme != null
		var has_active_config := U_UI_THEME_BUILDER.active_config != null
		_theme_debug_log(
			"register_ui_root '%s': has_font_theme=%s has_active_config=%s" % [
				root.name,
				str(has_theme),
				str(has_active_config),
			]
		)
		_font_applier.apply_theme_to_root(root, _font_theme)

func unregister_ui_root(root: Node) -> void:
	_root_registry.unregister_root(root)

## Preview mode: applies locale + font visually without dispatching to store.
## Used by settings UI for live preview while editing.
func set_localization_preview(preview: Dictionary) -> void:
	_preview_controller.start_preview(preview)
	var locale: StringName = _preview_controller.resolve_locale(_active_locale)
	var dyslexia: bool = _preview_controller.resolve_dyslexia_enabled(_dyslexia_enabled)
	_dyslexia_enabled = dyslexia
	if locale != _active_locale:
		_load_locale(locale)
	_apply_font_override(dyslexia)

## Clear preview mode: reverts to store state.
func clear_localization_preview() -> void:
	if not _preview_controller.clear_preview():
		return
	if _resolved_store != null:
		var state: Dictionary = _resolved_store.get_state()
		_apply_localization_settings(state)

func _load_fonts() -> void:
	_font_applier.load_fonts()
	_default_font = _font_applier.get_default_font()
	_dyslexia_font = _font_applier.get_dyslexia_font()
	_cjk_font = _font_applier.get_cjk_font()
	_theme_debug_log(
		"fonts loaded: default=%s dyslexia=%s cjk=%s" % [
			str(_default_font != null),
			str(_dyslexia_font != null),
			str(_cjk_font != null),
		]
	)

func _apply_font_override(dyslexia_enabled: bool) -> void:
	_font_theme = _font_applier.build_theme(_active_locale, dyslexia_enabled)
	var roots: Array[Node] = _root_registry.get_live_roots()
	_theme_debug_log(
		"apply_font_override locale=%s dyslexia=%s theme_null=%s roots=%d active_config=%s" % [
			str(_active_locale),
			str(dyslexia_enabled),
			str(_font_theme == null),
			roots.size(),
			str(U_UI_THEME_BUILDER.active_config != null),
		]
	)
	for root: Node in roots:
		_font_applier.apply_theme_to_root(root, _font_theme)

func _get_active_font(dyslexia_enabled: bool = false) -> Font:
	return _font_applier.get_active_font(_active_locale, dyslexia_enabled)

func _notify_ui_roots() -> void:
	_root_registry.notify_locale_changed(_active_locale)

func _await_store_ready_soft(max_frames: int = 60) -> I_StateStore:
	var tree := get_tree()
	if tree == null:
		return null
	var frames_waited := 0
	while frames_waited <= max_frames:
		var store := U_DependencyResolution.resolve_state_store(null, null, self)
		if store != null:
			if store.is_ready():
				return store
			if store.has_signal("store_ready"):
				if _is_gut_running():
					return null
				await store.store_ready
				if is_instance_valid(store) and store.is_ready():
					return store
		elif _is_gut_running():
			return null
		await tree.process_frame
		frames_waited += 1
	return null

func _is_gut_running() -> bool:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	return tree.root.find_child("GutRunner", true, false) != null

func _theme_debug_log(message: String) -> void:
	U_UI_THEME_DEBUG.log("M_LocalizationManager", message)
