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

func push_overlay(manager: Node, scene_id: StringName, force: bool) -> void:
	var scene_path: String = U_SCENE_REGISTRY.get_scene_path(scene_id)
	if scene_path.is_empty():
		push_warning("M_SceneManager: Scene '%s' not found for overlay" % scene_id)
		return

	var overlay_scene: Node = manager._load_scene(scene_path)
	if overlay_scene == null:
		push_error("M_SceneManager: Failed to load overlay scene '%s'" % scene_id)
		return

	var ui_overlay_stack: CanvasLayer = manager._ui_overlay_stack
	if ui_overlay_stack == null:
		push_error("M_SceneManager: UIOverlayStack not found for overlay '%s'" % scene_id)
		overlay_scene.queue_free()
		return

	_configure_overlay_scene(overlay_scene, scene_id)
	ui_overlay_stack.add_child(overlay_scene)

	var store = manager._store
	if store != null:
		store.dispatch(U_SCENE_ACTIONS.push_overlay(scene_id))

	manager._update_particles_and_focus()

func pop_overlay(manager: Node) -> void:
	var ui_overlay_stack: CanvasLayer = manager._ui_overlay_stack
	if ui_overlay_stack == null:
		return

	var overlay_count: int = ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return

	var store = manager._store
	if store != null:
		store.dispatch(U_SCENE_ACTIONS.pop_overlay())

	var top_overlay: Node = ui_overlay_stack.get_child(overlay_count - 1)
	ui_overlay_stack.remove_child(top_overlay)
	top_overlay.queue_free()

	manager._update_particles_and_focus()
	manager._restore_focus_to_top_overlay()

func push_overlay_with_return(manager: Node, overlay_id: StringName) -> void:
	var current_top: StringName = _get_top_overlay_id(manager)
	manager._overlay_return_stack.push_back(current_top)

	if not current_top.is_empty():
		pop_overlay(manager)

	push_overlay(manager, overlay_id, true)

func pop_overlay_with_return(manager: Node) -> void:
	pop_overlay(manager)

	if not manager._overlay_return_stack.is_empty():
		var previous_overlay: StringName = manager._overlay_return_stack.pop_back()
		if not previous_overlay.is_empty():
			manager.call_deferred("_push_overlay_for_return", previous_overlay)

func configure_overlay_scene(overlay_scene: Node, scene_id: StringName) -> void:
	_configure_overlay_scene(overlay_scene, scene_id)

func restore_focus_to_top_overlay(manager: Node) -> void:
	_restore_focus_to_top_overlay(manager)

func find_first_focusable_in(root: Node) -> Control:
	return _find_first_focusable_in(root)

func get_top_overlay_id(manager: Node) -> StringName:
	return _get_top_overlay_id(manager)

func reconcile_overlay_stack(manager: Node, desired_overlay_ids: Array[StringName], current_stack: Array[StringName]) -> void:
	_reconcile_overlay_stack(manager, desired_overlay_ids, current_stack)

func get_overlay_scene_ids_from_ui(manager: Node) -> Array[StringName]:
	return _get_overlay_scene_ids_from_ui(manager)

func overlay_stacks_match(stack_a: Array[StringName], stack_b: Array[StringName]) -> bool:
	return _overlay_stacks_match(stack_a, stack_b)

func update_overlay_visibility(manager: Node, overlay_ids: Array[StringName]) -> void:
	_update_overlay_visibility(manager, overlay_ids)

func _configure_overlay_scene(overlay_scene: Node, scene_id: StringName) -> void:
	if overlay_scene == null:
		return

	overlay_scene.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_scene.set_meta(OVERLAY_META_SCENE_ID, scene_id)

func _restore_focus_to_top_overlay(manager: Node) -> void:
	var ui_overlay_stack: CanvasLayer = manager._ui_overlay_stack
	if ui_overlay_stack == null:
		return

	var overlay_count: int = ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return

	var top_overlay: Node = ui_overlay_stack.get_child(overlay_count - 1)
	if top_overlay == null:
		return

	var viewport: Viewport = manager.get_tree().root
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

func _get_top_overlay_id(manager: Node) -> StringName:
	var ui_overlay_stack: CanvasLayer = manager._ui_overlay_stack
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

func _reconcile_overlay_stack(manager: Node, desired_overlay_ids: Array[StringName], current_stack: Array[StringName]) -> void:
	if manager._is_processing_transition or manager._transition_queue.size() > 0:
		manager._pending_overlay_reconciliation = true
		return

	const MAX_STACK_DEPTH := 8
	var desired_scene_stack: Array[StringName] = _map_overlay_ids_to_scene_ids(desired_overlay_ids)
	if _overlay_stacks_match(current_stack, desired_scene_stack):
		manager._pending_overlay_reconciliation = false
		_update_overlay_visibility(manager, desired_overlay_ids)
		return

	var normalized_current: Array[StringName] = current_stack.duplicate(true)
	var prefix_len: int = _get_longest_matching_prefix(normalized_current, desired_scene_stack)

	while normalized_current.size() > prefix_len:
		manager.pop_overlay()
		if not normalized_current.is_empty():
			normalized_current.pop_back()

	var desired_count: int = min(desired_scene_stack.size(), MAX_STACK_DEPTH)
	if desired_scene_stack.size() > MAX_STACK_DEPTH:
		push_warning("M_SceneManager: Desired overlay stack exceeds supported depth (%d); truncating" % MAX_STACK_DEPTH)

	for i in range(prefix_len, desired_count):
		var scene_id: StringName = desired_scene_stack[i]
		if scene_id == StringName(""):
			continue
		if not manager._push_overlay_scene_from_navigation(scene_id):
			break
		normalized_current.append(scene_id)

	manager._pending_overlay_reconciliation = false
	_update_overlay_visibility(manager, desired_overlay_ids)

func _get_overlay_scene_ids_from_ui(manager: Node) -> Array[StringName]:
	var overlay_ids: Array[StringName] = []
	var ui_overlay_stack: CanvasLayer = manager._ui_overlay_stack

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

func _update_overlay_visibility(manager: Node, overlay_ids: Array[StringName]) -> void:
	var ui_overlay_stack: CanvasLayer = manager._ui_overlay_stack
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

