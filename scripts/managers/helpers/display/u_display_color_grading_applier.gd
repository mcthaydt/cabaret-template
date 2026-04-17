extends RefCounted
class_name U_DisplayColorGradingApplier

## Applies per-scene color grading settings via a shader overlay.
##
## Creates a ColorGradingLayer (CanvasLayer 1) inside PostProcessOverlay and
## listens for scene/transition_completed to swap color gradings automatically.
## Sharpness is disabled on mobile (5-tap unsharp mask is too expensive on tile-based GPUs)
## but the color grading pass itself runs on all platforms.

const COLOR_GRADING_SHADER := preload("res://assets/shaders/sh_color_grading_shader.gdshader")
const U_CANVAS_LAYERS := preload("res://scripts/ui/u_canvas_layers.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_POST_PROCESS_PIPELINE := preload("res://scripts/managers/helpers/display/u_post_process_pipeline.gd")

const SCENE_SWAPPED := StringName("scene/swapped")

var _owner: Node = null
var _state_store: I_StateStore = null
var _color_grading_layer: CanvasLayer = null
var _color_grading_rect: ColorRect = null
var _shader_material: ShaderMaterial = null
var _is_mobile: bool = false
var _pipeline: U_PostProcessPipeline = null

func set_pipeline(pipeline: U_PostProcessPipeline) -> void:
	_pipeline = pipeline

func initialize(owner: Node, state_store: I_StateStore) -> void:
	_owner = owner
	_state_store = state_store
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	U_ColorGradingRegistry.initialize()

	if _state_store != null and _state_store.has_signal("action_dispatched"):
		_state_store.action_dispatched.connect(_on_action_dispatched)

func apply_settings(display_settings: Dictionary) -> void:
	if not _ensure_color_grading_layer():
		return
	var state := {"display": display_settings}
	_apply_color_grading_uniforms(state)

func update_visibility(should_show: bool) -> void:
	if not _ensure_color_grading_layer():
		return
	if _pipeline != null:
		_pipeline.set_pass_visible(&"color_grading", should_show)
	else:
		_color_grading_layer.visible = should_show

## Mobile debug: force-disable the color grading shader pass.
## Returns true if the layer was previously visible (i.e., this changed something).
func debug_force_disable() -> bool:
	if _color_grading_layer == null or not is_instance_valid(_color_grading_layer):
		return false
	var was_visible: bool = _color_grading_layer.visible
	if _pipeline != null:
		_pipeline.set_pass_visible(&"color_grading", false)
	else:
		_color_grading_layer.visible = false
	return was_visible

## Mobile debug: restore the color grading layer to its normal visibility state.
func debug_restore_visibility(should_show: bool) -> void:
	if _color_grading_layer != null and is_instance_valid(_color_grading_layer):
		if _pipeline != null:
			_pipeline.set_pass_visible(&"color_grading", should_show)
		else:
			_color_grading_layer.visible = should_show

func cleanup() -> void:
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		if _state_store.action_dispatched.is_connected(_on_action_dispatched):
			_state_store.action_dispatched.disconnect(_on_action_dispatched)
	_state_store = null

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: Variant = action.get("type", "")
	if action_type != SCENE_SWAPPED:
		return
	var payload: Dictionary = action.get("payload", {})
	var scene_id: Variant = payload.get("scene_id", "")
	if scene_id is StringName or scene_id is String:
		_load_grade_for_scene(StringName(str(scene_id)))

func _load_grade_for_scene(scene_id: StringName) -> void:
	if _state_store == null:
		return
	var grade := U_ColorGradingRegistry.get_color_grading_for_scene(scene_id)
	_state_store.dispatch(U_ColorGradingActions.load_scene_grade(grade.to_dictionary()))

func _apply_color_grading_uniforms(state: Dictionary) -> void:
	if _shader_material == null:
		return

	_shader_material.set_shader_parameter("filter_mode", U_ColorGradingSelectors.get_filter_mode(state))
	_shader_material.set_shader_parameter("filter_intensity", U_ColorGradingSelectors.get_filter_intensity(state))
	_shader_material.set_shader_parameter("exposure", U_ColorGradingSelectors.get_exposure(state))
	_shader_material.set_shader_parameter("brightness", U_ColorGradingSelectors.get_brightness(state))
	_shader_material.set_shader_parameter("contrast", U_ColorGradingSelectors.get_contrast(state))
	_shader_material.set_shader_parameter("brilliance", U_ColorGradingSelectors.get_brilliance(state))
	_shader_material.set_shader_parameter("highlights", U_ColorGradingSelectors.get_highlights(state))
	_shader_material.set_shader_parameter("shadows", U_ColorGradingSelectors.get_shadows(state))
	_shader_material.set_shader_parameter("saturation", U_ColorGradingSelectors.get_saturation(state))
	_shader_material.set_shader_parameter("vibrance", U_ColorGradingSelectors.get_vibrance(state))
	_shader_material.set_shader_parameter("warmth", U_ColorGradingSelectors.get_warmth(state))
	_shader_material.set_shader_parameter("tint", U_ColorGradingSelectors.get_tint(state))
	_shader_material.set_shader_parameter("sharpness", U_ColorGradingSelectors.get_sharpness(state))

	# Mobile override: force-disable sharpness (5-tap unsharp mask is too expensive on tile-based GPUs)
	if _is_mobile:
		_shader_material.set_shader_parameter("sharpness", 0.0)

func _ensure_color_grading_layer() -> bool:
	if _color_grading_layer != null and is_instance_valid(_color_grading_layer):
		return true
	_setup_color_grading_layer()
	return _color_grading_layer != null

func _setup_color_grading_layer() -> void:
	var post_process_overlay := U_SERVICE_LOCATOR.try_get_service(StringName("post_process_overlay")) as Node
	if post_process_overlay == null:
		return

	# Check if already exists
	var existing := post_process_overlay.find_child("ColorGradingLayer", false, false)
	if existing is CanvasLayer:
		_color_grading_layer = existing as CanvasLayer
		var rect := _color_grading_layer.find_child("ColorGradingRect", false, false)
		if rect is ColorRect:
			_color_grading_rect = rect as ColorRect
			_shader_material = _color_grading_rect.material as ShaderMaterial
		if _pipeline != null and _color_grading_rect != null:
			_pipeline.register_pass(&"color_grading", _color_grading_rect, COLOR_GRADING_SHADER)
		return

	# Create ColorGradingLayer below the authored post-process layers.
	_color_grading_layer = CanvasLayer.new()
	_color_grading_layer.name = "ColorGradingLayer"
	_color_grading_layer.layer = U_CANVAS_LAYERS.PP_COLOR_GRADING
	_color_grading_layer.follow_viewport_enabled = true

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = COLOR_GRADING_SHADER

	_color_grading_rect = ColorRect.new()
	_color_grading_rect.name = "ColorGradingRect"
	_color_grading_rect.material = _shader_material
	_color_grading_rect.anchors_preset = Control.PRESET_FULL_RECT
	_color_grading_rect.anchor_right = 1.0
	_color_grading_rect.anchor_bottom = 1.0
	_color_grading_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_color_grading_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_color_grading_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_color_grading_layer.add_child(_color_grading_rect)
	post_process_overlay.add_child(_color_grading_layer)
	if _pipeline != null:
		_pipeline.register_pass(&"color_grading", _color_grading_rect, COLOR_GRADING_SHADER)