@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_display_manager.gd"
class_name M_DisplayManager

## Display Manager - applies display settings from Redux display slice.
## Phase 1B: Scaffolding for store subscription + preview mode.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const RS_QUALITY_PRESET := preload("res://scripts/resources/display/rs_quality_preset.gd")

const SERVICE_NAME := StringName("display_manager")
const DISPLAY_SLICE_NAME := StringName("display")

const WINDOW_PRESETS := {
	"1280x720": Vector2i(1280, 720),
	"1600x900": Vector2i(1600, 900),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1440": Vector2i(2560, 1440),
	"3840x2160": Vector2i(3840, 2160),
}
const QUALITY_PRESET_PATHS := {
	"low": "res://resources/display/cfg_quality_presets/cfg_quality_low.tres",
	"medium": "res://resources/display/cfg_quality_presets/cfg_quality_medium.tres",
	"high": "res://resources/display/cfg_quality_presets/cfg_quality_high.tres",
	"ultra": "res://resources/display/cfg_quality_presets/cfg_quality_ultra.tres",
}

## Injected dependency (tests)
@export var state_store: I_StateStore = null

var _state_store: I_StateStore = null
var _last_display_hash: int = 0
var _display_settings_preview_active: bool = false
var _preview_settings: Dictionary = {}
var _quality_preset_cache: Dictionary = {}

# Cached values for inspection/tests (Phase 1B)
var _last_applied_settings: Dictionary = {}
var _apply_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(SERVICE_NAME)
	U_SERVICE_LOCATOR.register(SERVICE_NAME, self)

	await _initialize_store_async()

func _exit_tree() -> void:
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

	var state := _state_store.get_state()
	_apply_display_settings(state)
	_last_display_hash = _get_display_hash(state)

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
				await store.store_ready
				if is_instance_valid(store) and store.is_ready():
					return store
		await tree.process_frame
		frames_waited += 1

	return null

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
	if slice_name != DISPLAY_SLICE_NAME or _display_settings_preview_active:
		return
	if _state_store == null:
		return

	var state := _state_store.get_state()
	var display_hash := _get_display_hash(state)
	if display_hash != _last_display_hash:
		_apply_display_settings(state)
		_last_display_hash = display_hash

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
	return null

func _apply_display_settings(state: Dictionary) -> void:
	var effective_settings := _build_effective_settings(state)
	_last_applied_settings = effective_settings
	_apply_count += 1
	_apply_window_settings(effective_settings)
	_apply_quality_settings(effective_settings)

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
	var state := {"display": display_settings}
	var window_preset := U_DISPLAY_SELECTORS.get_window_size_preset(state)
	var window_mode := U_DISPLAY_SELECTORS.get_window_mode(state)
	var vsync_enabled := U_DISPLAY_SELECTORS.is_vsync_enabled(state)

	apply_window_size_preset(window_preset)
	set_window_mode(window_mode)
	set_vsync_enabled(vsync_enabled)

func _apply_quality_settings(display_settings: Dictionary) -> void:
	var state := {"display": display_settings}
	var preset := U_DISPLAY_SELECTORS.get_quality_preset(state)
	apply_quality_preset(preset)

func apply_window_size_preset(preset: String) -> void:
	if not WINDOW_PRESETS.has(preset):
		return
	if not _is_display_server_available():
		return
	if is_inside_tree():
		call_deferred("_apply_window_size_preset_now", preset)
	else:
		_apply_window_size_preset_now(preset)

func set_window_mode(mode: String) -> void:
	if not _is_display_server_available():
		return
	if is_inside_tree():
		call_deferred("_set_window_mode_now", mode)
	else:
		_set_window_mode_now(mode)

func set_vsync_enabled(enabled: bool) -> void:
	if not _is_display_server_available():
		return
	if is_inside_tree():
		call_deferred("_set_vsync_enabled_now", enabled)
	else:
		_set_vsync_enabled_now(enabled)

func _apply_window_size_preset_now(preset: String) -> void:
	if not WINDOW_PRESETS.has(preset):
		return
	var size: Vector2i = WINDOW_PRESETS[preset]
	DisplayServer.window_set_size(size)
	var screen_size := DisplayServer.screen_get_size()
	var window_pos := (screen_size - size) / 2
	DisplayServer.window_set_position(window_pos)

func _set_window_mode_now(mode: String) -> void:
	match mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size := DisplayServer.screen_get_size()
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(Vector2i.ZERO)
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		_:
			push_warning("M_DisplayManager: Invalid window mode '%s'" % mode)

func _set_vsync_enabled_now(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func apply_quality_preset(preset: String) -> void:
	if preset.is_empty():
		return
	if not _is_rendering_available():
		return

	var config := _load_quality_preset(preset)
	if config == null:
		return

	_apply_shadow_quality(String(config.shadow_quality))
	_apply_anti_aliasing(String(config.anti_aliasing))

func _load_quality_preset(preset: String) -> Resource:
	if _quality_preset_cache.has(preset):
		return _quality_preset_cache[preset]

	var path: String = String(QUALITY_PRESET_PATHS.get(preset, ""))
	if path.is_empty():
		push_warning("M_DisplayManager: Unknown quality preset '%s'" % preset)
		return null

	var resource := load(path)
	if resource == null or not (resource is RS_QUALITY_PRESET):
		push_warning("M_DisplayManager: Failed to load quality preset '%s' (%s)" % [preset, path])
		return null

	_quality_preset_cache[preset] = resource
	return resource

func _apply_shadow_quality(shadow_quality: String) -> void:
	match shadow_quality:
		"off":
			RenderingServer.directional_shadow_atlas_set_size(0, false)
		"low":
			RenderingServer.directional_shadow_atlas_set_size(1024, false)
		"medium":
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		"high":
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		_:
			push_warning("M_DisplayManager: Unknown shadow quality '%s'" % shadow_quality)

func _apply_anti_aliasing(anti_aliasing: String) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	match anti_aliasing:
		"none":
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"fxaa":
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"msaa_2x":
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"msaa_4x":
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"msaa_8x":
			viewport.msaa_3d = Viewport.MSAA_8X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		_:
			push_warning("M_DisplayManager: Unknown anti-aliasing '%s'" % anti_aliasing)

func _is_display_server_available() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	return not (OS.has_feature("headless") or OS.has_feature("server") or display_name == "headless" or display_name == "dummy")

func _is_rendering_available() -> bool:
	return not (OS.has_feature("headless") or OS.has_feature("server"))

func _get_display_hash(state: Dictionary) -> int:
	if state == null:
		return 0
	var slice: Variant = state.get(DISPLAY_SLICE_NAME, {})
	if slice is Dictionary:
		return (slice as Dictionary).hash()
	return 0
