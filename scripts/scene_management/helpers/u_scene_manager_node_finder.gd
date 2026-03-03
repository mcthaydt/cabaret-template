class_name U_SceneManagerNodeFinder

## Node Finder Helper for M_SceneManager
##
## Responsibilities:
## - Find required container nodes in the scene tree
## - ServiceLocator-only lookup
## - Store reference discovery

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")

## Container references structure
class ContainerRefs:
	var active_scene_container: Node = null
	var ui_overlay_stack: CanvasLayer = null
	var transition_overlay: CanvasLayer = null
	var loading_overlay: CanvasLayer = null

## Find all required container nodes
##
## Uses ServiceLocator only for deterministic node discovery.
##
## Parameters:
##   manager: The scene manager node (used for null/validity guard)
##
## Returns:
##   ContainerRefs instance with discovered nodes (null if not found)
static func find_containers(manager: Node) -> ContainerRefs:
	var refs := ContainerRefs.new()
	if manager == null:
		return refs

	# Find ActiveSceneContainer
	refs.active_scene_container = U_SERVICE_LOCATOR.try_get_service(StringName("active_scene_container"))
	if refs.active_scene_container == null:
		push_error("M_SceneManager: ActiveSceneContainer service not found (active_scene_container)")

	# Find UIOverlayStack
	refs.ui_overlay_stack = U_SERVICE_LOCATOR.try_get_service(StringName("ui_overlay_stack")) as CanvasLayer
	if refs.ui_overlay_stack == null:
		push_error("M_SceneManager: UIOverlayStack service not found (ui_overlay_stack)")

	# Find TransitionOverlay
	refs.transition_overlay = U_SERVICE_LOCATOR.try_get_service(StringName("transition_overlay")) as CanvasLayer
	if refs.transition_overlay == null:
		push_error("M_SceneManager: TransitionOverlay service not found (transition_overlay)")

	# Find LoadingOverlay
	refs.loading_overlay = U_SERVICE_LOCATOR.try_get_service(StringName("loading_overlay")) as CanvasLayer
	if refs.loading_overlay == null:
		push_warning("M_SceneManager: LoadingOverlay service not found (loading transitions will not work)")

	return refs

## Ensure store reference is valid (fallback to group lookup)
##
## Used when store might be invalidated or not yet available.
## Checks if current store is valid, falls back to group lookup if not.
##
## Parameters:
##   current_store: Current store reference (may be null or invalid)
##   manager: The scene manager node (used to get tree)
##
## Returns:
##   Valid M_StateStore reference or null
static func ensure_store_reference(current_store: Node, _manager: Node) -> Node:
	if current_store != null and is_instance_valid(current_store):
		return current_store

	var store := U_SERVICE_LOCATOR.try_get_service(StringName("state_store")) as M_STATE_STORE
	return store
