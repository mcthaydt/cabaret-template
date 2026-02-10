## Interface for scene type-specific behavior handlers.
##
## Implementations define how different scene types (GAMEPLAY, MENU, UI, END_GAME)
## should be loaded, unloaded, and managed by M_SceneManager.
##
## Usage:
## - Create a handler class extending I_SCENE_TYPE_HANDLER
## - Implement all methods to define scene-type-specific behavior
## - Register handler in M_SceneManager._register_scene_type_handlers()
##
## Example:
## [codeblock]
## class_name H_GameplaySceneHandler extends I_SCENE_TYPE_HANDLER
##
## func get_scene_type() -> int:
##     return U_SCENE_REGISTRY.SceneType.GAMEPLAY
##
## func on_load(scene: Node, scene_id: StringName, managers: Dictionary) -> void:
##     scene_manager.mark_scene_spawned(scene)
##     var spawn_manager = managers.get("spawn_manager")
##     if spawn_manager != null:
##         await spawn_manager.spawn_at_last_spawn(scene)
## [/codeblock]
class_name I_SCENE_TYPE_HANDLER
extends RefCounted


## Returns the SceneType this handler manages (from U_SCENE_REGISTRY.SceneType enum)
##
## This method MUST be overridden by subclasses to return a valid SceneType enum value.
## The interface pushes an error if called directly to enforce implementation.
##
## Returns: int - SceneType enum value (MENU, GAMEPLAY, UI, or END_GAME)
func get_scene_type() -> int:
	push_error("I_SCENE_TYPE_HANDLER.get_scene_type() must be implemented by subclass")
	return -1


## Called when a scene of this type is loaded.
##
## Override this method to perform scene-type-specific initialization.
## Common tasks: spawning player, setting metadata, configuring scene state.
##
## Parameters:
## - scene: The loaded scene node (added to ActiveSceneContainer)
## - scene_id: The scene's registry ID (StringName)
## - managers: Dictionary of manager references for this scene type
##            (e.g., {"spawn_manager": M_SpawnManager, "state_store": M_StateStore})
##
## Note: This method may be async (use await for manager calls)
func on_load(_scene: Node, _scene_id: StringName, _managers: Dictionary) -> void:
	pass


## Called when a scene of this type is unloaded.
##
## Override this method to perform scene-type-specific cleanup.
## Common tasks: saving state, clearing caches, disconnecting signals.
##
## Parameters:
## - scene: The scene node being unloaded
## - scene_id: The scene's registry ID (StringName)
func on_unload(_scene: Node, _scene_id: StringName) -> void:
	pass


## Returns array of required manager group names for this scene type.
##
## M_SceneManager uses this to verify required managers are available before
## loading scenes of this type. Handlers should list all managers they access
## in on_load() to enable dependency validation.
##
## Returns: Array[StringName] - Group names of required managers
##          (e.g., [StringName("spawn_manager"), StringName("state_store")])
##
## Example:
## [codeblock]
## func get_required_managers() -> Array[StringName]:
##     return [StringName("spawn_manager"), StringName("state_store")]
## [/codeblock]
func get_required_managers() -> Array[StringName]:
	return []


## Returns whether this scene type should be tracked in navigation history.
##
## When true, M_SceneManager tracks the scene in navigation history, enabling
## back button navigation. When false, loading this scene clears history.
##
## Typical values:
## - GAMEPLAY: false (clears history stack)
## - MENU/UI: true (enables back navigation)
## - END_GAME: false (end state, no back navigation)
##
## Returns: bool - true if scene should be tracked in history
func should_track_history() -> bool:
	return false


## Returns the navigation shell ID for this scene type.
##
## The shell ID determines which UI shell state the navigation slice should
## be in when this scene type is active.
##
## Typical values:
## - GAMEPLAY: StringName("gameplay")
## - MENU/UI: StringName("main_menu")
## - END_GAME: StringName("endgame")
##
## Returns: StringName - Shell ID for navigation state
func get_shell_id() -> StringName:
	return StringName("")


## Returns the navigation action to dispatch when loading this scene type.
##
## M_SceneManager calls this to get the Redux action that should be dispatched
## to update navigation state when a scene of this type is loaded.
##
## Parameters:
## - scene_id: The scene being loaded (StringName)
##
## Returns: Dictionary - Redux action with "type" and "payload" fields,
##                       or empty dict if no action needed
##
## Example:
## [codeblock]
## func get_navigation_action(scene_id: StringName) -> Dictionary:
##     return U_NAVIGATION_ACTIONS.start_game(scene_id)
## [/codeblock]
func get_navigation_action(_scene_id: StringName) -> Dictionary:
	return {}
