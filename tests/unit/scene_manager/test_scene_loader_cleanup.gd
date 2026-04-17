extends GutTest

## Tests for staged scene cleanup in U_SceneLoader
##
## Verifies that remove_current_scene() disables processing on children
## before freeing them, preventing old scenes from ticking during cleanup.

var loader: U_SceneLoader

func before_each() -> void:
	loader = U_SceneLoader.new()

func after_each() -> void:
	loader = null

func _make_container_with_children(count: int) -> Node:
	var container := Node.new()
	container.name = "ActiveSceneContainer"
	add_child(container)
	autofree(container)
	for i in range(count):
		var child := Node.new()
		child.name = "Child_%d" % i
		container.add_child(child)
	return container

# --- Process mode disabled before free ---

func test_remove_disables_processing_on_children() -> void:
	var container := _make_container_with_children(3)
	var children: Array[Node] = []
	for child in container.get_children():
		children.append(child)

	loader.remove_current_scene(container)

	for child in children:
		if is_instance_valid(child):
			assert_eq(
				child.process_mode, Node.PROCESS_MODE_DISABLED,
				"Child process_mode should be DISABLED after removal"
			)

func test_remove_clears_all_children() -> void:
	var container := _make_container_with_children(3)
	loader.remove_current_scene(container)
	assert_eq(container.get_child_count(), 0, "Container should have no children after removal")

func test_remove_handles_empty_container() -> void:
	var container := _make_container_with_children(0)
	loader.remove_current_scene(container)
	assert_eq(container.get_child_count(), 0, "Empty container should remain empty")

func test_remove_handles_null_container() -> void:
	loader.remove_current_scene(null)
	assert_true(true, "remove_current_scene(null) should not crash")

func test_children_freed_after_frame() -> void:
	var container := _make_container_with_children(2)
	var children: Array[Node] = []
	for child in container.get_children():
		children.append(child)

	loader.remove_current_scene(container)
	await get_tree().process_frame

	for child in children:
		assert_false(is_instance_valid(child), "Children should be freed after a frame")
