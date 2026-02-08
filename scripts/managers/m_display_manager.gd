@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_display_manager.gd"
class_name M_DisplayManager

## Display Manager - applies display settings from Redux display slice.
## Phase 1B: Scaffolding for store subscription + preview mode.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_PALETTE_MANAGER := preload("res://scripts/managers/helpers/u_palette_manager.gd")
const U_DISPLAY_SERVER_WINDOW_OPS := preload("res://scripts/utils/display/u_display_server_window_ops.gd")
const U_DISPLAY_WINDOW_APPLIER := preload("res://scripts/managers/helpers/display/u_display_window_applier.gd")
const U_DISPLAY_QUALITY_APPLIER := preload("res://scripts/managers/helpers/display/u_display_quality_applier.gd")
const U_DISPLAY_POST_PROCESS_APPLIER := preload("res://scripts/managers/helpers/display/u_display_post_process_applier.gd")
const U_DISPLAY_UI_SCALE_APPLIER := preload("res://scripts/managers/helpers/display/u_display_ui_scale_applier.gd")
const U_DISPLAY_UI_THEME_APPLIER := preload("res://scripts/managers/helpers/display/u_display_ui_theme_applier.gd")
const U_DISPLAY_CINEMA_GRADE_APPLIER := preload("res://scripts/managers/helpers/display/u_display_cinema_grade_applier.gd")

const SERVICE_NAME := StringName("display_manager")
const DISPLAY_SLICE_NAME := StringName("display")
const NAVIGATION_SLICE_NAME := StringName("navigation")
const SHELL_GAMEPLAY := StringName("gameplay")

const MIN_UI_SCALE := 0.8
const MAX_UI_SCALE := 1.3

## Injected dependency (tests)
@export var state_store: I_StateStore = null
var window_ops: I_WindowOps = null

var _state_store: I_StateStore = null
var _window_ops: I_WindowOps = null
var _last_display_hash: int = 0
var _last_window_hash: int = 0
var _display_settings_preview_active: bool = false
var _preview_settings: Dictionary = {}
var _palette_manager: RefCounted = null

var _window_applier: RefCounted = null  # U_DisplayWindowApplier
var _quality_applier: RefCounted = null  # U_DisplayQualityApplier
var _post_process_applier: RefCounted = null  # U_DisplayPostProcessApplier
var _ui_scale_applier: RefCounted = null  # U_DisplayUIScaleApplier
var _ui_theme_applier: RefCounted = null  # U_DisplayUIThemeApplier
var _cinema_grade_applier: RefCounted = null  # U_DisplayCinemaGradeApplier

# Cached values for inspection/tests (Phase 1B)
var _last_applied_settings: Dictionary = {}
var _apply_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_SERVICE_LOCATOR.register(SERVICE_NAME, self)
	_ensure_appliers()

	await _initialize_store_async()

func _exit_tree() -> void:
	if _cinema_grade_applier != null:
		_cinema_grade_applier.cleanup()
	if _state_store != null and _state_store.has_signal("slice_updated"):
		if _state_store.slice_updated.is_connected(_on_slice_updated):
			_state_store.slice_updated.disconnect(_on_slice_updated)
	_state_store = null

func _initialize_store_async() -> void:
	var store := await _await_store_ready_soft()
	if store == null:
		print_verbose("M_DisplayManager: StateStore not found. Display settings will not be applied.")
		return

	_state_store = store
	if _state_store.has_signal("slice_updated"):
		_state_store.slice_updated.connect(_on_slice_updated)

	_ensure_appliers()
	if _cinema_grade_applier != null:
		_cinema_grade_applier.initialize(self, _state_store)

	var state := _state_store.get_state()
	_apply_display_settings(state)
	_last_display_hash = _get_display_hash(state)
	_update_overlay_visibility()

func _process(__delta: float) -> void:
	if _post_process_applier == null:
		return
	_post_process_applier.process_film_grain_time()

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

func _on_slice_updated(slice_name: StringName, __slice_data: Dictionary) -> void:
	if _state_store == null:
		return

	if slice_name == DISPLAY_SLICE_NAME and not _display_settings_preview_active:
		var state := _state_store.get_state()
		var display_hash := _get_display_hash(state)
		if display_hash != _last_display_hash:
			_apply_display_settings(state)
			_last_display_hash = display_hash

	if slice_name == NAVIGATION_SLICE_NAME:
		_update_overlay_visibility()

## Override: I_DisplayManager.set_display_settings_preview
func set_display_settings_preview(settings: Dictionary) -> void:
	_preview_settings = settings.duplicate(true)
	_display_settings_preview_active = true
	var state: Dictionary = {}
	if _state_store != null:
		state = _state_store.get_state()
	_apply_display_settings(state)

## Override: I_DisplayManager.clear_display_settings_preview
func clear_display_settings_preview() -> void:
	_preview_settings.clear()
	_display_settings_preview_active = false
	if _state_store == null:
		_last_applied_settings = {}
		return
	var state := _state_store.get_state()
	_apply_display_settings(state)
	_last_display_hash = _get_display_hash(state)

## Override: I_DisplayManager.get_active_palette
func get_active_palette() -> Resource:
	if _palette_manager == null:
		return null
	return _palette_manager.get_active_palette()

func _apply_display_settings(state: Dictionary) -> void:
	var effective_settings := _build_effective_settings(state)
	_last_applied_settings = effective_settings
	_apply_count += 1

	var window_hash := _get_window_hash(effective_settings)
	if window_hash != _last_window_hash:
		_apply_window_settings(effective_settings)
		_last_window_hash = window_hash

	_apply_quality_settings(effective_settings)
	_apply_post_process_settings(effective_settings)
	_apply_cinema_grade_settings(effective_settings)
	_apply_ui_scale_settings(effective_settings)
	_apply_accessibility_settings(effective_settings)

func _build_effective_settings(state: Dictionary) -> Dictionary:
	var settings: Dictionary = {}
	if state != null:
		var slice: Variant = state.get(DISPLAY_SLICE_NAME, {})
		if slice is Dictionary:
			settings = (slice as Dictionary).duplicate(true)

	if _display_settings_preview_active:
		for key in _preview_settings.keys():
			settings[key] = _preview_settings[key]
	return settings

func _apply_window_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _window_applier == null:
		return
	_window_applier.set_window_ops(_get_window_ops())
	_window_applier.apply_settings(display_settings)

func _apply_quality_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _quality_applier == null:
		return
	_quality_applier.apply_settings(display_settings)

func _apply_ui_scale_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _ui_scale_applier == null:
		return
	var state := {"display": display_settings}
	var scale := U_DISPLAY_SELECTORS.get_ui_scale(state)
	_ui_scale_applier.set_ui_scale(scale)

func _apply_accessibility_settings(display_settings: Dictionary) -> void:
	if _palette_manager == null:
		_palette_manager = U_PALETTE_MANAGER.new()
	var state := {"display": display_settings}
	var mode := U_DISPLAY_SELECTORS.get_color_blind_mode(state)
	var high_contrast := U_DISPLAY_SELECTORS.is_high_contrast_enabled(state)
	_palette_manager.set_color_blind_mode(mode, high_contrast)
	_ensure_appliers()
	if _ui_theme_applier != null:
		_ui_theme_applier.apply_theme_from_palette(_palette_manager.get_active_palette())
		if _ui_scale_applier != null:
			_ui_theme_applier.apply_theme_to_roots(_ui_scale_applier.get_roots())

func _apply_post_process_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _post_process_applier == null:
		return
	_post_process_applier.apply_settings(display_settings)
	_update_overlay_visibility()

func _apply_cinema_grade_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _cinema_grade_applier == null:
		return
	_cinema_grade_applier.apply_settings(display_settings)

func set_ui_scale(scale: float) -> void:
	_ensure_appliers()
	if _ui_scale_applier == null:
		return
	_ui_scale_applier.set_ui_scale(scale)

func apply_window_size_preset(preset: String) -> void:
	_ensure_appliers()
	if _window_applier == null:
		return
	_window_applier.set_window_ops(_get_window_ops())
	_window_applier.apply_window_size_preset(preset)

func set_window_mode(mode: String) -> void:
	_ensure_appliers()
	if _window_applier == null:
		return
	_window_applier.set_window_ops(_get_window_ops())
	_window_applier.set_window_mode(mode)

func set_vsync_enabled(enabled: bool) -> void:
	_ensure_appliers()
	if _window_applier == null:
		return
	_window_applier.set_window_ops(_get_window_ops())
	_window_applier.set_vsync_enabled(enabled)

func apply_quality_preset(preset: String) -> void:
	_ensure_appliers()
	if _quality_applier == null:
		return
	_quality_applier.apply_quality_preset(preset)

func _get_display_hash(state: Dictionary) -> int:
	if state == null:
		return 0
	var slice: Variant = state.get(DISPLAY_SLICE_NAME, {})
	if slice is Dictionary:
		return (slice as Dictionary).hash()
	return 0

func _get_window_hash(display_settings: Dictionary) -> int:
	if display_settings == null:
		return 0
	var preset: Variant = display_settings.get("window_size_preset", "")
	var mode: Variant = display_settings.get("window_mode", "")
	var vsync: Variant = display_settings.get("vsync_enabled", true)
	return [preset, mode, vsync].hash()

func _get_window_ops() -> I_WindowOps:
	if window_ops != null:
		return window_ops
	if _window_ops == null:
		_window_ops = U_DISPLAY_SERVER_WINDOW_OPS.new()
	return _window_ops

func _is_display_server_available() -> bool:
	_ensure_appliers()
	if _window_applier == null:
		return false
	_window_applier.set_window_ops(_get_window_ops())
	return _window_applier.is_display_server_available()

func _ensure_appliers() -> void:
	if _window_applier == null:
		_window_applier = U_DISPLAY_WINDOW_APPLIER.new()
		_window_applier.initialize(self)
	if _quality_applier == null:
		_quality_applier = U_DISPLAY_QUALITY_APPLIER.new()
		_quality_applier.initialize(self)
	if _post_process_applier == null:
		_post_process_applier = U_DISPLAY_POST_PROCESS_APPLIER.new()
		_post_process_applier.initialize(self)
	if _ui_scale_applier == null:
		_ui_scale_applier = U_DISPLAY_UI_SCALE_APPLIER.new()
		_ui_scale_applier.initialize(MIN_UI_SCALE, MAX_UI_SCALE)
	if _ui_theme_applier == null:
		_ui_theme_applier = U_DISPLAY_UI_THEME_APPLIER.new()
	if _cinema_grade_applier == null:
		_cinema_grade_applier = U_DISPLAY_CINEMA_GRADE_APPLIER.new()

func register_ui_scale_root(node: Node) -> void:
	_ensure_appliers()
	if _ui_scale_applier != null:
		_ui_scale_applier.register_ui_scale_root(node)
	if _ui_theme_applier != null:
		_ui_theme_applier.apply_theme_to_node(node)

func unregister_ui_scale_root(node: Node) -> void:
	_ensure_appliers()
	if _ui_scale_applier == null:
		return
	_ui_scale_applier.unregister_ui_scale_root(node)

func _update_overlay_visibility() -> void:
	if _state_store == null:
		return
	_ensure_appliers()

	var state := _state_store.get_state()
	var navigation_state: Dictionary = state.get("navigation", {})
	var shell := U_NAVIGATION_SELECTORS.get_shell(navigation_state)
	var should_show := shell == SHELL_GAMEPLAY

	if _post_process_applier != null:
		_post_process_applier.update_overlay_visibility(should_show)
	if _cinema_grade_applier != null:
		_cinema_grade_applier.update_visibility(should_show)
