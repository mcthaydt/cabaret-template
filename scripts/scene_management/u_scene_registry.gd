extends RefCounted
class_name U_SceneRegistry

## Static scene metadata registry
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

## Door pairing dictionary
## Key: scene_id (StringName)
## Value: Dictionary[door_id (StringName)] -> exit_data (Dictionary)
static var _door_exits: Dictionary = {}

## Static initializer - registers all scenes and door pairings
static func _static_init() -> void:
	_register_scenes()
	_register_door_pairings()

## Register all scenes with metadata
static func _register_scenes() -> void:
	# Main Menu
	_register_scene(
		StringName("main_menu"),
		"res://scenes/ui/main_menu.tscn",
		SceneType.MENU,
		"fade",
		5  # Medium priority - load after boot
	)

	# Settings Menu
	_register_scene(
		StringName("settings_menu"),
		"res://scenes/ui/settings_menu.tscn",
		SceneType.UI,
		"instant",
		3  # Lower priority - overlay
	)

	# Gameplay Base
	_register_scene(
		StringName("gameplay_base"),
		"res://scenes/gameplay/gameplay_base.tscn",
		SceneType.GAMEPLAY,
		"loading",
		8  # High priority - core gameplay scene
	)

	# Example area scenes (for door pairing tests)
	_register_scene(
		StringName("exterior"),
		"res://scenes/gameplay/exterior.tscn",
		SceneType.GAMEPLAY,
		"fade",
		6
	)

	_register_scene(
		StringName("interior_house"),
		"res://scenes/gameplay/interior_house.tscn",
		SceneType.GAMEPLAY,
		"fade",
		6
	)

	# Test scenes (for unit tests)
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

	_register_scene(
		StringName("pause_menu"),
		"res://tests/scenes/test_pause_menu.tscn",
		SceneType.UI,
		"instant",
		0
	)

## Register door pairings for seamless area transitions
static func _register_door_pairings() -> void:
	# Exterior → Interior House
	_register_door_exit(
		StringName("exterior"),
		StringName("door_to_house"),
		StringName("interior_house"),
		StringName("entrance_from_exterior"),
		"fade"
	)

	# Interior House → Exterior
	_register_door_exit(
		StringName("interior_house"),
		StringName("door_to_exterior"),
		StringName("exterior"),
		StringName("exit_from_house"),
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
