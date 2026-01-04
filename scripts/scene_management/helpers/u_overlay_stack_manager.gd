extends RefCounted
class_name U_OverlayStackManager

## Overlay stack helper for M_SceneManager (Phase 9A - T090c).
##
## Responsibilities:
## - Pushing and popping overlay scenes
## - Managing overlay return stack behaviour
## - Configuring overlay scenes and focus
## - Reconciling overlay stack from navigation state

const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_UI_REGISTRY := preload("res://scripts/ui/u_ui_registry.gd")

const OVERLAY_META_SCENE_ID := StringName("_scene_manager_overlay_scene_id")

func push_overlay(scene_id: StringName, force: bool, load_scene: Callable, ui_overlay_stack: CanvasLayer, store: Object, on_overlay_stack_updated: Callable) -> void:
	var scene_path: String = U_SCENE_REGISTRY.get_scene_path(scene_id)
	if scene_path.is_empty():
		push_warning("M_SceneManager: Scene '%s' not found for overlay" % scene_id)
		return

	var overlay_scene: Node = null
	if load_scene != null and load_scene.is_valid():
		overlay_scene = load_scene.call(scene_path) as Node
	if overlay_scene == null:
		push_error("M_SceneManager: Failed to load overlay scene '%s'" % scene_id)
		return

	if ui_overlay_stack == null:
		push_error("M_SceneManager: UIOverlayStack not found for overlay '%s'" % scene_id)
		overlay_scene.queue_free()
		return

	_configure_overlay_scene(overlay_scene, scene_id)
	ui_overlay_stack.add_child(overlay_scene)

	if store != null and store.has_method("dispatch"):
		store.dispatch(U_SCENE_ACTIONS.push_overlay(scene_id))

	if on_overlay_stack_updated != null and on_overlay_stack_updated.is_valid():
		on_overlay_stack_updated.call()

func pop_overlay(ui_overlay_stack: CanvasLayer, store: Object, on_overlay_stack_updated: Callable, viewport: Viewport) -> void:
	if ui_overlay_stack == null:
		return

	var overlay_count: int = ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return

	if store != null and store.has_method("dispatch"):
		store.dispatch(U_SCENE_ACTIONS.pop_overlay())

	var top_overlay: Node = ui_overlay_stack.get_child(overlay_count - 1)
	# Ensure the node is queued for deletion while it is still in the scene tree.
	# Calling queue_free() after remove_child() can leave it orphaned in tests.
	top_overlay.queue_free()
	ui_overlay_stack.remove_child(top_overlay)

	if on_overlay_stack_updated != null and on_overlay_stack_updated.is_valid():
		on_overlay_stack_updated.call()
	_restore_focus_to_top_overlay(ui_overlay_stack, viewport)

func push_overlay_with_return(overlay_id: StringName, overlay_return_stack: Array[StringName], load_scene: Callable, ui_overlay_stack: CanvasLayer, store: Object, on_overlay_stack_updated: Callable, viewport: Viewport) -> void:
	var current_top: StringName = _get_top_overlay_id(ui_overlay_stack)
	overlay_return_stack.push_back(current_top)

	if not current_top.is_empty():
		pop_overlay(ui_overlay_stack, store, on_overlay_stack_updated, viewport)

	push_overlay(overlay_id, true, load_scene, ui_overlay_stack, store, on_overlay_stack_updated)

func pop_overlay_with_return(overlay_return_stack: Array[StringName], load_scene: Callable, ui_overlay_stack: CanvasLayer, store: Object, on_overlay_stack_updated: Callable, viewport: Viewport, deferred_push_overlay_for_return: Callable) -> void:
	pop_overlay(ui_overlay_stack, store, on_overlay_stack_updated, viewport)

	if not overlay_return_stack.is_empty():
		var previous_overlay: StringName = overlay_return_stack.pop_back()
		if not previous_overlay.is_empty():
			if deferred_push_overlay_for_return != null and deferred_push_overlay_for_return.is_valid():
				deferred_push_overlay_for_return.call(previous_overlay)

func configure_overlay_scene(overlay_scene: Node, scene_id: StringName) -> void:
	_configure_overlay_scene(overlay_scene, scene_id)

func restore_focus_to_top_overlay(ui_overlay_stack: CanvasLayer, viewport: Viewport) -> void:
	_restore_focus_to_top_overlay(ui_overlay_stack, viewport)

func find_first_focusable_in(root: Node) -> Control:
	return _find_first_focusable_in(root)

func get_top_overlay_id(ui_overlay_stack: CanvasLayer) -> StringName:
	return _get_top_overlay_id(ui_overlay_stack)

func reconcile_overlay_stack(desired_overlay_ids: Array[StringName], current_stack: Array[StringName], load_scene: Callable, ui_overlay_stack: CanvasLayer, store: Object, on_overlay_stack_updated: Callable, viewport: Viewport, get_transition_queue_state: Callable, set_overlay_reconciliation_pending: Callable) -> void:
	_reconcile_overlay_stack(desired_overlay_ids, current_stack, load_scene, ui_overlay_stack, store, on_overlay_stack_updated, viewport, get_transition_queue_state, set_overlay_reconciliation_pending)

func get_overlay_scene_ids_from_ui(ui_overlay_stack: CanvasLayer) -> Array[StringName]:
	return _get_overlay_scene_ids_from_ui(ui_overlay_stack)

func overlay_stacks_match(stack_a: Array[StringName], stack_b: Array[StringName]) -> bool:
	return _overlay_stacks_match(stack_a, stack_b)

func update_overlay_visibility(ui_overlay_stack: CanvasLayer, overlay_ids: Array[StringName]) -> void:
	_update_overlay_visibility(ui_overlay_stack, overlay_ids)

func _configure_overlay_scene(overlay_scene: Node, scene_id: StringName) -> void:
	if overlay_scene == null:
		return

	overlay_scene.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_scene.set_meta(OVERLAY_META_SCENE_ID, scene_id)

func _restore_focus_to_top_overlay(ui_overlay_stack: CanvasLayer, viewport: Viewport) -> void:
	if ui_overlay_stack == null:
		return

	var overlay_count: int = ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return

	var top_overlay: Node = ui_overlay_stack.get_child(overlay_count - 1)
	if top_overlay == null:
		return

	var focus_owner: Control = null
	if viewport != null:
		focus_owner = viewport.gui_get_focus_owner()

	var has_focus_in_top: bool = focus_owner != null \
		and focus_owner.is_inside_tree() \
		and top_overlay.is_ancestor_of(focus_owner)
	if has_focus_in_top:
		return

	var target: Control = _find_first_focusable_in(top_overlay)
	if target != null and target.is_inside_tree():
		target.grab_focus()

func _find_first_focusable_in(root: Node) -> Control:
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
				return control
			var nested_control := _find_first_focusable_in(control)
			if nested_control != null:
				return nested_control
		else:
			var nested := _find_first_focusable_in(child)
			if nested != null:
				return nested
	return null

func _get_top_overlay_id(ui_overlay_stack: CanvasLayer) -> StringName:
	if ui_overlay_stack == null:
		return StringName("")

	var overlay_count: int = ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return StringName("")

	var top_overlay: Node = ui_overlay_stack.get_child(overlay_count - 1)
	if top_overlay.has_meta(OVERLAY_META_SCENE_ID):
		var scene_id_meta: Variant = top_overlay.get_meta(OVERLAY_META_SCENE_ID)
		if scene_id_meta is StringName:
			return scene_id_meta
		elif scene_id_meta is String:
			return StringName(scene_id_meta)

	return StringName("")

func _reconcile_overlay_stack(desired_overlay_ids: Array[StringName], current_stack: Array[StringName], load_scene: Callable, ui_overlay_stack: CanvasLayer, store: Object, on_overlay_stack_updated: Callable, viewport: Viewport, get_transition_queue_state: Callable, set_overlay_reconciliation_pending: Callable) -> void:
	# Check if transition is in progress
	var transition_state: Dictionary = {}
	if get_transition_queue_state != null and get_transition_queue_state.is_valid():
		var state_variant: Variant = get_transition_queue_state.call()
		if state_variant is Dictionary:
			transition_state = state_variant

	var is_processing: bool = transition_state.get("is_processing", false)
	var queue_size: int = transition_state.get("queue_size", 0)

	if is_processing or queue_size > 0:
		if set_overlay_reconciliation_pending != null and set_overlay_reconciliation_pending.is_valid():
			set_overlay_reconciliation_pending.call(true)
		return

	const MAX_STACK_DEPTH := 8
	var desired_scene_stack: Array[StringName] = _map_overlay_ids_to_scene_ids(desired_overlay_ids)
	if _overlay_stacks_match(current_stack, desired_scene_stack):
		if set_overlay_reconciliation_pending != null and set_overlay_reconciliation_pending.is_valid():
			set_overlay_reconciliation_pending.call(false)
		_update_overlay_visibility(ui_overlay_stack, desired_overlay_ids)
		return

	var normalized_current: Array[StringName] = current_stack.duplicate(true)
	var prefix_len: int = _get_longest_matching_prefix(normalized_current, desired_scene_stack)

	while normalized_current.size() > prefix_len:
		pop_overlay(ui_overlay_stack, store, on_overlay_stack_updated, viewport)
		if not normalized_current.is_empty():
			normalized_current.pop_back()

	var desired_count: int = min(desired_scene_stack.size(), MAX_STACK_DEPTH)
	if desired_scene_stack.size() > MAX_STACK_DEPTH:
		push_warning("M_SceneManager: Desired overlay stack exceeds supported depth (%d); truncating" % MAX_STACK_DEPTH)

	for i in range(prefix_len, desired_count):
		var scene_id: StringName = desired_scene_stack[i]
		if scene_id == StringName(""):
			continue
		var before_count: int = ui_overlay_stack.get_child_count() if ui_overlay_stack != null else 0
		push_overlay(scene_id, false, load_scene, ui_overlay_stack, store, on_overlay_stack_updated)
		if ui_overlay_stack == null:
			break
		var after_count: int = ui_overlay_stack.get_child_count()
		if after_count <= before_count:
			break
		normalized_current.append(scene_id)

	if set_overlay_reconciliation_pending != null and set_overlay_reconciliation_pending.is_valid():
		set_overlay_reconciliation_pending.call(false)
	_update_overlay_visibility(ui_overlay_stack, desired_overlay_ids)

func _get_overlay_scene_ids_from_ui(ui_overlay_stack: CanvasLayer) -> Array[StringName]:
	var overlay_ids: Array[StringName] = []

	if ui_overlay_stack == null:
		return overlay_ids

	for child in ui_overlay_stack.get_children():
		if child.has_meta(OVERLAY_META_SCENE_ID):
			var scene_id_meta: Variant = child.get_meta(OVERLAY_META_SCENE_ID)
			if scene_id_meta is StringName:
				overlay_ids.append(scene_id_meta)
			elif scene_id_meta is String:
				overlay_ids.append(StringName(scene_id_meta))
			else:
				push_warning("M_SceneManager: Overlay has invalid scene_id metadata")
		else:
			push_warning("M_SceneManager: Overlay missing scene_id metadata")

	return overlay_ids

func _overlay_stacks_match(stack_a: Array[StringName], stack_b: Array[StringName]) -> bool:
	if stack_a.size() != stack_b.size():
		return false

	for i in range(stack_a.size()):
		if stack_a[i] != stack_b[i]:
			return false

	return true

func _update_overlay_visibility(ui_overlay_stack: CanvasLayer, overlay_ids: Array[StringName]) -> void:
	if ui_overlay_stack == null or overlay_ids.is_empty():
		return

	var top_overlay_id: StringName = overlay_ids.back() if not overlay_ids.is_empty() else StringName("")
	var should_hide_previous: bool = false

	if top_overlay_id != StringName(""):
		var definition: Dictionary = U_UI_REGISTRY.get_screen(top_overlay_id)
		if not definition.is_empty():
			should_hide_previous = definition.get("hides_previous_overlays", false)

	var child_count: int = ui_overlay_stack.get_child_count()
	for i in range(child_count):
		var overlay: Node = ui_overlay_stack.get_child(i)
		if overlay is CanvasItem:
			if should_hide_previous:
				overlay.visible = (i == child_count - 1)
			else:
				overlay.visible = true

func _get_longest_matching_prefix(stack_a: Array[StringName], stack_b: Array[StringName]) -> int:
	var limit: int = min(stack_a.size(), stack_b.size())
	for i in range(limit):
		if stack_a[i] != stack_b[i]:
			return i
	return limit

func _map_overlay_ids_to_scene_ids(overlay_ids: Array[StringName]) -> Array[StringName]:
	var mapped: Array[StringName] = []
	for overlay_id in overlay_ids:
		var definition: Dictionary = U_UI_REGISTRY.get_screen(overlay_id)
		if definition.is_empty():
			mapped.append(overlay_id)
			continue
		var scene_id_variant: Variant = definition.get("scene_id", overlay_id)
		if scene_id_variant is StringName:
			mapped.append(scene_id_variant)
		elif scene_id_variant is String:
			mapped.append(StringName(scene_id_variant))
		else:
			mapped.append(overlay_id)
	return mapped
