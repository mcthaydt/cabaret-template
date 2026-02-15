@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_localization_manager.gd"
class_name M_LocalizationManager

## Localization Manager - applies locale and font settings from Redux localization slice.
## Uses Theme resources for font cascade (Godot's theme inheritance).

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")
const U_LOCALE_FILE_LOADER := preload("res://scripts/managers/helpers/u_locale_file_loader.gd")
const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")
const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")

const SERVICE_NAME := StringName("localization_manager")
const LOCALIZATION_SLICE_NAME := StringName("localization")
const CJK_LOCALES: Array[StringName] = [&"zh_CN", &"ja"]

## Control types that support the "font" theme property.
const _FONT_THEME_TYPES: Array[StringName] = [
	&"Control", &"Label", &"Button", &"OptionButton", &"CheckBox", &"CheckButton",
	&"LineEdit", &"TextEdit", &"RichTextLabel", &"ItemList",
	&"PopupMenu", &"TabBar", &"Tree",
]

## Injected dependency for tests
@export var state_store: I_StateStore = null

var _resolved_store: I_StateStore = null
var _active_locale: StringName = &""
var _translations: Dictionary = {}
var _ui_roots: Array[Node] = []
var _last_localization_hash: int = 0

var _dyslexia_enabled: bool = false

var _default_font: Font = null
var _dyslexia_font: Font = null
var _cjk_font: Font = null

var _font_theme: Theme = null

## Preview mode: applies locale+font without dispatching to store.
var _localization_preview_active: bool = false
var _applying_settings: bool = false

# For test inspection
var _apply_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_SERVICE_LOCATOR.register(SERVICE_NAME, self)
	_load_fonts()
	_initialize_store_async()

func _exit_tree() -> void:
	if _resolved_store != null and _resolved_store.has_signal("slice_updated"):
		if _resolved_store.slice_updated.is_connected(_on_slice_updated):
			_resolved_store.slice_updated.disconnect(_on_slice_updated)
	_resolved_store = null

func _initialize_store_async() -> void:
	if state_store != null:
		_on_store_ready(state_store)
		return
	var store := await _await_store_ready_soft()
	if store != null:
		_on_store_ready(store)
	else:
		print_verbose("M_LocalizationManager: StateStore not found. Loading default locale.")
		_load_locale(&"en")
		_apply_font_override(false)

func _on_store_ready(store: I_StateStore) -> void:
	_resolved_store = store
	if _resolved_store.has_signal("slice_updated"):
		_resolved_store.slice_updated.connect(_on_slice_updated)
	var state: Dictionary = _resolved_store.get_state()
	_apply_localization_settings(state)

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
	if _resolved_store == null:
		return
	if _localization_preview_active:
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
	_apply_ui_scale_override(state)
	_apply_count += 1
	var loc_slice: Dictionary = state.get("localization", {})
	_last_localization_hash = loc_slice.hash()
	_applying_settings = false

func _load_locale(locale: StringName) -> void:
	_translations = U_LOCALE_FILE_LOADER.load_locale(locale)
	_active_locale = locale
	_notify_ui_roots()

func translate(key: StringName) -> String:
	return _translations.get(String(key), String(key))

func get_locale() -> StringName:
	return _active_locale

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
	if root not in _ui_roots:
		_ui_roots.append(root)
		_apply_font_to_root(root)

func unregister_ui_root(root: Node) -> void:
	_ui_roots.erase(root)

## Preview mode: applies locale + font visually without dispatching to store.
## Used by settings UI for live preview while editing.
func set_localization_preview(preview: Dictionary) -> void:
	_localization_preview_active = true
	var locale: StringName = StringName(str(preview.get("locale", _active_locale)))
	var dyslexia: bool = bool(preview.get("dyslexia_font_enabled", _dyslexia_enabled))
	_dyslexia_enabled = dyslexia
	if locale != _active_locale:
		_load_locale(locale)
	_apply_font_override(dyslexia)

## Clear preview mode: reverts to store state.
func clear_localization_preview() -> void:
	if not _localization_preview_active:
		return
	_localization_preview_active = false
	if _resolved_store != null:
		var state: Dictionary = _resolved_store.get_state()
		_apply_localization_settings(state)

func _load_fonts() -> void:
	_default_font = load("res://assets/fonts/fnt_ui_default.ttf") as Font
	_dyslexia_font = load("res://assets/fonts/fnt_dyslexia.ttf") as Font
	_cjk_font = load("res://assets/fonts/fnt_cjk.otf") as Font

func _apply_font_override(dyslexia_enabled: bool) -> void:
	var font: Font = _get_active_font(dyslexia_enabled)
	_font_theme = _build_font_theme(font)
	for root: Node in _ui_roots:
		if not is_instance_valid(root):
			continue
		_apply_font_to_root(root)

func _get_active_font(dyslexia_enabled: bool = false) -> Font:
	if _active_locale in CJK_LOCALES:
		return _cjk_font
	return _dyslexia_font if dyslexia_enabled else _default_font

func _build_font_theme(font: Font) -> Theme:
	if font == null:
		return null
	var theme := Theme.new()
	for type_name: StringName in _FONT_THEME_TYPES:
		theme.set_font(&"font", type_name, font)
	return theme

func _apply_font_to_root(root: Node) -> void:
	if _font_theme == null:
		return
	if root is Control:
		(root as Control).theme = _font_theme
	elif root is CanvasLayer:
		for child: Node in root.get_children():
			if child is Control:
				(child as Control).theme = _font_theme

func _apply_ui_scale_override(state: Dictionary) -> void:
	if _resolved_store == null:
		return
	var scale_override: float = U_LOCALIZATION_SELECTORS.get_ui_scale_override(state)
	if scale_override == 1.0:
		return
	var current_ui_scale: float = U_DISPLAY_SELECTORS.get_ui_scale(state)
	if absf(current_ui_scale - scale_override) < 0.01:
		return
	_resolved_store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(scale_override))

func _notify_ui_roots() -> void:
	for root: Node in _ui_roots:
		if not is_instance_valid(root):
			continue
		if root.has_method("_on_locale_changed"):
			root._on_locale_changed(_active_locale)

func _await_store_ready_soft(max_frames: int = 60) -> I_StateStore:
	var tree := get_tree()
	if tree == null:
		return null
	var frames_waited := 0
	while frames_waited <= max_frames:
		var store := U_STATE_UTILS.try_get_store(self)
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
