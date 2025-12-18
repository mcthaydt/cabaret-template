@icon("res://resources/editor_icons/manager.svg")
class_name M_GameplayInitializer
extends Node

## M_GameplayInitializer - Gameplay Scene Initialization Manager
##
## Ensures player spawns at sp_default when gameplay scene loads directly
## (not through M_SceneManager transition).
##
## This handles cases like:
## - Running gameplay_base.tscn directly in editor
## - Tests that load gameplay scenes directly
## - Initial game boot to gameplay scene
##
## Integration:
## - Add as child of gameplay scene root
## - Discovers M_SpawnManager via "spawn_manager" group
## - Only spawns if player is NOT already at spawn point

const M_SPAWN_MANAGER := preload("res://scripts/managers/m_spawn_manager.gd")

func _ready() -> void:
	# Get scene root early for metadata check
	var scene_root: Node = get_parent()
	if scene_root != null and scene_root.name == "Managers":
		scene_root = scene_root.get_parent()

	# Check if M_SceneManager already spawned the player BEFORE waiting
	# This prevents race condition since metadata is set synchronously
	# M_SceneManager sets metadata on scene root to indicate it handled spawning
	if scene_root != null and scene_root.has_meta("_scene_manager_spawned"):
		# Scene was loaded via M_SceneManager, which already called spawn_at_last_spawn
		# Skip redundant spawn to avoid clearing target_spawn_point twice
		return

	# Wait for scene tree to fully initialize
	await get_tree().process_frame
	await get_tree().physics_frame

	# Check if still in tree after awaits (may have been removed during test cleanup)
	if not is_inside_tree():
		return

	# Find spawn manager via ServiceLocator (Phase 10B-7: T141c)
	var spawn_manager: M_SPAWN_MANAGER = U_ServiceLocator.get_service(StringName("spawn_manager")) as M_SPAWN_MANAGER
	if spawn_manager == null:
		# No spawn manager available (e.g., running scene standalone in editor)
		# Silently skip - this is expected behavior
		return

	if scene_root == null:
		scene_root = get_tree().current_scene

	if scene_root == null:
		return

	# Spawn player at last spawn point (defaults to sp_default if no state)
	# This path is only reached when:
	# - Running gameplay_base.tscn directly in editor
	# - Loading gameplay scenes in tests
	# - Any other direct scene instantiation (NOT via M_SceneManager)
	await spawn_manager.spawn_at_last_spawn(scene_root)
