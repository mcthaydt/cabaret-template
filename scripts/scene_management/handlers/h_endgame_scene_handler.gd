## Scene type handler for END_GAME scenes.
##
## Handles end game-specific navigation state including shell synchronization.
## End game scenes represent terminal states (victory, game over) and do not
## support back navigation.
##
## Responsibilities:
## - Return "endgame" shell for navigation state
## - Dispatch set_shell() navigation action
## - Do NOT track in navigation history (end state)
## - No spawn manager required
class_name H_EndGameSceneHandler extends I_SCENE_TYPE_HANDLER

const U_SCENE_REGISTRY = preload("res://scripts/scene_management/u_scene_registry.gd")
const U_NAVIGATION_ACTIONS = preload("res://scripts/state/actions/u_navigation_actions.gd")


## Returns SceneType.END_GAME
func get_scene_type() -> int:
	return U_SCENE_REGISTRY.SceneType.END_GAME


## No special load behavior for endgame scenes.
func on_load(scene: Node, _scene_id: StringName, managers: Dictionary) -> void:
	pass


## No special unload behavior for endgame scenes.
func on_unload(scene: Node, _scene_id: StringName) -> void:
	pass


## Endgame scenes only require M_StateStore.
func get_required_managers() -> Array[StringName]:
	return [StringName("state_store")]


## Endgame scenes do NOT track in navigation history (end state).
func should_track_history() -> bool:
	return false


## Returns "endgame" shell ID.
func get_shell_id() -> StringName:
	return StringName("endgame")


## Dispatches set_shell() navigation action.
func get_navigation_action(scene_id: StringName) -> Dictionary:
	return U_NAVIGATION_ACTIONS.set_shell(get_shell_id(), scene_id)
