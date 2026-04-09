extends SubViewportContainer
class_name U_ViewportResizer

## Automatically resizes the child SubViewport to match the container size.
## On mobile devices, renders at a reduced resolution for better performance.
## Uses stretch_shrink when stretch is enabled (Godot-managed upscaling),
## or directly sets SubViewport.size when stretch is disabled.

const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

func _ready() -> void:
	resized.connect(_on_resized)
	# Resize immediately before first frame to avoid low-res initial render
	call_deferred("_resize_viewport")

func _on_resized() -> void:
	_resize_viewport()

func _resize_viewport() -> void:
	var viewport := get_child(0) as SubViewport
	if viewport == null:
		return

	# Use actual container size as the base resolution
	var target_size := size

	# Ensure minimum size to avoid issues
	if target_size.x < 1 or target_size.y < 1:
		target_size = get_viewport().get_visible_rect().size

	var scale_factor := U_MOBILE_PLATFORM_DETECTOR.get_viewport_scale_factor()

	if stretch:
		# When stretch is enabled, Godot manages the SubViewport size and
		# prevents manual resizing. Use stretch_shrink instead — it tells
		# the container to render at a fraction of native resolution and
		# upscale the result.
		if scale_factor < 1.0:
			# Account for DPI scaling: the container may be larger than the
			# design resolution on high-DPI devices. stretch_shrink divides
			# the CONTAINER size, so we must divide by both the DPI scale
			# (container/design) and the resolution scale factor.
			var design_width: float = float(
				ProjectSettings.get_setting("display/window/size/viewport_width")
			)
			var dpi_scale: float = size.x / design_width if design_width > 0.0 else 1.0
			stretch_shrink = maxi(2, int(roundf(dpi_scale / scale_factor)))
		else:
			stretch_shrink = 1
		return

	# When stretch is disabled, directly set the SubViewport render size.
	# Pass design resolution so mobile scaling is relative to design size,
	# not the DPI-inflated container size.
	var design_size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	var scaled_size := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(
		Vector2i(int(target_size.x), int(target_size.y)),
		design_size if design_size.x > 0 else Vector2i.ZERO
	)
	viewport.size = scaled_size