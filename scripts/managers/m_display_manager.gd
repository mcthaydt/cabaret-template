@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_display_manager.gd"
class_name M_DisplayManager

## Display Manager - applies display settings from Redux display slice.
## Phase 1B: Scaffolding for store subscription + preview mode.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_POST_PROCESS_LAYER := preload("res://scripts/managers/helpers/u_post_process_layer.gd")
const U_PALETTE_MANAGER := preload("res://scripts/managers/helpers/u_palette_manager.gd")
const U_DISPLAY_SERVER_WINDOW_OPS := preload("res://scripts/utils/display/u_display_server_window_ops.gd")
const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/utils/display/u_display_option_catalog.gd")
const RS_LUT_DEFINITION := preload("res://scripts/resources/display/rs_lut_definition.gd")
const RS_UI_COLOR_PALETTE := preload("res://scripts/resources/ui/rs_ui_color_palette.gd")
const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")

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
var _current_ui_scale: float = 1.0
var _ui_scale_roots: Array[Node] = []
var _palette_manager: RefCounted = null
var _ui_theme: Theme = null
var _ui_theme_palette_id: StringName = StringName("")
var _window_mode_retry_frame: int = -1

# Post-process overlay (Phase 3C)
var _post_process_layer: U_PostProcessLayer = null
var _post_process_overlay: Node = null
var _film_grain_active: bool = false

# Cached values for inspection/tests (Phase 1B)
var _last_applied_settings: Dictionary = {}
var _apply_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_SERVICE_LOCATOR.register(SERVICE_NAME, self)

	await _initialize_store_async()

func _exit_tree() -> void:
	if _state_store != null and _state_store.has_signal("slice_updated"):
		if _state_store.slice_updated.is_connected(_on_slice_updated):
			_state_store.slice_updated.disconnect(_on_slice_updated)
	_state_store = null
	_ui_scale_roots.clear()

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

func _process(_delta: float) -> void:
	if not _film_grain_active:
		return
	if _post_process_layer == null:
		return
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN,
		StringName("time"),
		time_seconds
	)

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
		_palette_manager = U_PALETTE_MANAGER.new()
	if not _last_applied_settings.is_empty():
		_apply_accessibility_settings(_last_applied_settings)
	else:
		if _palette_manager.get_active_palette() == null:
			_palette_manager.set_color_blind_mode("normal", false)
	var palette: Resource = _palette_manager.get_active_palette()
	_apply_ui_theme_from_palette(palette)
	return palette

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
	var state := {"display": display_settings}
	var window_preset := U_DISPLAY_SELECTORS.get_window_size_preset(state)
	var window_mode := U_DISPLAY_SELECTORS.get_window_mode(state)
	var vsync_enabled := U_DISPLAY_SELECTORS.is_vsync_enabled(state)

	set_window_mode(window_mode)
	if window_mode == "windowed":
		apply_window_size_preset(window_preset)
	set_vsync_enabled(vsync_enabled)

func _apply_quality_settings(display_settings: Dictionary) -> void:
	var state := {"display": display_settings}
	var preset := U_DISPLAY_SELECTORS.get_quality_preset(state)
	apply_quality_preset(preset)

func _apply_ui_scale_settings(display_settings: Dictionary) -> void:
	var state := {"display": display_settings}
	var scale := U_DISPLAY_SELECTORS.get_ui_scale(state)
	set_ui_scale(scale)

func _apply_accessibility_settings(display_settings: Dictionary) -> void:
	if _palette_manager == null:
		_palette_manager = U_PALETTE_MANAGER.new()
	var state := {"display": display_settings}
	var mode := U_DISPLAY_SELECTORS.get_color_blind_mode(state)
	var high_contrast := U_DISPLAY_SELECTORS.is_high_contrast_enabled(state)
	_palette_manager.set_color_blind_mode(mode, high_contrast)
	_apply_ui_theme_from_palette(_palette_manager.get_active_palette())

func _apply_post_process_settings(display_settings: Dictionary) -> void:
	if not _ensure_post_process_layer():
		return
	var state := {"display": display_settings}
	_apply_film_grain_settings(state)
	_apply_crt_settings(state)
	_apply_dither_settings(state)
	_apply_lut_settings(state)
	_apply_color_blind_shader_settings(state)

func _apply_film_grain_settings(state: Dictionary) -> void:
	var enabled := U_DISPLAY_SELECTORS.is_film_grain_enabled(state)
	_film_grain_active = enabled
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN, enabled)
	var intensity := U_DISPLAY_SELECTORS.get_film_grain_intensity(state)
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN,
		StringName("intensity"),
		intensity
	)

func _apply_crt_settings(state: Dictionary) -> void:
	var enabled := U_DISPLAY_SELECTORS.is_crt_enabled(state)
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_CRT, enabled)
	var scanline_intensity := U_DISPLAY_SELECTORS.get_crt_scanline_intensity(state)
	var curvature := U_DISPLAY_SELECTORS.get_crt_curvature(state)
	var chromatic_aberration := U_DISPLAY_SELECTORS.get_crt_chromatic_aberration(state)
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_CRT,
		StringName("scanline_intensity"),
		scanline_intensity
	)
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_CRT,
		StringName("curvature"),
		curvature
	)
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_CRT,
		StringName("chromatic_aberration"),
		chromatic_aberration
	)

func _apply_dither_settings(state: Dictionary) -> void:
	var enabled := U_DISPLAY_SELECTORS.is_dither_enabled(state)
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_DITHER, enabled)
	var intensity := U_DISPLAY_SELECTORS.get_dither_intensity(state)
	var pattern := U_DISPLAY_SELECTORS.get_dither_pattern(state)
	var pattern_mode := 0
	match pattern:
		"bayer":
			pattern_mode = 0
		"noise":
			pattern_mode = 1
		_:
			pattern_mode = 0
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_DITHER,
		StringName("intensity"),
		intensity
	)
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_DITHER,
		StringName("pattern_mode"),
		pattern_mode
	)

func _apply_lut_settings(state: Dictionary) -> void:
	var enabled := U_DISPLAY_SELECTORS.is_lut_enabled(state)
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_LUT, enabled)
	var intensity := U_DISPLAY_SELECTORS.get_lut_intensity(state)
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_LUT,
		StringName("intensity"),
		intensity
	)

	var lut_path := U_DISPLAY_SELECTORS.get_lut_resource(state)
	if lut_path.is_empty():
		return
	var resource: Resource = load(lut_path)
	if resource == null:
		push_warning("M_DisplayManager: Failed to load LUT resource '%s'" % lut_path)
		return

	var lut_texture: Texture2D = null
	if resource is Texture2D:
		lut_texture = resource as Texture2D
	elif resource is RS_LUT_DEFINITION:
		var definition := resource as RS_LUT_DEFINITION
		if definition.texture == null:
			push_warning("M_DisplayManager: LUT texture missing for '%s'" % lut_path)
			return
		lut_texture = definition.texture
	else:
		push_warning("M_DisplayManager: Invalid LUT resource '%s' (expected Texture2D or RS_LUTDefinition)" % lut_path)
		return

	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_LUT,
		StringName("lut_texture"),
		lut_texture
	)

func _apply_color_blind_shader_settings(state: Dictionary) -> void:
	var enabled := U_DISPLAY_SELECTORS.is_color_blind_shader_enabled(state)
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_COLOR_BLIND, enabled)
	var mode := U_DISPLAY_SELECTORS.get_color_blind_mode(state)
	var mode_value := _get_color_blind_mode_value(mode)
	if not enabled:
		mode_value = 0
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_COLOR_BLIND,
		StringName("mode"),
		mode_value
	)
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_COLOR_BLIND,
		StringName("intensity"),
		1.0
	)

func set_ui_scale(scale: float) -> void:
	var clamped_scale := clampf(scale, MIN_UI_SCALE, MAX_UI_SCALE)
	_current_ui_scale = clamped_scale
	if _ui_scale_roots.is_empty():
		return
	var valid_roots: Array[Node] = []
	for node in _ui_scale_roots:
		if node == null or not is_instance_valid(node):
			continue
		valid_roots.append(node)
		_apply_ui_scale_to_node(node, clamped_scale)
	_ui_scale_roots = valid_roots

func apply_window_size_preset(preset: String) -> void:
	var preset_resource: Resource = U_DISPLAY_OPTION_CATALOG.get_window_size_preset_by_id(preset)
	if preset_resource == null:
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
	var preset_resource: Resource = U_DISPLAY_OPTION_CATALOG.get_window_size_preset_by_id(preset)
	if preset_resource == null:
		return
	var size: Vector2i = Vector2i(0, 0)
	var size_value: Variant = preset_resource.get("size")
	if size_value is Vector2i:
		size = size_value
	if size == Vector2i.ZERO:
		return
	var ops := _get_window_ops()
	ops.window_set_size(size)
	var screen_size := ops.screen_get_size()
	var window_pos := (screen_size - size) / 2
	ops.window_set_position(window_pos)

func _set_window_mode_now(mode: String, attempt: int = 0) -> void:
	# macOS can abort if we attempt to change window style masks (borderless) while
	# fullscreen or while a fullscreen transition is still in progress.
	#
	# To avoid this, we:
	# - never toggle WINDOW_FLAG_BORDERLESS while already fullscreen
	# - when leaving fullscreen, we exit fullscreen first, then retry on a later frame
	#   before toggling style flags.
	if attempt > 8:
		push_warning("M_DisplayManager: Window mode '%s' did not settle after retries" % mode)
		return

	var ops := _get_window_ops()
	var current_mode := ops.window_get_mode()
	var is_fullscreen := current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var is_macos := ops.get_os_name() == "macOS"
	var is_borderless := ops.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)

	match mode:
		"fullscreen":
			# Enter fullscreen without touching style masks; macOS can crash on styleMask changes.
			if is_fullscreen:
				return
			ops.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			# Exit fullscreen first, then apply style flags on a later frame.
			if is_fullscreen:
				ops.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				call_deferred("_set_window_mode_now", mode, attempt + 1)
				return
			# Even after leaving fullscreen, macOS can still be mid-transition.
			# Give it an extra frame before touching the style mask.
			if is_macos and attempt == 1:
				_schedule_window_mode_retry_next_frame(mode, attempt + 1)
				return

			ops.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Avoid redundant style-mask changes; these can crash on macOS in some states.
			if not is_borderless:
				ops.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size := ops.screen_get_size()
			ops.window_set_size(screen_size)
			ops.window_set_position(Vector2i.ZERO)
		"windowed":
			# Exit fullscreen first, then apply style flags on a later frame.
			if is_fullscreen:
				ops.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				call_deferred("_set_window_mode_now", mode, attempt + 1)
				return
			# Even after leaving fullscreen, macOS can still be mid-transition.
			# Give it an extra frame before touching the style mask.
			if is_macos and attempt == 1:
				_schedule_window_mode_retry_next_frame(mode, attempt + 1)
				return

			ops.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Avoid redundant style-mask changes; these can crash on macOS in some states.
			if is_borderless:
				ops.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		_:
			push_warning("M_DisplayManager: Invalid window mode '%s'" % mode)

func _schedule_window_mode_retry_next_frame(mode: String, attempt: int) -> void:
	_window_mode_retry_frame = Engine.get_process_frames()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var timer := (main_loop as SceneTree).create_timer(0.0)
		timer.timeout.connect(_on_window_mode_retry.bind(mode, attempt))
		return
	call_deferred("_set_window_mode_now", mode, attempt)

func _on_window_mode_retry(mode: String, attempt: int) -> void:
	if Engine.get_process_frames() <= _window_mode_retry_frame:
		_schedule_window_mode_retry_next_frame(mode, attempt)
		return
	_set_window_mode_now(mode, attempt)

func _set_vsync_enabled_now(enabled: bool) -> void:
	var ops := _get_window_ops()
	if enabled:
		ops.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		ops.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

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
	var resource := U_DISPLAY_OPTION_CATALOG.get_quality_preset_by_id(preset)
	if resource == null:
		push_warning("M_DisplayManager: Unknown quality preset '%s'" % preset)
		return null
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
	var viewport := _get_render_target_viewport()
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

func _get_render_target_viewport() -> Viewport:
	var tree := get_tree()
	if tree != null and tree.root != null:
		var game_viewport := tree.root.find_child("GameViewport", true, false)
		if game_viewport is Viewport:
			return game_viewport as Viewport
	return get_viewport()

func _is_display_server_available() -> bool:
	var ops := _get_window_ops()
	if ops == null or not ops.is_available():
		return false

	if ops.is_real_window_backend() and Engine.is_editor_hint():
		# Window operations mutate the host window. In editor/GUT-in-editor runs this
		# targets the editor window and can crash on macOS.
		return false
	if ops.is_real_window_backend() and ops.get_os_name() == "macOS" and _is_gut_running():
		# GUT runs inside the editor binary; window style changes during tests can
		# crash macOS (NSWindow styleMask exceptions).
		return false

	return true

func _is_gut_running() -> bool:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	return tree.root.find_child("GutRunner", true, false) != null

func _is_rendering_available() -> bool:
	return not (OS.has_feature("headless") or OS.has_feature("server"))

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

func _ensure_post_process_layer() -> bool:
	if _post_process_layer != null:
		return true
	_setup_post_process_overlay()
	return _post_process_layer != null

func _setup_post_process_overlay() -> void:
	if _post_process_overlay != null and is_instance_valid(_post_process_overlay):
		_post_process_layer = U_POST_PROCESS_LAYER.new()
		_post_process_layer.initialize(_post_process_overlay)
		_update_overlay_visibility()
		return

	var tree := get_tree()
	if tree != null:
		# PostProcessOverlay is now inside GameViewport, not directly in root
		var existing := tree.root.find_child("PostProcessOverlay", true, false)
		if existing is Node:
			_post_process_overlay = existing
		elif existing != null:
			push_warning("M_DisplayManager: PostProcessOverlay found but is not a Node")

	if _post_process_overlay == null:
		# Fallback: try to find GameViewport and add overlay there
		var game_viewport := tree.root.find_child("GameViewport", true, false) as SubViewport
		if game_viewport == null:
			push_error("M_DisplayManager: GameViewport not found, cannot add post-process overlay")
			return

		var overlay_scene: PackedScene = POST_PROCESS_OVERLAY_SCENE
		if overlay_scene == null:
			push_error("M_DisplayManager: Failed to load post-process overlay scene")
			return
		var overlay_instance := overlay_scene.instantiate()
		if overlay_instance is Node:
			_post_process_overlay = overlay_instance
			game_viewport.add_child(_post_process_overlay)
		else:
			push_error("M_DisplayManager: Post-process overlay root is not a Node")
			return

	_post_process_layer = U_POST_PROCESS_LAYER.new()
	_post_process_layer.initialize(_post_process_overlay)
	_update_overlay_visibility()

func _get_color_blind_mode_value(mode: String) -> int:
	match mode:
		"deuteranopia":
			return 1
		"protanopia":
			return 2
		"tritanopia":
			return 3
	return 0

func _is_hex_string(value: String) -> bool:
	var length := value.length()
	for i in length:
		var code := value.unicode_at(i)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 70
		var is_lower := code >= 97 and code <= 102
		if not (is_digit or is_upper or is_lower):
			return false
	return true

func _apply_ui_scale_to_node(node: Node, scale: float) -> void:
	if node is CanvasLayer:
		_apply_font_scale_to_tree(node, scale)
		return
	if node is Control:
		# Safe area padding disabled - it interferes with fullscreen overlays
		# UI elements should use proper anchors instead
		_apply_font_scale_to_tree(node, scale)
		return
	_apply_font_scale_to_tree(node, scale)

func _apply_font_scale_to_tree(node: Node, scale: float) -> void:
	if node == null:
		return
	if node is Control:
		_apply_font_scale_to_control(node as Control, scale)
	var children: Array = node.get_children()
	for child in children:
		if child is Node:
			_apply_font_scale_to_tree(child, scale)

func _apply_font_scale_to_control(control: Control, scale: float) -> void:
	if control == null:
		return
	var base_size: int = _get_font_base_size(control)
	if base_size <= 0:
		return
	var scaled_size: int = int(round(float(base_size) * scale))
	if scaled_size <= 0:
		scaled_size = 1
	control.add_theme_font_size_override("font_size", scaled_size)

func _get_font_base_size(control: Control) -> int:
	if control == null:
		return 0
	var meta_key: StringName = StringName("ui_scale_font_base")
	if control.has_meta(meta_key):
		return int(control.get_meta(meta_key))
	var base_size: int = control.get_theme_font_size("font_size")
	control.set_meta(meta_key, base_size)
	return base_size

func _get_viewport_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var viewport: Viewport = control.get_viewport()
	if viewport == null:
		return Rect2()
	return viewport.get_visible_rect()

func _get_safe_area_rect(viewport_rect: Rect2) -> Rect2:
	if viewport_rect.size == Vector2.ZERO:
		return viewport_rect
	if not _is_display_server_available():
		return viewport_rect
	var ops := _get_window_ops()
	if ops.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and not OS.has_feature("mobile"):
		return viewport_rect
	var screen: int = ops.window_get_current_screen()
	var safe_rect_i: Rect2i = ops.screen_get_usable_rect(screen)
	if safe_rect_i.size == Vector2i.ZERO:
		return viewport_rect
	var safe_rect: Rect2 = Rect2(Vector2(safe_rect_i.position), Vector2(safe_rect_i.size))
	var viewport_bounds: Rect2 = Rect2(Vector2.ZERO, viewport_rect.size)
	var clamped: Rect2 = safe_rect.intersection(viewport_bounds)
	if clamped.size == Vector2.ZERO:
		return viewport_rect
	return clamped

func _apply_safe_area_padding(control: Control, viewport_size: Vector2, safe_rect: Rect2) -> void:
	if control == null:
		return
	if not _is_full_anchor(control):
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var left: float = max(safe_rect.position.x, 0.0)
	var top: float = max(safe_rect.position.y, 0.0)
	var right: float = max(viewport_size.x - (safe_rect.position.x + safe_rect.size.x), 0.0)
	var bottom: float = max(viewport_size.y - (safe_rect.position.y + safe_rect.size.y), 0.0)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = -right
	control.offset_bottom = -bottom

func _is_full_anchor(control: Control) -> bool:
	return is_equal_approx(control.anchor_left, 0.0) \
		and is_equal_approx(control.anchor_top, 0.0) \
		and is_equal_approx(control.anchor_right, 1.0) \
		and is_equal_approx(control.anchor_bottom, 1.0)

func _get_window_ops() -> I_WindowOps:
	if window_ops != null:
		return window_ops
	if _window_ops == null:
		_window_ops = U_DISPLAY_SERVER_WINDOW_OPS.new()
	return _window_ops

func register_ui_scale_root(node: Node) -> void:
	if node == null:
		return
	if _ui_scale_roots.has(node):
		return
	_ui_scale_roots.append(node)
	_apply_ui_scale_to_node(node, _current_ui_scale)
	_apply_ui_theme_to_node(node)

func unregister_ui_scale_root(node: Node) -> void:
	if node == null:
		return
	_ui_scale_roots.erase(node)

func _apply_ui_theme_from_palette(palette: Resource) -> void:
	if palette == null:
		return
	if not (palette is RS_UI_COLOR_PALETTE):
		return
	var typed_palette := palette as RS_UI_COLOR_PALETTE
	if _ui_theme == null:
		_ui_theme = Theme.new()
	var should_update := _ui_theme_palette_id != typed_palette.palette_id
	if should_update:
		_configure_ui_theme(_ui_theme, typed_palette)
		_ui_theme_palette_id = typed_palette.palette_id
	_apply_ui_theme_to_roots()

func _configure_ui_theme(theme: Theme, palette: RS_UI_COLOR_PALETTE) -> void:
	var text_color := palette.text
	var text_types: Array[String] = [
		"Label",
		"Button",
		"CheckBox",
		"OptionButton",
		"LineEdit",
		"RichTextLabel",
	]
	for type_name in text_types:
		theme.set_color("font_color", type_name, text_color)

func _apply_ui_theme_to_roots() -> void:
	if _ui_theme == null:
		return
	if _ui_scale_roots.is_empty():
		return
	var valid_roots: Array[Node] = []
	for node in _ui_scale_roots:
		if node == null or not is_instance_valid(node):
			continue
		valid_roots.append(node)
		_apply_ui_theme_to_node(node)
	_ui_scale_roots = valid_roots

func _apply_ui_theme_to_node(node: Node) -> void:
	if node == null or _ui_theme == null:
		return
	if node is Control:
		var control := node as Control
		if control.theme == null or control.theme == _ui_theme:
			control.theme = _ui_theme
	var children: Array = node.get_children()
	for child in children:
		if child is Node:
			_apply_ui_theme_to_node(child)

func _update_overlay_visibility() -> void:
	if _post_process_overlay == null or not is_instance_valid(_post_process_overlay):
		return
	if _state_store == null:
		return

	var state := _state_store.get_state()
	var navigation_state: Dictionary = state.get("navigation", {})
	var shell := U_NAVIGATION_SELECTORS.get_shell(navigation_state)
	var should_show := shell == SHELL_GAMEPLAY

	# The overlay root is a Node, so we need to hide/show its CanvasLayer children
	for child in _post_process_overlay.get_children():
		if child is CanvasLayer:
			child.visible = should_show
