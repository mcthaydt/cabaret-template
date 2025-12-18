## Scene type handler for UI scenes.
##
## Handles UI-specific navigation state including shell synchronization and
## history tracking for back button navigation.
##
## Responsibilities:
## - Return "main_menu" shell for navigation state
## - Dispatch set_shell() navigation action
## - Track in navigation history (enable back navigation)
## - No spawn manager required
##
## Note: Behavior is identical to H_MenuSceneHandler (both use "main_menu" shell).
class_name H_UISceneHandler extends I_SCENE_TYPE_HANDLER

const U_SCENE_REGISTRY = preload("res://scripts/scene_management/u_scene_registry.gd")
const U_NAVIGATION_ACTIONS = preload("res://scripts/state/actions/u_navigation_actions.gd")


## Returns SceneType.UI
func get_scene_type() -> int:
	return U_SCENE_REGISTRY.SceneType.UI


## No special load behavior for UI scenes.
func on_load(scene: Node, scene_id: StringName, managers: Dictionary) -> void:
	pass


## No special unload behavior for UI scenes.
func on_unload(scene: Node, scene_id: StringName) -> void:
	pass


## UI scenes only require M_StateStore.
func get_required_managers() -> Array[StringName]:
	return [StringName("state_store")]


## UI scenes track in navigation history (enable back button).
func should_track_history() -> bool:
	return true


## Returns "main_menu" shell ID.
func get_shell_id() -> StringName:
	return StringName("main_menu")


## Dispatches set_shell() navigation action.
func get_navigation_action(scene_id: StringName) -> Dictionary:
	return U_NAVIGATION_ACTIONS.set_shell(get_shell_id(), scene_id)
