extends GutTest

## Tests for U_DisplayCinemaGradeApplier mobile behavior.
## On mobile, the cinema grade layer should be force-hidden to eliminate
## the fullscreen shader pass that re-renders the scene at native resolution.

const U_CINEMA_GRADE_APPLIER := preload("res://scripts/managers/helpers/display/u_display_cinema_grade_applier.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const CINEMA_GRADE_SHADER := preload("res://assets/shaders/sh_cinema_grade_shader.gdshader")

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

# Creates an applier initialized in the given mode, with a pre-existing CinemaGradeLayer
func _setup_applier(mobile_override: int) -> Dictionary:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(mobile_override)

	# Pre-create the CinemaGradeLayer in the overlay so the applier can find it
	var layer := CanvasLayer.new()
	layer.name = "CinemaGradeLayer"
	layer.layer = 1
	layer.follow_viewport_enabled = true

	var material := ShaderMaterial.new()
	material.shader = CINEMA_GRADE_SHADER

	var rect := ColorRect.new()
	rect.name = "CinemaGradeRect"
	rect.material = material
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	layer.add_child(rect)
	_overlay.add_child(layer)

	var applier := U_CINEMA_GRADE_APPLIER.new()
	applier.initialize(null, null)

	return {"applier": applier, "layer": layer}

# --- Desktop behavior ---

func test_desktop_update_visibility_shows_layer() -> void:
	var result := _setup_applier(0)
	var applier: U_DisplayCinemaGradeApplier = result["applier"]
	var layer: CanvasLayer = result["layer"]

	applier.update_visibility(true)
	assert_true(layer.visible,
		"CinemaGradeLayer should be visible on desktop when should_show=true")

func test_desktop_update_visibility_hides_layer() -> void:
	var result := _setup_applier(0)
	var applier: U_DisplayCinemaGradeApplier = result["applier"]
	var layer: CanvasLayer = result["layer"]

	layer.visible = true  # start visible
	applier.update_visibility(false)
	assert_false(layer.visible,
		"CinemaGradeLayer should be hidden on desktop when should_show=false")

# --- Mobile behavior: cinema grade should be force-hidden ---

func test_mobile_update_visibility_hides_layer_even_when_should_show() -> void:
	var result := _setup_applier(1)
	var applier: U_DisplayCinemaGradeApplier = result["applier"]
	var layer: CanvasLayer = result["layer"]

	applier.update_visibility(true)
	assert_false(layer.visible,
		"CinemaGradeLayer should be hidden on mobile even when should_show=true")

func test_mobile_update_visibility_hides_layer_when_should_hide() -> void:
	var result := _setup_applier(1)
	var applier: U_DisplayCinemaGradeApplier = result["applier"]
	var layer: CanvasLayer = result["layer"]

	applier.update_visibility(false)
	assert_false(layer.visible,
		"CinemaGradeLayer should be hidden on mobile when should_show=false")

func test_mobile_apply_settings_does_not_create_layer() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	var applier := U_CINEMA_GRADE_APPLIER.new()
	applier.initialize(null, null)

	# apply_settings on mobile should skip entirely (no layer creation)
	applier.apply_settings({})

	var layer := _overlay.find_child("CinemaGradeLayer", false, false)
	assert_null(layer,
		"CinemaGradeLayer should not be created on mobile")