extends RefCounted
class_name U_DisplayPostProcessApplier

## Applies post-process settings to the display overlay.
## Uses a grain + dither shader for post-processing effects (one screen texture sample).

const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/utils/display/u_display_option_catalog.gd")
const U_POST_PROCESS_LAYER := preload("res://scripts/core/managers/helpers/display/u_post_process_layer.gd")
const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")
const U_CANVAS_LAYERS := preload("res://scripts/ui/u_canvas_layers.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_POST_PROCESS_PIPELINE := preload("res://scripts/core/managers/helpers/display/u_post_process_pipeline.gd")

var _owner: Node = null
var _post_process_layer: U_PostProcessLayer = null
var _post_process_overlay: Node = null
var _any_effect_active: bool = false
var _is_mobile: bool = false
var _pipeline: U_PostProcessPipeline = null
var _ui_color_blind_layer: CanvasLayer = null
var _ui_color_blind_rect: ColorRect = null

func set_pipeline(pipeline: U_PostProcessPipeline) -> void:
	_pipeline = pipeline

func initialize(owner: Node) -> void:
	_owner = owner
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
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
	_apply_grain_dither_effect_settings(state)
	_apply_color_blind_shader_settings(state)

func update_overlay_visibility(should_show: bool) -> void:
	if _post_process_overlay == null or not is_instance_valid(_post_process_overlay):
		return

	# The overlay root is a Node, so we need to hide/show its CanvasLayer children.
	# Skip ColorGradingLayer — its visibility is managed by U_DisplayColorGradingApplier.
	for child in _post_process_overlay.get_children():
		if child is CanvasLayer and child.name != &"ColorGradingLayer":
			child.visible = should_show

func _apply_grain_dither_effect_settings(state: Dictionary) -> void:
	var fg_enabled := U_DISPLAY_SELECTORS.is_film_grain_enabled(state)
	var dither_enabled := U_DISPLAY_SELECTORS.is_dither_enabled(state)
	var scanlines := U_DISPLAY_SELECTORS.is_scanlines_enabled(state)

	_any_effect_active = fg_enabled or dither_enabled or scanlines

	if not _any_effect_active:
		return

	# Set per-effect enable flags in the grain+dither shader
	_post_process_layer.set_grain_dither_parameter(StringName("film_grain_enabled"), 1 if fg_enabled else 0)
	_post_process_layer.set_grain_dither_parameter(StringName("dither_enabled"), 1 if dither_enabled else 0)
	_post_process_layer.set_grain_dither_parameter(StringName("scanlines_enabled"), 1 if scanlines else 0)

	# Film grain params
	if fg_enabled:
		var intensity := U_DISPLAY_SELECTORS.get_film_grain_intensity(state)
		_post_process_layer.set_grain_dither_parameter(StringName("fg_intensity"), intensity)

	# Dither params
	if dither_enabled:
		var intensity := U_DISPLAY_SELECTORS.get_dither_intensity(state)
		_post_process_layer.set_grain_dither_parameter(StringName("dither_intensity"), intensity)

	# Scanline params
	if scanlines:
		var intensity := U_DISPLAY_SELECTORS.get_line_mask_intensity(state)
		var count := U_DISPLAY_SELECTORS.get_scanline_count(state)
		_post_process_layer.set_grain_dither_parameter(StringName("line_mask_intensity"), intensity)
		_post_process_layer.set_grain_dither_parameter(StringName("scanline_count"), count)

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

func _disable_post_process_effects() -> void:
	_any_effect_active = false

func _ensure_post_process_layer() -> bool:
	if _post_process_layer != null:
		return true
	_setup_post_process_overlay()
	return _post_process_layer != null

func _setup_post_process_overlay() -> void:
	if _post_process_overlay != null and is_instance_valid(_post_process_overlay):
		_post_process_layer = U_POST_PROCESS_LAYER.new()
		_post_process_layer.initialize(_post_process_overlay)
		_register_grain_dither_pass()
		return

	var existing := U_SERVICE_LOCATOR.try_get_service(StringName("post_process_overlay"))
	if existing is Node:
		_post_process_overlay = existing
	elif existing != null:
		push_warning("U_DisplayPostProcessApplier: post_process_overlay service is not a Node")

	if _post_process_overlay == null:
		# Fallback: add overlay under the registered gameplay viewport.
		var game_viewport := U_SERVICE_LOCATOR.try_get_service(StringName("game_viewport")) as SubViewport
		if game_viewport == null:
			push_warning("U_DisplayPostProcessApplier: game_viewport service not found, cannot add post-process overlay")
			return

		var overlay_scene: PackedScene = POST_PROCESS_OVERLAY_SCENE
		if overlay_scene == null:
			push_error("U_DisplayPostProcessApplier: Failed to load post-process overlay scene")
			return
		var overlay_instance := overlay_scene.instantiate()
		if overlay_instance is Node:
			_post_process_overlay = overlay_instance
			game_viewport.add_child(_post_process_overlay)
			U_SERVICE_LOCATOR.register(StringName("post_process_overlay"), _post_process_overlay)
		else:
			push_error("U_DisplayPostProcessApplier: Post-process overlay root is not a Node")
			return

	_post_process_layer = U_POST_PROCESS_LAYER.new()
	_post_process_layer.initialize(_post_process_overlay)
	_register_grain_dither_pass()

func _register_grain_dither_pass() -> void:
	if _pipeline == null or _post_process_layer == null:
		return
	var grain_rect := _post_process_layer.get_grain_dither_rect()
	if grain_rect == null:
		return
	var grain_mat := grain_rect.material as ShaderMaterial
	var grain_shader: Shader = grain_mat.shader if grain_mat != null else null
	_pipeline.register_pass(&"grain_dither", grain_rect, grain_shader)

func _get_color_blind_mode_value(mode: String) -> int:
	match mode:
		"deuteranopia":
			return 1
		"protanopia":
			return 2
		"tritanopia":
			return 3
	return 0

func _setup_ui_color_blind_layer() -> void:
	var tree := U_DisplayApplierUtils.get_tree_safe(_owner)
	if tree == null or tree.root == null:
		push_warning("U_DisplayPostProcessApplier: Cannot setup UI color blind layer, tree/root not available")
		return

	# Check if already exists
	var existing := tree.root.find_child("UIColorBlindLayer", false, false)
	if existing is CanvasLayer:
		_ui_color_blind_layer = existing as CanvasLayer
		_ui_color_blind_rect = _ui_color_blind_layer.find_child("ColorBlindRect", false, false) as ColorRect
		return

	# Create UI color blind layer above UIOverlayStack.
	_ui_color_blind_layer = CanvasLayer.new()
	_ui_color_blind_layer.name = "UIColorBlindLayer"
	_ui_color_blind_layer.layer = U_CANVAS_LAYERS.UI_COLOR_BLIND

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

## Mobile debug: force-disable the grain+dither post-process shader pass.
## Returns true if the grain+dither rect was previously visible.
func debug_force_disable_grain_dither() -> bool:
	_ensure_post_process_layer()
	if _post_process_layer == null:
		return false
	var grain_dither_rect := _post_process_layer.get_grain_dither_rect()
	if grain_dither_rect == null:
		return false
	var was_visible: bool = grain_dither_rect.visible
	if _pipeline != null:
		_pipeline.set_pass_visible(&"grain_dither", false)
	else:
		grain_dither_rect.visible = false
	return was_visible

## Mobile debug: restore the grain+dither post-process rect visibility.
func debug_restore_grain_dither_visibility(visible: bool) -> void:
	_ensure_post_process_layer()
	if _post_process_layer == null:
		return
	if _pipeline != null:
		_pipeline.set_pass_visible(&"grain_dither", visible)
	else:
		_post_process_layer.set_grain_dither_visible(visible)
