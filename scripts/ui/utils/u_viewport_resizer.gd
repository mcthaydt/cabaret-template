extends SubViewportContainer
class_name U_ViewportResizer

## Automatically resizes the child SubViewport to match the container size.
## On mobile devices, respects native resolution for crisp post-processing.

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

	# Use actual window size for proper resolution
	# On mobile, this respects the native screen resolution for sharp rendering
	var target_size := size

	# Ensure minimum size to avoid issues
	if target_size.x < 1 or target_size.y < 1:
		target_size = get_viewport().get_visible_rect().size

	viewport.size = target_size
