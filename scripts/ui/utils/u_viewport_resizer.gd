extends SubViewportContainer
class_name U_ViewportResizer

## Automatically resizes the child SubViewport to match the container size.

func _ready() -> void:
	resized.connect(_on_resized)
	_resize_viewport()

func _on_resized() -> void:
	_resize_viewport()

func _resize_viewport() -> void:
	var viewport := get_child(0) as SubViewport
	if viewport == null:
		return
	viewport.size = size
