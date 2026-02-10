extends RefCounted
class_name U_DisplayPostProcessApplier

## Applies post-process settings to the display overlay.

const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/utils/display/u_display_option_catalog.gd")
const U_POST_PROCESS_LAYER := preload("res://scripts/managers/helpers/u_post_process_layer.gd")
const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")

var _owner: Node = null
var _post_process_layer: U_PostProcessLayer = null
var _post_process_overlay: Node = null
var _film_grain_active: bool = false
var _ui_color_blind_layer: CanvasLayer = null
var _ui_color_blind_rect: ColorRect = null

func initialize(owner: Node) -> void:
	_owner = owner
	if owner != null and owner.is_inside_tree():
		_setup_ui_color_blind_layer()

func apply_settings(display_settings: Dictionary) -> void:
	if not _ensure_post_process_layer():
		return
	var state := {"display": display_settings}
	var post_processing_enabled := U_DISPLAY_SELECTORS.is_post_processing_enabled(state)
	if not post_processing_enabled:
		_disable_post_process_effects()
		_apply_color_blind_shader_settings(state)
		return
	_apply_film_grain_settings(state)
	_apply_crt_settings(state)
	_apply_dither_settings(state)
	_apply_color_blind_shader_settings(state)

func process_film_grain_time() -> void:
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

func update_overlay_visibility(should_show: bool) -> void:
	if _post_process_overlay == null or not is_instance_valid(_post_process_overlay):
		return

	# The overlay root is a Node, so we need to hide/show its CanvasLayer children.
	# Skip CinemaGradeLayer — its visibility is managed by U_DisplayCinemaGradeApplier.
	for child in _post_process_overlay.get_children():
		if child is CanvasLayer and child.name != &"CinemaGradeLayer":
			child.visible = should_show

func _apply_film_grain_settings(state: Dictionary) -> void:
	var enabled := U_DISPLAY_SELECTORS.is_film_grain_enabled(state)
	_film_grain_active = enabled
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN, enabled)
	if enabled:
		var intensity := U_DISPLAY_SELECTORS.get_film_grain_intensity(state)
		_post_process_layer.set_effect_parameter(
			U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN,
			StringName("intensity"),
			intensity
		)

func _apply_crt_settings(state: Dictionary) -> void:
	var enabled := U_DISPLAY_SELECTORS.is_crt_enabled(state)
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_CRT, enabled)
	if enabled:
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
	if enabled:
		var intensity := U_DISPLAY_SELECTORS.get_dither_intensity(state)
		_post_process_layer.set_effect_parameter(
			U_POST_PROCESS_LAYER.EFFECT_DITHER,
			StringName("intensity"),
			intensity
		)
		# Always use bayer pattern (simplified - no user customization)
		_post_process_layer.set_effect_parameter(
			U_POST_PROCESS_LAYER.EFFECT_DITHER,
			StringName("pattern_mode"),
			0
		)

func _apply_color_blind_shader_settings(state: Dictionary) -> void:
	var mode := U_DISPLAY_SELECTORS.get_color_blind_mode(state)
	var mode_value := _get_color_blind_mode_value(mode)
	var enabled := mode_value != 0 # Enabled if mode is not "normal"

	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_COLOR_BLIND, enabled)
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

	# Apply color blind filter to UI layer as well
	_apply_ui_color_blind_shader(enabled, mode_value)

func _is_post_processing_enabled(quality_preset: String) -> bool:
	if quality_preset.is_empty():
		return true
	var preset: Resource = U_DISPLAY_OPTION_CATALOG.get_quality_preset_by_id(quality_preset)
	if preset == null:
		return true
	var enabled_value: Variant = preset.get("post_processing_enabled")
	if enabled_value is bool:
		return enabled_value
	return true

func _disable_post_process_effects() -> void:
	_film_grain_active = false
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN, false)
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_CRT, false)
	_post_process_layer.set_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_DITHER, false)

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

	var tree := _get_tree()
	if tree == null or tree.root == null:
		return

	# PostProcessOverlay is now inside GameViewport, not directly in root.
	var existing := tree.root.find_child("PostProcessOverlay", true, false)
	if existing is Node:
		_post_process_overlay = existing
	elif existing != null:
		push_warning("U_DisplayPostProcessApplier: PostProcessOverlay found but is not a Node")

	if _post_process_overlay == null:
		# Fallback: try to find GameViewport and add overlay there.
		var game_viewport := tree.root.find_child("GameViewport", true, false) as SubViewport
		if game_viewport == null:
			push_error("U_DisplayPostProcessApplier: GameViewport not found, cannot add post-process overlay")
			return

		var overlay_scene: PackedScene = POST_PROCESS_OVERLAY_SCENE
		if overlay_scene == null:
			push_error("U_DisplayPostProcessApplier: Failed to load post-process overlay scene")
			return
		var overlay_instance := overlay_scene.instantiate()
		if overlay_instance is Node:
			_post_process_overlay = overlay_instance
			game_viewport.add_child(_post_process_overlay)
		else:
			push_error("U_DisplayPostProcessApplier: Post-process overlay root is not a Node")
			return

	_post_process_layer = U_POST_PROCESS_LAYER.new()
	_post_process_layer.initialize(_post_process_overlay)

func _get_color_blind_mode_value(mode: String) -> int:
	match mode:
		"deuteranopia":
			return 1
		"protanopia":
			return 2
		"tritanopia":
			return 3
	return 0

func _get_tree() -> SceneTree:
	if _owner != null:
		return _owner.get_tree()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop as SceneTree
	return null

func _setup_ui_color_blind_layer() -> void:
	var tree := _get_tree()
	if tree == null or tree.root == null:
		push_warning("U_DisplayPostProcessApplier: Cannot setup UI color blind layer, tree/root not available")
		return

	# Check if already exists
	var existing := tree.root.find_child("UIColorBlindLayer", false, false)
	if existing is CanvasLayer:
		_ui_color_blind_layer = existing as CanvasLayer
		_ui_color_blind_rect = _ui_color_blind_layer.find_child("ColorBlindRect", false, false) as ColorRect
		return

	# Create UI color blind layer (layer 11, above UIOverlayStack which is layer 10)
	_ui_color_blind_layer = CanvasLayer.new()
	_ui_color_blind_layer.name = "UIColorBlindLayer"
	_ui_color_blind_layer.layer = 11

	# Load the color blind shader
	var shader: Shader = load("res://assets/shaders/sh_colorblind_daltonize.gdshader")
	if shader == null:
		push_error("U_DisplayPostProcessApplier: Failed to load color blind shader")
		return

	# Create shader material
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("mode", 0)
	material.set_shader_parameter("intensity", 1.0)

	# Create ColorRect that covers the entire screen
	_ui_color_blind_rect = ColorRect.new()
	_ui_color_blind_rect.name = "ColorBlindRect"
	_ui_color_blind_rect.material = material
	_ui_color_blind_rect.anchors_preset = Control.PRESET_FULL_RECT
	_ui_color_blind_rect.anchor_right = 1.0
	_ui_color_blind_rect.anchor_bottom = 1.0
	_ui_color_blind_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui_color_blind_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui_color_blind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_color_blind_rect.visible = false

	# Add to scene tree
	_ui_color_blind_layer.add_child(_ui_color_blind_rect)
	tree.root.add_child.call_deferred(_ui_color_blind_layer)

func _apply_ui_color_blind_shader(enabled: bool, mode_value: int) -> void:
	if _ui_color_blind_rect == null or not is_instance_valid(_ui_color_blind_rect):
		return

	# Set visibility
	_ui_color_blind_rect.visible = enabled

	# Update shader parameters
	var material := _ui_color_blind_rect.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("mode", mode_value)
		material.set_shader_parameter("intensity", 1.0)
