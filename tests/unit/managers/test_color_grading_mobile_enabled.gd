extends GutTest

## Tests for U_DisplayColorGradingApplier mobile behavior.
## Color grading is now active on mobile; sharpness override remains disabled
## on mobile (5-tap unsharp mask is too expensive on tile-based GPUs).

const U_COLOR_GRADING_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_color_grading_applier.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/core/utils/display/u_mobile_platform_detector.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const COLOR_GRADING_SHADER := preload("res://assets/shaders/sh_color_grading_shader.gdshader")

var _overlay: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)

	# Build overlay and register in service locator so the applier can find it
	_overlay = Node.new()
	_overlay.name = "PostProcessOverlay"
	add_child_autofree(_overlay)
	U_SERVICE_LOCATOR.register(StringName("post_process_overlay"), _overlay)

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_MOBILE_PLATFORM_DETECTOR.set_testing(false)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)

# Creates an applier initialized in the given mode, with a pre-existing ColorGradingLayer
func _setup_applier(mobile_override: int) -> Dictionary:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(mobile_override)

	# Pre-create the ColorGradingLayer in the overlay so the applier can find it
	var layer := CanvasLayer.new()
	layer.name = "ColorGradingLayer"
	layer.layer = 1
	layer.follow_viewport_enabled = true

	var material := ShaderMaterial.new()
	material.shader = COLOR_GRADING_SHADER

	var rect := ColorRect.new()
	rect.name = "ColorGradingRect"
	rect.material = material
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	layer.add_child(rect)
	_overlay.add_child(layer)

	var applier := U_COLOR_GRADING_APPLIER.new()
	applier.initialize(null, null)

	return {"applier": applier, "layer": layer}

# --- Desktop behavior ---

func test_desktop_update_visibility_shows_layer() -> void:
	var result := _setup_applier(0)
	var applier: U_DisplayColorGradingApplier = result["applier"]
	var layer: CanvasLayer = result["layer"]

	applier.update_visibility(true)
	assert_true(layer.visible,
		"ColorGradingLayer should be visible on desktop when should_show=true")

func test_desktop_update_visibility_hides_layer() -> void:
	var result := _setup_applier(0)
	var applier: U_DisplayColorGradingApplier = result["applier"]
	var layer: CanvasLayer = result["layer"]

	layer.visible = true  # start visible
	applier.update_visibility(false)
	assert_false(layer.visible,
		"ColorGradingLayer should be hidden on desktop when should_show=false")

# --- Mobile behavior: color grading is now enabled on mobile ---

func test_mobile_update_visibility_shows_layer_when_should_show() -> void:
	var result := _setup_applier(1)
	var applier: U_DisplayColorGradingApplier = result["applier"]
	var layer: CanvasLayer = result["layer"]

	applier.update_visibility(true)
	assert_true(layer.visible,
		"ColorGradingLayer should be visible on mobile when should_show=true")

func test_mobile_update_visibility_hides_layer_when_should_hide() -> void:
	var result := _setup_applier(1)
	var applier: U_DisplayColorGradingApplier = result["applier"]
	var layer: CanvasLayer = result["layer"]

	applier.update_visibility(false)
	assert_false(layer.visible,
		"ColorGradingLayer should be hidden on mobile when should_show=false")

func test_mobile_apply_settings_creates_layer() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	var applier := U_COLOR_GRADING_APPLIER.new()
	applier.initialize(null, null)

	# apply_settings on mobile should now create the layer and apply uniforms
	applier.apply_settings({})

	var layer := _overlay.find_child("ColorGradingLayer", false, false)
	assert_not_null(layer,
		"ColorGradingLayer should be created on mobile (color grading is now enabled)")
