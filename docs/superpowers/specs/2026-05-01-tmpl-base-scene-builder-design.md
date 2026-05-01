# Design: tmpl_base_scene Builder

**Date**: 2026-05-01
**Status**: Approved

## Problem

The project has `tmpl_base_scene.tscn` (the base gameplay room template) authored by hand as a Godot scene file. There is a builder (`build_gameplay_demo_room.gd`) that instantiates this template and adds a spawn point to produce `gameplay_demo_room.tscn`, but there is no builder that generates `tmpl_base_scene.tscn` itself. This means the template can only be modified in-editor, not programmatically.

## Solution

A `U_TemplateBaseSceneBuilder` (`RefCounted`) that builds the complete `tmpl_base_scene.tscn` node tree programmatically. A thin `@tool extends EditorScript` adapter calls it. The generated output **replaces** the hand-authored `.tscn` as the source of truth.

## Files

| Layer | File | Notes |
|-------|------|-------|
| Builder | `scripts/core/utils/editors/u_template_base_scene_builder.gd` | `RefCounted`, fluent, builds full scene tree |
| EditorScript adapter | `scripts/demo/editors/build_tmpl_base_scene.gd` | ~5-line wrapper |
| Test | `tests/unit/editors/test_u_template_base_scene_builder.gd` | Structural equivalence verification |
| Output | `scenes/core/templates/tmpl_base_scene.tscn` | Generated from builder |

## Architecture

The builder follows the fluent pattern established by `U_EditorBlockoutBuilder`:

- `create_root()` — creates `GameplayRoot` with its script
- `.add_child_node(parent, type, name, props)` — generic child node helper
- Private helpers per scene group: `_build_scene_objects(root)`, `_build_environment(root)`, `_build_systems(root)`, `_build_managers(root)`, `_build_entities(root)`
- `.save(path)` — packs into `PackedScene` and saves
- Returns `true`/`false` from `save()`

### Scene tree to generate

```
GameplayRoot (Node3D, script=root.gd)
├── SceneObjects (Node3D, marker_scene_objects_group.gd)
│   ├── SO_Floor (CSGBox3D, 30x0.01x30, grid texture material)
│   ├── SO_Ceiling (CSGBox3D, y=30, 30x0.01x30, wall_cutout material)
│   ├── SO_Wall_West (CSGBox3D, x=-15 y=15, 0.01x30x30)
│   │   ├── BaseECSEntity script, entity_id="wall_west", tags=["room_fade_group"]
│   │   └── C_RoomFadeGroupComponent (group_tag="wall_west", fade_normal=(-1,0,0))
│   ├── SO_Wall_East (x=15 y=15, 0.01x30x30)
│   │   ├── BaseECSEntity script, entity_id="wall_east", tags=["room_fade_group"]
│   │   └── C_RoomFadeGroupComponent (group_tag="wall_east", fade_normal=(1,0,0))
│   ├── SO_Wall_North (y=15 z=-15, 30x30x0.01)
│   │   ├── BaseECSEntity script, entity_id="wall_north", tags=["room_fade_group"]
│   │   └── C_RoomFadeGroupComponent (group_tag="wall_north")
│   └── SO_Wall_South (y=15 z=15, 30x30x0.01)
│       ├── BaseECSEntity script, entity_id="wall_south", tags=["room_fade_group"]
│       └── C_RoomFadeGroupComponent (group_tag="wall_south", fade_normal=(0,0,1))
├── Environment (Node, marker_environment_group.gd)
│   ├── Env_WorldEnvironment (WorldEnvironment, black background)
│   └── Env_DirectionalLight3D (light color (0.56,0.83,1), energy 1.5)
├── Systems (Node, marker_systems_group.gd)
│   ├── Core (Node)
│   │   ├── S_InputSystem
│   │   ├── S_VCamSystem (priority 100)
│   │   └── S_WallCutoutSystem (with config resource)
│   ├── Physics (Node)
│   │   ├── S_GravitySystem (priority 60)
│   │   └── S_JumpSystem (priority 75)
│   ├── Movement (Node)
│   │   ├── S_MovementSystem (priority 50)
│   │   ├── S_FloatingSystem (priority 70)
│   │   ├── S_SpawnRecoverySystem (priority 75)
│   │   ├── S_RotateToInputSystem (priority 80)
│   │   └── S_AlignWithSurfaceSystem (priority 90)
│   └── Feedback (Node)
│       ├── S_LandingIndicatorSystem (priority 110)
│       ├── S_JumpParticlesSystem (priority 120)
│       ├── S_JumpSoundSystem (priority 121)
│       ├── S_LandingParticlesSystem
│       └── S_GamepadVibrationSystem (priority 122)
├── Managers (Node, marker_managers_group.gd)
│   └── M_ECSManager
└── Entities (Node, marker_entities_group.gd)
    ├── E_Player (instance of prefab_player.tscn)
    ├── E_CameraRoot (instance of tmpl_camera.tscn)
    └── SpawnPoints (Node3D, marker_spawn_points_group.gd) -- empty
```

## Conventions

Per [ADR 0011](https://github.com/anomalyco/opencode/issues) and `docs/architecture/extensions/builders.md`:
- Builder logic in `RefCounted`, never `EditorScript`
- File under 200 lines; extract helpers if it exceeds
- `_set_owner_recursive()` on all children before packing
- `build_gameplay_demo_room.gd` will be updated to call the same builder instead of loading the `.tscn` template directly (future step)

## Test Strategy

The test for `build_tmpl_base_scene.gd` (EditorScript adapter) runs with `get_orchestrator().execute_editor_script()` per the GUT EditorScript testing pattern. It verifies the generated scene exists and can be instantiated.

The `build_gameplay_demo_room.gd` test also runs via `execute_editor_script()` and verifies the demo room scene exists with a `sp_default` spawn point under `SpawnPoints`.

A structural equivalence test instantiates both the generated scene and the current hand-authored template (before replacement), walks both trees, and asserts:
- Node name, type, script, position match
- Material references match on CSG boxes
- ECS component existence and field values match on wall entities
- Child counts match per group

## Out of scope

- Updating `build_gameplay_demo_room.gd` to use the builder rather than loading the template `.tscn` (future step)
- Any changes to `gameplay_demo_room.tscn` structure
- Wall/ceiling fading, hybrid camera, or other base-scene systems — this builder just reproduces what exists
