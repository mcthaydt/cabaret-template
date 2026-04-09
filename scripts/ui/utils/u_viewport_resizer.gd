extends SubViewportContainer
class_name U_ViewportResizer

## Automatically resizes the child SubViewport to match the container size.
## On mobile devices, renders at a reduced resolution for better performance.
## The SubViewportContainer's stretch property handles upscaling to native size.

const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

func _ready() -> void:
	resized.connect(_on_resized)
	# Resize immediately before first frame to avoid low-res initial render
	call_deferred("_resize_viewport")

func _on_resized() -> void:
	_resize_viewport()

func _resize_viewport() -> void:
	# If stretch is enabled, the container controls the size automatically.
	if stretch:
		return

	var viewport := get_child(0) as SubViewport
	if viewport == null:
		return

	# Use actual container size as the base resolution
	var target_size := size

	# Ensure minimum size to avoid issues
	if target_size.x < 1 or target_size.y < 1:
		target_size = get_viewport().get_visible_rect().size

	# On mobile, scale the viewport down for better performance.
	# The SubViewportContainer stretch will upscale to fill the screen.
	var scaled_size := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(
		Vector2i(int(target_size.x), int(target_size.y))
	)
	viewport.size = scaled_size
