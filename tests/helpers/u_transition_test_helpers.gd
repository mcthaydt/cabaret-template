class_name U_TransitionTestHelpers
extends RefCounted

## Test helper utilities for scene transitions
##
## Provides utilities to simplify transition testing by eliminating
## the Array closure workaround pattern and providing reliable
## async waiting utilities.
##
## Usage:
##   var tracker := U_TransitionTestHelpers.create_completion_tracker()
##   effect.execute(overlay, tracker.get_callback())
##   var completed := await tracker.wait(get_tree(), 1.0)
##   assert_true(completed, "Transition should complete")

## Completion tracking helper
##
## Eliminates the GDScript Array closure workaround pattern:
##   # Old pattern:
##   var completed: Array = [false]
##   callback = func(): completed[0] = true
##
##   # New pattern:
##   var tracker := U_TransitionTestHelpers.create_completion_tracker()
##   callback = tracker.get_callback()
class CompletionTracker:
	extends RefCounted

	## Whether the completion has been triggered
	var is_complete: bool = false

	## Mark as complete (can be called directly or via callback)
	func mark_complete() -> void:
		is_complete = true

	## Get a callback that marks this tracker as complete
	##
	## Returns a Callable that can be passed to async operations.
	## The callback captures this RefCounted instance, so it works
	## correctly (unlike primitive value captures in GDScript closures).
	func get_callback() -> Callable:
		return func() -> void:
			is_complete = true

	## Wait for completion with timeout
	##
	## Returns true if completed, false if timeout occurred.
	##
	## Parameters:
	##   tree: SceneTree - Required for await
	##   timeout_sec: float - Maximum wait time (default 1.0s)
	##
	## Returns: bool - true if completed, false if timeout
	func wait(tree: SceneTree, timeout_sec: float = 1.0) -> bool:
		if tree == null:
			return is_complete

		var start_ms: int = Time.get_ticks_msec()
		while not is_complete:
			await tree.process_frame
			var elapsed: float = (Time.get_ticks_msec() - start_ms) / 1000.0
			if elapsed >= timeout_sec:
				return false
		return true


## Create a new completion tracker
##
## Usage:
##   var tracker := U_TransitionTestHelpers.create_completion_tracker()
##   effect.execute(overlay, tracker.get_callback())
##   await tracker.wait(get_tree(), 1.0)
static func create_completion_tracker() -> CompletionTracker:
	return CompletionTracker.new()


## Wait for tween completion with timeout
##
## Replacement for manual polling loops. Returns true if tween
## completed, false if timeout occurred.
##
## Parameters:
##   tween: Tween - The tween to wait for
##   tree: SceneTree - Required for await
##   timeout_sec: float - Maximum wait time (default 1.0s)
##
## Returns: bool - true if tween finished, false if timeout or invalid
##
## Usage:
##   var tween := node.create_tween()
##   tween.tween_property(...)
##   var completed := await U_TransitionTestHelpers.await_tween_or_timeout(tween, get_tree(), 1.0)
##   assert_true(completed)
static func await_tween_or_timeout(tween: Tween, tree: SceneTree, timeout_sec: float = 1.0) -> bool:
	if tween == null or not tween.is_valid():
		return false

	if tree == null:
		return false

	var tracker := create_completion_tracker()
	tween.finished.connect(tracker.get_callback())

	return await tracker.wait(tree, timeout_sec)


## Create a test overlay with ColorRect for transition testing
##
## Returns a CanvasLayer with a TransitionColorRect child,
## matching the production structure expected by Trans_Fade.
##
## Usage:
##   var overlay := U_TransitionTestHelpers.create_test_overlay()
##   add_child_autofree(overlay)
##   fade.execute(overlay, callback)
static func create_test_overlay() -> CanvasLayer:
	var overlay := CanvasLayer.new()
	overlay.name = "TransitionOverlay"

	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	color_rect.modulate.a = 0.0
	overlay.add_child(color_rect)

	return overlay


## Create a test loading overlay for loading screen transition testing
##
## Returns a CanvasLayer configured for loading transitions.
##
## Usage:
##   var overlay := U_TransitionTestHelpers.create_test_loading_overlay()
##   add_child_autofree(overlay)
##   loading.execute(overlay, callback)
static func create_test_loading_overlay() -> CanvasLayer:
	var overlay := CanvasLayer.new()
	overlay.name = "LoadingOverlay"
	overlay.visible = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	return overlay
