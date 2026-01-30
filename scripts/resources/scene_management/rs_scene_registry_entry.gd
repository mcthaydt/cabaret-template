extends Resource
class_name RS_SceneRegistryEntry

## Scene Registry Entry Resource
##
## Allows scene registration via editor UI without code modifications.
## Non-coders can create .tres files with scene metadata instead of editing
## U_SceneRegistry code.
##
## **Phase 11 improvement** (T212):
## - Improves user-friendliness from 85% to 95%
## - Allows scene registration via editor resources
## - No code changes needed to add new scenes
##
## **Usage:**
## 1. Create new RS_SceneRegistryEntry resource in editor
## 2. Save to `resources/scene_registry/cfg_<scene_name>_entry.tres`
## 3. Scene will be auto-loaded on startup
##
## **Example:**
## ```gdscript
## # Create in editor or via script:
## var entry := RS_SceneRegistryEntry.new()
## entry.scene_id = "my_level"
## entry.scene_path = "res://scenes/levels/my_level.tscn"
## entry.scene_type = SceneType.GAMEPLAY
## entry.default_transition = "fade"
## entry.preload_priority = 5
## ResourceSaver.save(entry, "res://resources/scene_registry/cfg_my_level_entry.tres")
## ```

## Unique identifier for this scene (e.g., "main_menu", "level_01")
@export var scene_id: StringName = StringName("")

## Path to the scene file (e.g., "res://scenes/ui/ui_main_menu.tscn")
@export_file("*.tscn") var scene_path: String = ""

## Scene type (determines behavior like cursor visibility, pause handling)
##
## Available types:
## - MENU (0): Main menu and character select screens - unlocked cursor
## - GAMEPLAY (1): Interactive gameplay scenes - locked cursor
## - UI (2): UI overlay scenes (pause, settings) - unlocked cursor
## - END_GAME (3): End-game screens (game over, victory, credits) - unlocked cursor
@export_enum("MENU:0", "GAMEPLAY:1", "UI:2", "END_GAME:3") var scene_type: int = 0

## Default transition effect when entering this scene
##
## Available transitions:
## - "instant": No visual effect, immediate swap
## - "fade": Fade to black/color transition (0.2s)
## - "loading": Loading screen with progress bar (for large scenes)
@export_enum("instant", "fade", "loading") var default_transition: String = "fade"

## Preload priority (higher = preloaded earlier)
##
## Priority levels:
## - 10+: Critical scenes (main_menu, pause_menu) - preloaded at startup
## - 5-9: Common scenes - preloaded when memory allows
## - 0-4: Rare scenes - loaded on-demand only
##
## **Preload benefit**: Instant transitions (< 0.5s) vs on-demand (1-3s)
@export_range(0, 15) var preload_priority: int = 0

## Validate resource configuration
##
## Called by editor to check for common configuration errors.
## Logs warnings if scene_id or scene_path are empty.
func _validate_property(property: Dictionary) -> void:
	# Validation runs in editor, warn about common mistakes
	if property.name == "scene_id" and scene_id.is_empty():
		push_warning("RS_SceneRegistryEntry: scene_id is empty. Assign a unique identifier (e.g., 'main_menu').")

	if property.name == "scene_path" and scene_path.is_empty():
		push_warning("RS_SceneRegistryEntry: scene_path is empty. Assign a path to your .tscn file.")

## Get scene type as enum for programmatic access
##
## Returns the scene_type as U_SceneRegistry.SceneType enum value.
## Useful for type-safe code that checks scene types.
func get_scene_type_enum() -> int:
	return scene_type

## Check if this scene should be preloaded at startup
##
## Returns true if preload_priority >= 10 (critical scenes).
func is_critical_scene() -> bool:
	return preload_priority >= 10

## Get human-readable scene type name
##
## Returns "MENU", "GAMEPLAY", "UI", or "END_GAME" for display in editor or debug output.
func get_scene_type_name() -> String:
	match scene_type:
		0: return "MENU"
		1: return "GAMEPLAY"
		2: return "UI"
		3: return "END_GAME"
		_: return "UNKNOWN"

## Check if resource is valid for registration
##
## Returns true if scene_id and scene_path are both non-empty.
## Used by U_SceneRegistry to filter out incomplete resources.
func is_valid() -> bool:
	return not scene_id.is_empty() and not scene_path.is_empty()

## Get resource summary for debugging
##
## Returns a formatted string with key resource properties.
func get_description() -> String:
	return "SceneEntry[%s]: %s (%s, priority %d)" % [scene_id, scene_path, get_scene_type_name(), preload_priority]
