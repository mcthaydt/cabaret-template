# Base Scene Defaults Design

**Date:** 2026-04-30
**Context:** Update the canonical `tmpl_base_scene.tscn` with proper hybrid defaults: grid-textured room, tuned camera, and working wall/ceiling fading.

## Scope

Modify the static content of `tmpl_base_scene.tscn` and its dependencies:
- Room geometry (CSGBox3D walls, floor, ceiling)
- Grid texture material (moved from demo to core)
- Camera orbit defaults (FOV, distance, pitch)
- Wall/ceiling fading defaults
- Sky/environment (solid black)

Does **not** change system logic, ECS architecture, or runtime behavior beyond config values.

## Room Geometry

Single 5m x 5m x 5m (WxDxH) square room, centered at origin.

| Element | Dimensions | Position (center) | Notes |
|---------|-----------|-------------------|-------|
| Floor | 5 x 0.2 x 5 | (0, 0, 0) | Surface at y=0; collision enabled |
| West wall | 0.2 x 5 x 5 | (-2.5, 2.5, 0) | With C_RoomFadeGroupComponent |
| East wall | 0.2 x 5 x 5 | (2.5, 2.5, 0) | With C_RoomFadeGroupComponent |
| North wall | 5 x 5 x 0.2 | (0, 2.5, 2.5) | With C_RoomFadeGroupComponent |
| South wall | 5 x 5 x 0.2 | (0, 2.5, -2.5) | With C_RoomFadeGroupComponent |
| Ceiling | 5 x 0.2 x 5 | (0, 5, 0) | Collision enabled |

Each wall:
- Has `C_RoomFadeGroupComponent` with its outward-facing `fade_normal` (e.g., west = (-1, 0, 0))
- Tagged with `"room_fade_group"` via `BaseECSEntity`

All geometry uses the unshaded grid material.

## Grid Texture & Material

- Copy `assets/demo/textures/prototype_grids_png/Dark/tex_texture_01.png` to `assets/core/textures/prototype_grids/tex_texture_01.png`
- `StandardMaterial3D` applied to all room geometry:
  - `shading_mode = 2` (unshaded)
  - `albedo_texture` = grid texture
  - `texture_filter` = nearest (pixel art)

This moves the grid texture into core, satisfying the core-never-imports-demo constraint.

## Camera Defaults

### Orbit Mode (`cfg_default_orbit.tres`)

| Parameter | Before | After |
|-----------|--------|-------|
| FOV | 28.8415 | 39.5978 |
| Distance | 12.5 | 5.0 |
| Authored Pitch | -30.0 | -36.87 |

At distance 5.0, pitch -36.87 the camera sits exactly 3m above and 4m away from the player's feet.

### Camera State Component (`C_CameraStateComponent`)

Set `base_fov = 39.5978` in `tmpl_camera.tscn` to prevent the "ensure baseline" logic from overwriting the FOV.

### Camera Root Position

`E_CameraRoot` in `tmpl_base_scene.tscn` stays at default transform (no static offset). The VCam orbit mode handles all positioning relative to `CameraFollowAnchor`.

## Environment

`WorldEnvironment` settings:
- `background_mode = 1` (color)
- `background_color = Color(0, 0, 0, 1)` (solid black)

## Wall/Ceiling Fading

### Wall Visibility Config (`cfg_wall_visibility_config_default.tres`)

| Setting | Before | After | Reason |
|---------|--------|-------|--------|
| `fade_speed` | 4.0 | 6.0 | More responsive fade transitions |
| `min_alpha` | 0.05 | 0.0 | Full dissolve (grid texture provides spatial context) |
| `corridor_occlusion_margin` | 2.0 | 3.0 | Wider corridor check in 5m room |

### Fading system behavior (S_WallVisibilitySystem -- unchanged in code)

- Directional fade: walls between camera and player dissolve based on camera facing
- Corridor occlusion: forces fade for walls in the camera-player corridor
- Roof detection: ceiling fades when a wall in the same region already fades
- Bucket continuity: adjacent wall segments in the same normal bucket share fade state

The new defaults ensure the player is always visible through walls.

## Implementation Plan

### Files to modify

| File | Change |
|------|--------|
| `scenes/core/templates/tmpl_base_scene.tscn` | Replace room geometry, update E_CameraRoot position |
| `scenes/core/templates/tmpl_camera.tscn` | Set `C_CameraStateComponent.base_fov = 39.5978` |
| `resources/core/display/vcam/cfg_default_orbit.tres` | Update FOV, distance, pitch |
| `resources/core/base_settings/gameplay/cfg_wall_visibility_config_default.tres` | Update fade_speed, min_alpha, corridor_occlusion_margin |

### Files to create

| File | Purpose |
|------|---------|
| `assets/core/textures/prototype_grids/tex_texture_01.png` | Copied grid texture |
| `assets/core/textures/prototype_grids/tex_texture_01.png.import` | Import config |

### Files to extend

| File | Change |
|------|--------|
| `scripts/core/utils/editors/u_editor_blockout_builder.gd` | Add helper to produce room geometry nodes (staying under 200-line cap) |
| `scripts/core/editors/build_base_scene.gd` (new) | Orchestration script that uses the builder, adds camera/systems/entities/fade components, saves to `tmpl_base_scene.tscn` |

### Build script flow

1. Instantiate `U_EditorBlockoutBuilder`, call geometry methods to create floor, 4 walls, ceiling
2. Apply grid material to all CSGBox3D nodes
3. Add `C_RoomFadeGroupComponent` + `BaseECSEntity` to each wall
4. Instance `tmpl_camera.tscn` as `E_CameraRoot`
5. Instance `prefab_player.tscn` as `E_Player`
6. Instance remaining systems and managers (preserving existing template structure)
7. Save to `tmpl_base_scene.tscn`

### Testing

- Run `tools/run_gut_suite.sh -gtest=res://tests/integration/test_base_scene_contract.gd` to verify container structure
- Run `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` after file/naming/structure changes
- Manual visual check: player character visible in all four cardinal directions with appropriate wall fading

### Constraints

- Builder class stays under 200-line LOC cap -- if adding methods pushes it over, extract a helper
- Core never imports demo -- grid texture is copied, not referenced
- Commits follow TDD workflow with (RED)/(GREEN) markers

## Dependencies

- Requires Phase 5 (base scene cleanup) to be complete or deferred
- No new autoloads or manager registration needed
