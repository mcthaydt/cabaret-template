extends RefCounted
class_name U_SceneRegistry

## Static scene metadata registry
##
## T212: Now supports resource-based scene registration via RS_SceneRegistryEntry
const RS_SceneRegistryEntry := preload("res://scripts/resources/scene_management/rs_scene_registry_entry.gd")
const U_SceneRegistryLoader := preload("res://scripts/scene_management/helpers/u_scene_registry_loader.gd")
##
## Central registry for all scenes in the game. Provides scene metadata,
## door pairings, and validation. This is a static class - all data and
## methods are static.
##
## Scene Metadata:
## - scene_id: Unique identifier (StringName)
## - path: Resource path to .tscn file
## - scene_type: Type from SceneType enum
## - default_transition: Default transition effect (instant, fade, loading)
## - preload_priority: Priority for preloading (0=never, 10=critical)
##
## Door Pairings:
## - Maps (scene_id, door_id) -> (target_scene_id, target_spawn_point, transition_type)
## - Used for seamless area transitions

## Scene type enum
enum SceneType {
	MENU = 0,        # Menu scenes (main menu, character select)
	GAMEPLAY = 1,    # Gameplay scenes (areas, dungeons)
	UI = 2,          # UI overlay scenes (settings, pause menu)
	END_GAME = 3     # End game scenes (credits, game over)
}

## Scene metadata dictionary
## Key: scene_id (StringName)
## Value: Dictionary with scene metadata
static var _scenes: Dictionary = {}
static var _loader := U_SceneRegistryLoader.new()

## Door pairing dictionary
## Key: scene_id (StringName)
## Value: Dictionary[door_id (StringName)] -> exit_data (Dictionary)
static var _door_exits: Dictionary = {}

## Static initializer - registers all scenes and door pairings
##
## T212: Now loads resource-based scene entries from resources/scene_registry/
static func _static_init() -> void:
	_register_scenes()
	_load_resource_entries()  # T212: Load RS_SceneRegistryEntry resources
	_backfill_default_gameplay_scenes()
	_register_door_pairings()

## Register all scenes with metadata
##
## T212: CRITICAL scenes kept hardcoded for safety. Non-critical scenes moved to
## resources/scene_registry/cfg_*_entry.tres files for non-coder editing.
##
## CRITICAL (hardcoded for boot safety):
## - main_menu: Game entry point, must always work
## - settings_menu: Core UI, treated as critical
## - pause_menu: Preloaded at startup (priority 10)
## - loading_screen: Preloaded at startup (priority 10)
## - test scenes: Required for test suite
##
## NON-CRITICAL (migrated to .tres resources):
## - gameplay_base, exterior, interior_house → resources/scene_registry/
## - game_over, victory, credits → resources/scene_registry/
static func _register_scenes() -> void:
	# CRITICAL SCENES - Keep hardcoded for safety

	# Main Menu (game entry point)
	_register_scene(
		StringName("main_menu"),
		"res://scenes/ui/menus/ui_main_menu.tscn",
		SceneType.MENU,
		"fade",
		10  # Critical path - preload at startup (Phase 8)
	)

	# Settings Menu (user-designated critical)
	_register_scene(
		StringName("settings_menu"),
		"res://scenes/ui/menus/ui_settings_menu.tscn",
		SceneType.UI,
		"instant",
		10  # Upgraded to critical priority per user request
	)

	# Pause Menu (preloaded at startup)
	_register_scene(
		StringName("pause_menu"),
		"res://scenes/ui/menus/ui_pause_menu.tscn",
		SceneType.UI,
		"instant",
		10  # Critical path - preload at startup (Phase 8)
	)

	# Save/Load Menu (preloaded at startup)
	_register_scene(
		StringName("save_load_menu"),
		"res://scenes/ui/overlays/ui_save_load_menu.tscn",
		SceneType.UI,
		"instant",
		10  # Critical path - accessed from pause menu
	)

	# Loading Screen (preloaded at startup)
	_register_scene(
		StringName("loading_screen"),
		"res://scenes/ui/hud/ui_loading_screen.tscn",
		SceneType.UI,
		"instant",
		10  # Critical path - preload at startup (Phase 8)
	)

	# TEST SCENES - Keep hardcoded for test suite stability
	_register_scene(
		StringName("scene1"),
		"res://tests/scenes/test_scene1.tscn",
		SceneType.GAMEPLAY,
		"instant",
		0
	)

	_register_scene(
		StringName("scene2"),
		"res://tests/scenes/test_scene2.tscn",
		SceneType.GAMEPLAY,
		"instant",
		0
	)

	_register_scene(
		StringName("scene3"),
		"res://tests/scenes/test_scene3.tscn",
		SceneType.GAMEPLAY,
		"instant",
		0
	)

	# NON-CRITICAL SCENES - Migrated to resources/scene_registry/cfg_*_entry.tres
	# These scenes are now loaded via _load_resource_entries()
	# See: docs/scene_manager/ADDING_SCENES_GUIDE.md for details

## Load scene entries from resource files (T212)
##
## Scans resources/scene_registry/ for RS_SceneRegistryEntry .tres files and
## registers each scene. This allows non-coders to add scenes via editor UI.
##
## **Phase 11 improvement** (T212):
## - Scans directory for .tres files
## - Loads each RS_SceneRegistryEntry resource
## - Calls _register_scene() with resource data
## - Skips invalid or duplicate scenes
## - Maintains backward compatibility with hardcoded scenes
##
## **Non-coder workflow**:
## 1. Create new RS_SceneRegistryEntry resource in editor
## 2. Configure scene_id, scene_path, scene_type, etc.
## 3. Save as resources/scene_registry/cfg_<name>_entry.tres
## 4. Scene auto-loads on next game start
static func _load_resource_entries() -> void:
	_loader.load_resource_entries(_scenes, Callable(U_SceneRegistry, "_register_scene"))

## Ensure critical gameplay, settings, and end-game scenes are registered even
## if resources are missing. This provides a safety net for exports where
## resource-based entries might be excluded by filters (e.g., mobile builds).
## If resource entries exist, this is a no-op.
static func _backfill_default_gameplay_scenes() -> void:
	_loader.backfill_default_gameplay_scenes(_scenes, Callable(U_SceneRegistry, "_register_scene"))

## Register door pairings for seamless area transitions
static func _register_door_pairings() -> void:
	# Exterior → Interior Bar (main door)
	_register_door_exit(
		StringName("exterior"),
		StringName("door_to_house"),
		StringName("interior_bar"),
		StringName("sp_entrance_from_exterior"),
		"fade"
	)

	# Interior Bar → Exterior
	_register_door_exit(
		StringName("interior_bar"),
		StringName("door_to_exterior"),
		StringName("exterior"),
		StringName("sp_exit_from_house"),
		"fade"
	)

	# Exterior → Interior Bar (second door)
	_register_door_exit(
		StringName("exterior"),
		StringName("door_to_bar"),
		StringName("interior_bar"),
		StringName("sp_entrance_from_exterior"),
		"fade"
	)

	# Interior House → Exterior (kept for backward compatibility)
	_register_door_exit(
		StringName("interior_house"),
		StringName("door_to_exterior"),
		StringName("exterior"),
		StringName("sp_exit_from_house"),
		"fade"
	)

## Register a single scene
static func _register_scene(
	scene_id: StringName,
	path: String,
	scene_type: int,
	default_transition: String,
	preload_priority: int
) -> void:
	_scenes[scene_id] = {
		"scene_id": scene_id,
		"path": path,
		"scene_type": scene_type,
		"default_transition": default_transition,
		"preload_priority": preload_priority
	}

## Register a door exit (one-way pairing)
static func _register_door_exit(
	scene_id: StringName,
	door_id: StringName,
	target_scene_id: StringName,
	target_spawn_point: StringName,
	transition_type: String
) -> void:
	if not _door_exits.has(scene_id):
		_door_exits[scene_id] = {}

	_door_exits[scene_id][door_id] = {
		"target_scene_id": target_scene_id,
		"target_spawn_point": target_spawn_point,
		"transition_type": transition_type
	}

## Get scene metadata by scene_id
static func get_scene(scene_id: StringName) -> Dictionary:
	if _scenes.has(scene_id):
		return _scenes[scene_id].duplicate(true)
	return {}

## Get scene path by scene_id (convenience method)
static func get_scene_path(scene_id: StringName) -> String:
	var scene_data: Dictionary = get_scene(scene_id)
	return scene_data.get("path", "")

## Get scene type by scene_id (convenience method)
static func get_scene_type(scene_id: StringName) -> int:
	var scene_data: Dictionary = get_scene(scene_id)
	return scene_data.get("scene_type", -1)

## Get default transition by scene_id (convenience method)
static func get_default_transition(scene_id: StringName) -> String:
	var scene_data: Dictionary = get_scene(scene_id)
	return scene_data.get("default_transition", "instant")

## Get door exit metadata
static func get_door_exit(scene_id: StringName, door_id: StringName) -> Dictionary:
	if not _door_exits.has(scene_id):
		return {}

	var scene_doors: Dictionary = _door_exits[scene_id]
	if scene_doors.has(door_id):
		return scene_doors[door_id].duplicate(true)

	return {}

## Get all registered scenes
static func get_all_scenes() -> Array:
	var result: Array = []
	for scene_data in _scenes.values():
		result.append(scene_data.duplicate(true))
	return result

## Get scenes filtered by type
static func get_scenes_by_type(scene_type: int) -> Array:
	var result: Array = []
	for scene_data in _scenes.values():
		if scene_data["scene_type"] == scene_type:
			result.append(scene_data.duplicate(true))
	return result

## Get all scenes with preload_priority >= min_priority
##
## Used by Scene Manager to determine which scenes to preload at startup.
## Default min_priority of 10 returns only "critical path" scenes.
##
## Returns: Array of scene metadata dictionaries
static func get_preloadable_scenes(min_priority: int = 10) -> Array:
	var result: Array = []
	for scene_data in _scenes.values():
		var priority: int = scene_data.get("preload_priority", 0)
		if priority >= min_priority:
			result.append(scene_data.duplicate(true))
	return result

## Validate door pairings for consistency
##
## Checks that:
## - All target scenes exist in registry
## - Door pairings form valid bidirectional connections (optional, logged as warning)
##
## Returns true if all validations pass (errors only), false otherwise.
static func validate_door_pairings() -> bool:
	var is_valid: bool = true

	# Check all door exits reference valid scenes
	for scene_id in _door_exits:
		if not _scenes.has(scene_id):
			push_error("U_SceneRegistry: Door exit references non-existent scene: %s" % scene_id)
			is_valid = false
			continue

		var scene_doors: Dictionary = _door_exits[scene_id]
		for door_id in scene_doors:
			var exit_data: Dictionary = scene_doors[door_id]
			var target_scene: StringName = exit_data.get("target_scene_id", StringName(""))

			if target_scene == StringName(""):
				push_error("U_SceneRegistry: Door exit %s/%s has empty target_scene_id" % [scene_id, door_id])
				is_valid = false
				continue

			if not _scenes.has(target_scene):
				push_error("U_SceneRegistry: Door exit %s/%s targets non-existent scene: %s" % [scene_id, door_id, target_scene])
				is_valid = false

	return is_valid
