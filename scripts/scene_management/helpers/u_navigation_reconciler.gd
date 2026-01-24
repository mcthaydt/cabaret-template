class_name U_NavigationReconciler

## Navigation Reconciliation Helper for M_SceneManager
##
## Responsibilities:
## - Reconcile navigation slice → base scene transitions
## - Reconcile navigation overlay_stack → UIOverlayStack
## - Guard rails: pending scene tracking, queue checks
## - Helper methods: stack comparison, ID mapping

const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_UI_REGISTRY := preload("res://scripts/ui/utils/u_ui_registry.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_OVERLAY_STACK_MANAGER := preload("res://scripts/scene_management/helpers/u_overlay_stack_manager.gd")
const I_SceneManager := preload("res://scripts/interfaces/i_scene_manager.gd")

## Internal state for reconciliation
var _navigation_pending_scene_id: StringName = StringName("")
var _pending_overlay_reconciliation: bool = false
var _latest_navigation_state: Dictionary = {}

## Get pending scene ID
func get_pending_scene_id() -> StringName:
	return _navigation_pending_scene_id

## Set pending scene ID
func set_pending_scene_id(scene_id: StringName) -> void:
	_navigation_pending_scene_id = scene_id

## Get pending overlay reconciliation flag
func is_overlay_reconciliation_pending() -> bool:
	return _pending_overlay_reconciliation

## Set pending overlay reconciliation flag
func set_overlay_reconciliation_pending(pending: bool) -> void:
	_pending_overlay_reconciliation = pending

## Get latest navigation state
func get_latest_navigation_state() -> Dictionary:
	return _latest_navigation_state

## Reconcile navigation slice → scene transitions
##
## Main entry point for navigation reconciliation. Updates internal state
## and delegates base scene + overlay reconciliation.
##
## Parameters:
##   nav_state: Navigation slice dictionary
##   manager: Scene manager instance (for callbacks)
##   current_scene_id: Current active scene ID
##   overlay_helper: Overlay stack manager helper
func reconcile_navigation_state(
	nav_state: Dictionary,
	manager: Node,
	current_scene_id: StringName,
	overlay_helper: U_OVERLAY_STACK_MANAGER,
	load_scene: Callable,
	ui_overlay_stack: CanvasLayer,
	store: Object,
	on_overlay_stack_updated: Callable,
	viewport: Viewport,
	get_transition_queue_state: Callable,
	set_overlay_reconciliation_pending: Callable
) -> void:
	if nav_state.is_empty():
		return

	_latest_navigation_state = nav_state.duplicate(true)

	var desired_scene_id: StringName = nav_state.get("base_scene_id", StringName(""))
	reconcile_base_scene(
		desired_scene_id,
		manager,
		current_scene_id
	)

	var desired_overlay_ids: Array[StringName] = _coerce_string_name_array(
		nav_state.get("overlay_stack", [])
	)
	var current_stack: Array[StringName] = overlay_helper.get_overlay_scene_ids_from_ui(ui_overlay_stack)

	overlay_helper.reconcile_overlay_stack(
		desired_overlay_ids,
		current_stack,
		load_scene,
		ui_overlay_stack,
		store,
		on_overlay_stack_updated,
		viewport,
		get_transition_queue_state,
		set_overlay_reconciliation_pending
	)

## Reconcile base scene if needed
##
## Checks if base scene transition is needed and enqueues transition.
## Guards against duplicate transitions and invalid scenes.
##
## Parameters:
##   desired_scene_id: Target scene from navigation state
##   manager: Scene manager instance (for transition_to_scene callback)
##   current_scene_id: Current active scene ID
func reconcile_base_scene(
	desired_scene_id: StringName,
	manager: Node,
	current_scene_id: StringName
) -> void:
	if desired_scene_id == StringName(""):
		return

	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(desired_scene_id)
	if scene_data.is_empty():
		return

	if current_scene_id == desired_scene_id:
		return

	if manager.has_method("_get_active_transition_target"):
		var active_target: StringName = manager.call("_get_active_transition_target")
		if active_target == desired_scene_id:
			return

	if _navigation_pending_scene_id == desired_scene_id:
		return

	if manager.has_method("_is_scene_in_queue"):
		if manager.call("_is_scene_in_queue", desired_scene_id):
			return

	# Default transition settings from registry
	var transition_type: String = String(scene_data.get("default_transition", "instant"))
	var priority: int = 1  # HIGH priority for navigation-driven transitions

	# Navigation slice may provide override metadata
	if not _latest_navigation_state.is_empty():
		var metadata: Dictionary = _latest_navigation_state.get("_transition_metadata", {})
		if not metadata.is_empty():
			var type_variant: Variant = metadata.get("transition_type", transition_type)
			if type_variant is String:
				transition_type = String(type_variant)
			var priority_variant: Variant = metadata.get("priority", priority)
			if priority_variant is int:
				priority = int(priority_variant)

	if transition_type.is_empty():
		transition_type = "instant"

	var typed_manager := manager as I_SceneManager
	if typed_manager != null:
		typed_manager.transition_to_scene(desired_scene_id, transition_type, priority)
		_navigation_pending_scene_id = desired_scene_id

## Reconcile pending overlay reconciliation (deferred)
##
## Called after base scene transitions complete. Applies queued overlay changes.
##
## Parameters:
##   manager: Scene manager instance
##   overlay_helper: Overlay stack manager helper
func reconcile_pending_overlays(manager: Node, overlay_helper: U_OVERLAY_STACK_MANAGER, load_scene: Callable, ui_overlay_stack: CanvasLayer, store: Object, on_overlay_stack_updated: Callable, viewport: Viewport, get_transition_queue_state: Callable, set_overlay_reconciliation_pending: Callable) -> void:
	if not _pending_overlay_reconciliation:
		return

	if _latest_navigation_state.is_empty():
		_pending_overlay_reconciliation = false
		return

	var desired_overlay_ids: Array[StringName] = _coerce_string_name_array(
		_latest_navigation_state.get("overlay_stack", [])
	)
	var current_stack: Array[StringName] = overlay_helper.get_overlay_scene_ids_from_ui(ui_overlay_stack)

	overlay_helper.reconcile_overlay_stack(
		desired_overlay_ids,
		current_stack,
		load_scene,
		ui_overlay_stack,
		store,
		on_overlay_stack_updated,
		viewport,
		get_transition_queue_state,
		set_overlay_reconciliation_pending
	)

## Map overlay IDs to scene IDs using UI registry
##
## Looks up overlay definitions and extracts scene_id field.
## Falls back to overlay_id if definition not found.
##
## Parameters:
##   overlay_ids: Array of overlay identifiers
##
## Returns:
##   Array of scene identifiers
static func map_overlay_ids_to_scene_ids(overlay_ids: Array[StringName]) -> Array[StringName]:
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

## Coerce variant array to StringName array
##
## Safely converts mixed-type arrays to typed StringName arrays.
##
## Parameters:
##   value: Input variant (should be Array)
##
## Returns:
##   Typed Array[StringName]
static func _coerce_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry in value:
			if entry is StringName:
				result.append(entry)
			elif entry is String:
				result.append(StringName(entry))
	return result

## Get longest matching prefix between two stacks
##
## Used to optimize overlay reconciliation by preserving common prefix.
##
## Parameters:
##   stack_a: First stack
##   stack_b: Second stack
##
## Returns:
##   Length of matching prefix
static func get_longest_matching_prefix(stack_a: Array[StringName], stack_b: Array[StringName]) -> int:
	var limit: int = min(stack_a.size(), stack_b.size())
	for i in range(limit):
		if stack_a[i] != stack_b[i]:
			return i
	return limit
