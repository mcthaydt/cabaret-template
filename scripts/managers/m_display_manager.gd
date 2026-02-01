@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_display_manager.gd"
class_name M_DisplayManager

## Display Manager - applies display settings from Redux display slice.
## Phase 1B: Scaffolding for store subscription + preview mode.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_POST_PROCESS_LAYER := preload("res://scripts/managers/helpers/u_post_process_layer.gd")
const RS_QUALITY_PRESET := preload("res://scripts/resources/display/rs_quality_preset.gd")
const RS_LUT_DEFINITION := preload("res://scripts/resources/display/rs_lut_definition.gd")
const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")

const SERVICE_NAME := StringName("display_manager")
const DISPLAY_SLICE_NAME := StringName("display")
const UI_SCALABLE_GROUP := StringName("ui_scalable")

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
const MIN_UI_SCALE := 0.5
const MAX_UI_SCALE := 2.0

## Injected dependency (tests)
@export var state_store: I_StateStore = null

var _state_store: I_StateStore = null
var _last_display_hash: int = 0
var _display_settings_preview_active: bool = false
var _preview_settings: Dictionary = {}
var _quality_preset_cache: Dictionary = {}
var _current_ui_scale: float = 1.0

# Post-process overlay (Phase 3C)
var _post_process_layer: U_PostProcessLayer = null
var _post_process_overlay: CanvasLayer = null
var _film_grain_active: bool = false

# Cached values for inspection/tests (Phase 1B)
var _last_applied_settings: Dictionary = {}
var _apply_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(SERVICE_NAME)
	U_SERVICE_LOCATOR.register(SERVICE_NAME, self)

	var tree := get_tree()
	if tree != null and not tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.connect(_on_tree_node_added)

	await _initialize_store_async()

func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.disconnect(_on_tree_node_added)
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
	_apply_post_process_settings(effective_settings)
	_apply_ui_scale_settings(effective_settings)

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

func _apply_ui_scale_settings(display_settings: Dictionary) -> void:
	var state := {"display": display_settings}
	var scale := U_DISPLAY_SELECTORS.get_ui_scale(state)
	set_ui_scale(scale)

func _apply_post_process_settings(display_settings: Dictionary) -> void:
	if not _ensure_post_process_layer():
		return
	var state := {"display": display_settings}
	_apply_film_grain_settings(state)
	_apply_outline_settings(state)
	_apply_dither_settings(state)
	_apply_lut_settings(state)

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

func _apply_outline_settings(state: Dictionary) -> void:
	var enabled := U_DISPLAY_SELECTORS.is_outline_enabled(state)
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_OUTLINE, enabled)
	var thickness := U_DISPLAY_SELECTORS.get_outline_thickness(state)
	var outline_color := _parse_outline_color(U_DISPLAY_SELECTORS.get_outline_color(state))
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_OUTLINE,
		StringName("thickness"),
		thickness
	)
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_OUTLINE,
		StringName("outline_color"),
		outline_color
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
	if resource == null or not (resource is RS_LUT_DEFINITION):
		push_warning("M_DisplayManager: Invalid LUT resource '%s'" % lut_path)
		return
	var definition := resource as RS_LUT_DEFINITION
	if definition.texture == null:
		push_warning("M_DisplayManager: LUT texture missing for '%s'" % lut_path)
		return
	_post_process_layer.set_effect_parameter(
		U_POST_PROCESS_LAYER.EFFECT_LUT,
		StringName("lut_texture"),
		definition.texture
	)

func set_ui_scale(scale: float) -> void:
	var clamped_scale := clampf(scale, MIN_UI_SCALE, MAX_UI_SCALE)
	_current_ui_scale = clamped_scale
	var tree := get_tree()
	if tree == null:
		return
	var ui_nodes := tree.get_nodes_in_group(UI_SCALABLE_GROUP)
	for node in ui_nodes:
		if not _is_group_root(node, UI_SCALABLE_GROUP):
			continue
		_apply_ui_scale_to_node(node, clamped_scale)

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

func _ensure_post_process_layer() -> bool:
	if _post_process_layer != null:
		return true
	_setup_post_process_overlay()
	return _post_process_layer != null

func _setup_post_process_overlay() -> void:
	if _post_process_overlay != null and is_instance_valid(_post_process_overlay):
		_post_process_layer = U_POST_PROCESS_LAYER.new()
		_post_process_layer.initialize(_post_process_overlay)
		return

	var tree := get_tree()
	if tree != null:
		var existing := tree.root.find_child("PostProcessOverlay", true, false)
		if existing is CanvasLayer:
			_post_process_overlay = existing
		elif existing != null:
			push_warning("M_DisplayManager: PostProcessOverlay found but is not a CanvasLayer")

	if _post_process_overlay == null:
		var overlay_scene: PackedScene = POST_PROCESS_OVERLAY_SCENE
		if overlay_scene == null:
			push_error("M_DisplayManager: Failed to load post-process overlay scene")
			return
		var overlay_instance := overlay_scene.instantiate()
		if overlay_instance is CanvasLayer:
			_post_process_overlay = overlay_instance
			add_child(_post_process_overlay)
		else:
			push_error("M_DisplayManager: Post-process overlay root is not a CanvasLayer")
			return

	_post_process_layer = U_POST_PROCESS_LAYER.new()
	_post_process_layer.initialize(_post_process_overlay)

func _parse_outline_color(hex_value: String) -> Color:
	var value := hex_value.strip_edges()
	if value.is_empty():
		return Color(0, 0, 0, 1)
	if value.begins_with("#"):
		value = value.substr(1)
	if value.length() != 6 and value.length() != 8:
		return Color(0, 0, 0, 1)
	if not _is_hex_string(value):
		return Color(0, 0, 0, 1)

	var r: int = value.substr(0, 2).hex_to_int()
	var g: int = value.substr(2, 2).hex_to_int()
	var b: int = value.substr(4, 2).hex_to_int()
	var a: int = 255
	if value.length() == 8:
		a = value.substr(6, 2).hex_to_int()
	return Color8(r, g, b, a)

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

func _on_tree_node_added(node: Node) -> void:
	if node == null or not node.is_in_group(UI_SCALABLE_GROUP):
		return
	if not _is_group_root(node, UI_SCALABLE_GROUP):
		return
	_apply_ui_scale_to_node(node, _current_ui_scale)

func _apply_ui_scale_to_node(node: Node, scale: float) -> void:
	if node is CanvasLayer:
		var layer := node as CanvasLayer
		layer.transform = Transform2D().scaled(Vector2(scale, scale))
		return
	if node is Control:
		var control := node as Control
		control.scale = Vector2(scale, scale)
		return
	if node is Node2D:
		var node_2d := node as Node2D
		node_2d.scale = Vector2(scale, scale)

func _is_group_root(node: Node, group_name: StringName) -> bool:
	if node == null:
		return false
	var parent := node.get_parent()
	while parent != null:
		if parent.is_in_group(group_name):
			return false
		parent = parent.get_parent()
	return true
