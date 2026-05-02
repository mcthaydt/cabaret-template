# Sprite Zone Lighting Shader — Design

**Date**: 2026-05-02
**Status**: Approved
**Approach**: Extend existing pipeline (Approach A)

## Goal

Create a spatial shader for Sprite3D that replicates the unlit-but-zone-lit behavior of `sh_character_zone_lighting.gdshader`, and integrate Sprite3D into the existing zone lighting pipeline so the player sprite receives zone tints and intensities.

## Background

- `sh_character_zone_lighting.gdshader` applies zone lighting to `MeshInstance3D` character visuals via `render_mode unshaded` — no physical light response, ALBEDO computed from `albedo_sample * base_tint * effective_tint * effective_intensity`, with a `minimum_unlit_floor` (default 0.2) emitted as `EMISSION`.
- `U_CharacterLightingMaterialApplier` currently only targets `MeshInstance3D` — it recursively finds mesh children and applies the shader.
- `M_CharacterLightingManager._physics_process()` discovers zones, blends profiles, and calls the applier for each `character`-tagged entity.
- The player's `DirectionalSprite` (in `prefab_player_body.tscn`) has no `material_override` and receives no zone lighting.

## Changes

### 1. New Shader: `sh_sprite_zone_lighting.gdshader`

**Location**: `assets/core/shaders/`

Identical uniforms and fragment math to `sh_character_zone_lighting.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture : source_color;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec4 effective_tint : source_color = vec4(1.0);
uniform float effective_intensity : hint_range(0.0, 8.0, 0.01) = 1.0;
uniform float minimum_unlit_floor : hint_range(0.0, 1.0, 0.01) = 0.2;
```

Separate file from the mesh shader for independent management, even though math is identical.

### 2. Material Applier Extension: `U_CharacterLightingMaterialApplier`

New methods added to the existing class:

- **`apply_sprite_lighting(character_entity, base_tint, effective_tint, effective_intensity)`** — mirrors `apply_character_lighting()` but targets `Sprite3D` nodes.
- **`restore_sprite_materials(character_entity)`** — clears `material_override` on discovered sprites.
- **`collect_sprite_targets(entity)`** — recursively finds `Sprite3D` children with non-null `texture`.
- **`_apply_sprite_override(sprite, base_tint, effective_tint, effective_intensity)`** — extracts texture from `Sprite3D.texture`, creates/retrieves `ShaderMaterial` with the sprite shader, sets uniforms, assigns `sprite.material_override`.
- **Shared cache** — the existing `_material_cache` (keyed by `instance_id`) works for both `MeshInstance3D` and `Sprite3D`; no separate cache needed.
- **New preload constant**: `SH_SPRITE_ZONE_LIGHTING` pointing to the new shader file.

The second `Shader` preload requires a per-instance `_sprite_shader` field alongside the existing `_shader` field. The `_ensure_shader_material` method is generalized to accept a `shader` parameter.

### 3. Lighting Manager Integration: `M_CharacterLightingManager`

In `_apply_lighting_to_characters()`, after the existing `_material_applier.apply_character_lighting()` call:
- Add `_material_applier.apply_sprite_lighting(character_node, Color.WHITE, effective_tint, effective_intensity)`.

In `_update_character_entities()`, when a character is removed:
- Add `_material_applier.restore_sprite_materials(previous)` alongside existing `restore_character_materials()`.

No changes to zone discovery, blend math, temporal smoothing, or hysteresis.

### 4. Prefab Builder Update: `build_prefab_player_body.gd`

After creating the `DirectionalSprite` and setting its texture, assign a `ShaderMaterial` with `sh_sprite_zone_lighting.gdshader`, setting `albedo_texture` to the player spritesheet:

```gdscript
const SH_SPRITE_ZONE_LIGHTING := preload("res://assets/core/shaders/sh_sprite_zone_lighting.gdshader")

# After texture assignment, before add_child_to:
var sprite_shader_material := ShaderMaterial.new()
sprite_shader_material.shader = SH_SPRITE_ZONE_LIGHTING
sprite_shader_material.set_shader_parameter("albedo_texture", sprite_texture)
sprite.material_override = sprite_shader_material
```

The `GroundIndicator` (shadow blob) is NOT given the shader.

### 5. Contract Test Update: `test_base_scene_contract.gd`

New assertion: `DirectionalSprite.material_override` is a `ShaderMaterial` whose `.shader` matches `sh_sprite_zone_lighting.gdshader`.

## Files Touched

| File | Change |
|------|--------|
| `assets/core/shaders/sh_sprite_zone_lighting.gdshader` | New file |
| `scripts/core/utils/lighting/u_character_lighting_material_applier.gd` | Add sprite methods + preload |
| `scripts/core/managers/m_character_lighting_manager.gd` | Call sprite applier in `_apply_lighting_to_characters` and `_update_character_entities` |
| `scripts/demo/editors/build_prefab_player_body.gd` | Wire up default sprite shader material |
| `tests/integration/test_base_scene_contract.gd` | Add sprite shader material assertion |
| `scenes/core/prefabs/prefab_player_body.tscn` | Regenerated via builder |

## Constraints

- Core-never-imports-demo is enforced — the applier and shader live in `core/`.
- The builder stays under the 200-line LOC cap (currently 41 lines — well within).
- TDD workflow: test first, verify failure, implement, full suite, style enforcement.
