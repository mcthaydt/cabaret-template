# 2.5D Units And Scale Authoring Contract

## Purpose

This document defines the default world, tile, sprite, and collision scale for the Xenogears-style 2.5D direction. It is an authoring contract for future builders, templates, prefabs, and room blockouts; it does not migrate existing scenes by itself.

The goal is to keep 2D sprites readable inside 3D spaces while preserving simple snapping math for floors, walls, props, and camera framing.

## Core Unit Contract

Use this scale unless a focused system or asset document explicitly overrides it:

| Concept | Default |
|---------|---------|
| World unit | `1.0` Godot unit |
| Floor/wall tile | `1.0 x 1.0` Godot units |
| Source tile art | `128 x 128` pixels |
| Default humanoid visual width | `1.0` tile / `1.0` Godot unit |
| Default humanoid collision footprint | Smaller than the visual tile, usually `0.3-0.4` unit radius |
| Standard wall height | `3.0` tiles / `3.0` Godot units |

In short: `128px = 1 tile = 1 Godot world unit`.

`128 x 128` is the source art cell for one tile-sized visual unit. It is not the full size of a three-tile character block. If a future actor needs to appear larger than the default, its actor or prefab settings should declare that display size explicitly.

## Sprites In 3D Space

Characters are 2D sprites rendered in authored 3D rooms. Treat sprite display size, animation source size, and gameplay collision as separate concerns:

- Source art defines the pixel cell size, with `128 x 128` as the default tile-sized cell.
- Display size defines how large the sprite appears in world space.
- Collision defines how much space the actor blocks for movement and interaction.

Default humanoid characters display as one tile wide. Their collision footprint should stay smaller than the visual square so movement around corners, props, and interactables does not feel grid-locked or snaggy. A circular or capsule footprint with roughly `0.3-0.4` unit radius is the default target, subject to later prefab tests and play feel.

Directional sprite facing should be driven by gameplay intent: movement vector, interaction target, cutscene override, or authored pose. Do not rely on accidental always-face-camera billboard behavior when directional facing matters.

## Room And Tile Examples

Use whole-tile dimensions for blockouts and builder defaults whenever practical.

| Room Element | Example Size | Notes |
|--------------|--------------|-------|
| Small room floor | `8 x 8` units | 8 tiles wide by 8 tiles deep |
| Medium room floor | `12 x 10` units | Supports camera rotation and NPC spacing |
| Corridor width | `2-3` units | Use `3` units when two actors may pass or turn cleanly |
| Standard wall | `1` tile thick or thinner, `3` units tall | Thickness may be visual-only if collision uses separate shapes |
| Door opening | `1-2` units wide | Use wider openings when free camera rotation risks visual ambiguity |

Existing scenes may currently use different dimensions. Future scene and builder passes should migrate toward this scale contract as those areas are touched.

## Camera Readability

The 2.5D target is a freely rotatable horizontal camera around authored 3D spaces. Room scale must therefore read from arbitrary horizontal angles, not only cardinal viewpoints.

Authoring implications:

- Keep floors, walls, and important props aligned to the 1-unit tile grid by default.
- Leave enough walkable clearance around interactables for the smaller character collision footprint.
- Avoid relying on a single front-facing wall or a single camera angle for navigation clarity.
- Use wall fading, cutouts, or room visibility systems for occlusion instead of oversizing rooms to avoid every obstruction.
- Optional camera snap points may be added later for accessibility or authored-room presentation, but they are not the primary camera model.

Camera-relative movement should map input through the active camera basis so movement remains intuitive throughout free horizontal rotation.

## Builder And Prefab Expectations

Future 2.5D builders and prefabs should expose scale in tile units first and convert to Godot units directly:

- A `width_tiles` value of `5` means `5.0` Godot units.
- A `height_tiles` value of `3` means `3.0` Godot units.
- A `128 x 128` sprite cell displays as `1.0 x 1.0` world units unless actor settings override it.
- Collision defaults should be derived from actor footprint settings, not inferred from the full sprite rectangle.

Do not introduce a second hidden scale factor for tile art. If an asset needs a different source resolution, document its pixel density and intended world display size on the asset, prefab, or actor resource.

## Manual Review Checklist

Use this checklist when changing 2.5D scenes, builders, camera defaults, or character prefabs:

- Unit examples still match `1 tile = 1 Godot unit = 128px`.
- Character visual footprint and collision footprint are separate.
- Default walls remain understandable as `3` units tall unless the room intentionally overrides them.
- Free horizontal camera rotation remains the readability target.
- Any actor larger or smaller than one tile declares its display scale explicitly.
