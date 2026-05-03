extends SubViewportContainer
class_name U_ViewportResizer

func _ready() -> void:
	resized.connect(_on_resized)
	call_deferred("_resize_viewport")

func _on_resized() -> void:
	_resize_viewport()

func request_scale_refresh() -> void:
	_resize_viewport()

func _resize_viewport() -> void:
	var viewport := get_child(0) as SubViewport
	if viewport == null:
		return

	var target_size := size
	if target_size.x < 1 or target_size.y < 1:
		target_size = get_viewport().get_visible_rect().size

	if stretch:
		stretch_shrink = 1
		return

	viewport.size = Vector2i(int(target_size.x), int(target_size.y))
