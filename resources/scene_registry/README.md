# Scene Registry Resources

This directory contains scene registration resources that allow non-coders to add new scenes without modifying code.

## How to Add a New Scene

### Option 1: Via Godot Editor (Recommended for Non-Coders)

1. In Godot editor, go to: `FileSystem` → `resources/scene_registry/`
2. Right-click → `New Resource`
3. Search for and select: `RS_SceneRegistryEntry`
4. Configure the resource properties:
   - **scene_id**: Unique name (e.g., "my_level")
   - **scene_path**: Path to .tscn file (use file picker)
   - **scene_type**: Choose UI, GAMEPLAY, or END_GAME
   - **default_transition**: Choose instant, fade, or loading
   - **preload_priority**: 0-15 (10+ for critical scenes)
5. Save as: `<scene_name>.tres`
6. Scene will be automatically loaded on next game start

### Option 2: Via GDScript (For Coders)

```gdscript
var entry := RS_SceneRegistryEntry.new()
entry.scene_id = "my_level"
entry.scene_path = "res://scenes/levels/my_level.tscn"
entry.scene_type = 1  # GAMEPLAY
entry.default_transition = "fade"
entry.preload_priority = 5
ResourceSaver.save(entry, "res://resources/scene_registry/my_level.tres")
```

## Scene Type Guide

- **UI (0)**: Menus, settings screens - shows cursor, no pause
- **GAMEPLAY (1)**: Interactive levels - hides cursor, allows pause
- **END_GAME (2)**: Game over, victory screens - shows cursor

## Preload Priority Guide

- **10-15**: Critical scenes (main menu, pause) - preloaded at startup
- **5-9**: Common scenes - preloaded when memory allows
- **0-4**: Rare scenes - loaded on-demand

**Note**: Preloaded scenes transition instantly (< 0.5s). On-demand scenes take 1-3s to load.

## Example Scenes

**Currently migrated scenes (see .tres files in this directory)**:
- `gameplay_base.tres`: GAMEPLAY, loading, priority 8
- `exterior.tres`: GAMEPLAY, fade, priority 6
- `interior_house.tres`: GAMEPLAY, fade, priority 6
- `ui_game_over.tres`: END_GAME, fade, priority 8
- `ui_victory.tres`: END_GAME, fade, priority 5
- `ui_credits.tres`: END_GAME, fade, priority 0

**Critical scenes (kept hardcoded in U_SceneRegistry)**:
- main_menu: MENU, fade, priority 10
- settings_menu: UI, instant, priority 10
- pause_menu: UI, instant, priority 10
- loading_screen: UI, instant, priority 10

## Troubleshooting

**Scene not loading?**
- Check scene_id is unique (not already used)
- Verify scene_path points to existing .tscn file
- Ensure .tres file is saved in this directory
- Check console for errors during startup

**Can't find my scene in registry?**
- Resources are loaded once at startup via `U_SceneRegistry._static_init()`
- Restart game/editor to reload resources
- Check that .tres file has correct RS_SceneRegistryEntry type
