class_name U_SceneManagerNodeFinder

## Node Finder Helper for M_SceneManager
##
## Responsibilities:
## - Find required container nodes in the scene tree
## - ServiceLocator-first lookup with tree fallback
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
## Searches from the scene root (not SceneTree.root) to avoid cross-scene pollution.
## Uses ServiceLocator first for overlays (test environments), falls back to tree search.
##
## Parameters:
##   manager: The scene manager node (used to find scene root)
##
## Returns:
##   ContainerRefs instance with discovered nodes (null if not found)
static func find_containers(manager: Node) -> ContainerRefs:
	var refs := ContainerRefs.new()
	var tree := manager.get_tree()
	if tree == null:
		return refs

	# Walk up to scene root (direct child of SceneTree.root)
	var root: Node = manager
	while root.get_parent() != null and root.get_parent() != tree.root:
		root = root.get_parent()
	if root.get_parent() != tree.root:
		root = tree.root

	# Find ActiveSceneContainer
	refs.active_scene_container = root.find_child("ActiveSceneContainer", true, false)
	if refs.active_scene_container == null:
		push_error("M_SceneManager: ActiveSceneContainer not found")

	# Find UIOverlayStack
	refs.ui_overlay_stack = root.find_child("UIOverlayStack", true, false)
	if refs.ui_overlay_stack == null:
		push_error("M_SceneManager: UIOverlayStack not found")

	# Find TransitionOverlay (ServiceLocator first for test environments)
	refs.transition_overlay = U_SERVICE_LOCATOR.try_get_service(StringName("transition_overlay")) as CanvasLayer
	if refs.transition_overlay == null:
		refs.transition_overlay = root.find_child("TransitionOverlay", true, false)
	if refs.transition_overlay == null:
		push_error("M_SceneManager: TransitionOverlay not found")

	# Find LoadingOverlay (ServiceLocator first for test environments)
	refs.loading_overlay = U_SERVICE_LOCATOR.try_get_service(StringName("loading_overlay")) as CanvasLayer
	if refs.loading_overlay == null:
		refs.loading_overlay = root.find_child("LoadingOverlay", true, false)
	if refs.loading_overlay == null:
		push_warning("M_SceneManager: LoadingOverlay not found (loading transitions will not work)")

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
static func ensure_store_reference(current_store: Node, manager: Node) -> Node:
	if current_store != null and is_instance_valid(current_store):
		return current_store

	var tree := manager.get_tree()
	if tree == null:
		return null

	var stores := tree.get_nodes_in_group("state_store")
	if stores.size() > 0:
		return stores[0] as M_STATE_STORE

	return null
