extends GutTest

## Tests for U_ViewportResizer resolution scaling behavior.

const U_VIEWPORT_RESIZER := preload("res://scripts/core/ui/utils/u_viewport_resizer.gd")

var _container: SubViewportContainer
var _viewport: SubViewport

func after_each() -> void:
	if _container != null and is_instance_valid(_container):
		_container.queue_free()
	_container = null
	_viewport = null

func _build_viewport_resizer(with_stretch: bool, container_size: Vector2i = Vector2i(960, 600)) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.name = "GameViewportContainer"
	# Don't set anchors_preset — keep at default so size stays fixed in tests
	container.stretch = with_stretch
	container.size = container_size
	container.set_script(U_VIEWPORT_RESIZER)

	_viewport = SubViewport.new()
	_viewport.name = "GameViewport"
	_viewport.size = Vector2i(960, 600)
	container.add_child(_viewport)

	return container

func test_stretch_false_sets_viewport_to_container_size() -> void:
	_container = _build_viewport_resizer(false)
	add_child(_container)
	await get_tree().process_frame

	var expected_size := Vector2i(int(_container.size.x), int(_container.size.y))
	assert_eq(_viewport.size, expected_size,
		"Viewport size should match container size with stretch=false")

func test_stretch_true_no_shrink() -> void:
	_container = _build_viewport_resizer(true)
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 1,
		"stretch_shrink should be 1 (no reduction)")

func test_stretch_true_shrink_is_1() -> void:
	_container = _build_viewport_resizer(true)
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 1,
		"stretch_shrink should be 1")

