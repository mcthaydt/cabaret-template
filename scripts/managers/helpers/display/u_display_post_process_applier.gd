extends RefCounted

## Applies post-process settings to the display overlay.

const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_POST_PROCESS_LAYER := preload("res://scripts/managers/helpers/u_post_process_layer.gd")
const RS_LUT_DEFINITION := preload("res://scripts/resources/display/rs_lut_definition.gd")
const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")

var _owner: Node = null
var _post_process_layer: U_PostProcessLayer = null
var _post_process_overlay: Node = null
var _film_grain_active: bool = false

func initialize(owner: Node) -> void:
	_owner = owner

func apply_settings(display_settings: Dictionary) -> void:
	if not _ensure_post_process_layer():
		return
	var state := {"display": display_settings}
	_apply_film_grain_settings(state)
	_apply_crt_settings(state)
	_apply_dither_settings(state)
	_apply_lut_settings(state)
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
	for child in _post_process_overlay.get_children():
		if child is CanvasLayer:
			child.visible = should_show

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
		push_warning("U_DisplayPostProcessApplier: Failed to load LUT resource '%s'" % lut_path)
		return

	var lut_texture: Texture2D = null
	if resource is Texture2D:
		lut_texture = resource as Texture2D
	elif resource is RS_LUT_DEFINITION:
		var definition := resource as RS_LUT_DEFINITION
		if definition.texture == null:
			push_warning("U_DisplayPostProcessApplier: LUT texture missing for '%s'" % lut_path)
			return
		lut_texture = definition.texture
	else:
		push_warning("U_DisplayPostProcessApplier: Invalid LUT resource '%s' (expected Texture2D or RS_LUTDefinition)" % lut_path)
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
