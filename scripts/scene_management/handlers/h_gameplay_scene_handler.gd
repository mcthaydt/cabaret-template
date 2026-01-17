## Scene type handler for GAMEPLAY scenes.
##
## Handles gameplay-specific initialization including player spawning via M_SpawnManager
## and setting metadata to prevent M_GameplayInitializer race conditions.
##
## Responsibilities:
## - Record scene as spawned in M_SceneManager
## - Spawn player at target spawn point via M_SpawnManager
## - Return "gameplay" shell for navigation state
## - Dispatch start_game() navigation action
## - Do NOT track in navigation history (clears stack)
class_name H_GameplaySceneHandler extends I_SCENE_TYPE_HANDLER

const U_SCENE_REGISTRY = preload("res://scripts/scene_management/u_scene_registry.gd")
const U_NAVIGATION_ACTIONS = preload("res://scripts/state/actions/u_navigation_actions.gd")


## Returns SceneType.GAMEPLAY
func get_scene_type() -> int:
	return U_SCENE_REGISTRY.SceneType.GAMEPLAY


## Initializes gameplay scene with spawn manager integration.
##
## Awaits M_SpawnManager to position player at target spawn point.
## Note: Scene spawn bookkeeping is handled by M_SceneManager
## BEFORE the scene is added to the tree (to prevent M_GameplayInitializer race).
##
## Parameters:
## - scene: The loaded gameplay scene node (already added to tree)
## - scene_id: The scene's registry ID
## - managers: Dictionary containing "spawn_manager" and "state_store" references
func on_load(scene: Node, scene_id: StringName, managers: Dictionary) -> void:
	# Spawn player at target spawn point via M_SpawnManager
	# This happens AFTER scene is added to tree and _ready() has fired
	var spawn_manager = managers.get("spawn_manager")
	if spawn_manager != null:
		await spawn_manager.spawn_at_last_spawn(scene)


## No special cleanup needed for gameplay scenes.
func on_unload(scene: Node, scene_id: StringName) -> void:
	pass


## Gameplay scenes require M_SpawnManager and M_StateStore.
func get_required_managers() -> Array[StringName]:
	return [StringName("spawn_manager"), StringName("state_store")]


## Gameplay scenes clear navigation history (do not track).
func should_track_history() -> bool:
	return false


## Returns "gameplay" shell ID.
func get_shell_id() -> StringName:
	return StringName("gameplay")


## Dispatches start_game() navigation action.
func get_navigation_action(scene_id: StringName) -> Dictionary:
	return U_NAVIGATION_ACTIONS.start_game(scene_id)
