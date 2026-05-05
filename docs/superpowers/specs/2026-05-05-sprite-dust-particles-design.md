# Task H: GPU Particles → Billboarded Sprite Dust — Design Spec

Date: 2026-05-05
Branch: mobile-fixes

## Problem

`U_ParticleSpawner` creates `GPUParticles3D` with `ParticleProcessMaterial` for 3 gameplay events (spawn, jump, landing). GPU particles have:
- A 2-frame deferred activation bug workaround (3 callback methods on every caller)
- Ignore scene tree pause (requiring manual `speed_scale=0` pause handling in `M_SceneManager`)
- GPU overhead on mobile/gl_compatibility renderer
- Complex `ParticleProcessMaterial` configuration per effect

The goal zone also uses 2 authored `CPUParticles3D` sparkle nodes that have similar issues.

## Solution

Replace `GPUParticles3D` with individually animated `Sprite3D` puffs using the existing billboard pattern from `triggered_interactable_controller.gd`. Each dust puff is a `Sprite3D` that:
- Uses `BaseMaterial3D.BILLBOARD_PARTICLES` mode (billboard with scale preservation)
- Has a soft circular puff texture (`tex_dust_puff.png`, 32×32, generated via PixelLab)
- Animates via `Tween`: scale from 0 → max scale, then fade alpha to 0
- Auto-cleans up via `Tween` callback → `queue_free()`

This eliminates the GPU init bug workaround, simplifies pause handling (Sprite3D respects scene tree pause by default), and reduces GPU overhead.

## Architecture

### U_DustSpawner (replaces U_ParticleSpawner)

New utility class `U_DustSpawner` replaces `U_ParticleSpawner`. API mirrors the existing `ParticleConfig` pattern but with dust-specific semantics:

```gdscript
class_name U_DustSpawner

class DustConfig:
    var count: int = 10           # number of puffs (was emission_count)
    var lifetime: float = 0.5    # puff lifetime in seconds
    var scale: float = 0.3       # max puff scale in world units
    var spread: float = 0.4      # random position offset radius
    var drift: Vector3 = Vector3.UP  # drift direction/speed
    var spawn_offset: Vector3 = Vector3.ZERO

func spawn_dust(position: Vector3, container: Node3D, config: DustConfig) -> void
static func get_or_create_effects_container(tree: SceneTree) -> Node3D
static func is_dust_enabled(tree: SceneTree) -> bool
```

**Key behavior of `spawn_dust()`:**
- Creates `config.count` individual `Sprite3D` nodes
- Each puff positioned at `position + config.spawn_offset` + random offset within `config.spread` radius
- Each puff animated via `Tween`: scale 0 → `config.scale` over 30% of lifetime, then hold, then fade alpha 1 → 0 over last 50% of lifetime
- Each puff drifts by `config.drift * lifetime`
- Each puff auto-cleans up via `tween.finished → queue_free()`
- Returns immediately (no deferred activation needed)

### Dust Puff Sprite Setup

Each `Sprite3D` puff:
- `texture = preload("res://assets/core/textures/tex_dust_puff.png")`
- `billboard = BaseMaterial3D.BILLBOARD_PARTICLES` (value 3)
- Material: `transparency = ALPHA`, `shading_mode = UNSHADED`, `no_depth_test = true`, `cull_mode = DISABLED`
- `expand_mode = IGNORE_SIZE`, `stretch_mode = STRETCH_SCALE`
- `texture_filter = NEAREST` (matches BackgroundImage convention)

This mirrors the existing Sprite3D billboard pattern in `triggered_interactable_controller.gd`.

### Settings Resources

`RS_JumpParticlesSettings` and `RS_LandingParticlesSettings` rename particle-specific fields to dust-specific fields. The export properties change:

| Old | New | Type | Default (Jump) | Default (Landing) |
|-----|-----|------|---------|--------|
| emission_count | count | int | 10 | 15 |
| particle_lifetime | lifetime | float | 0.5 | 0.6 |
| particle_scale | scale | float | 0.1 | 0.12 |
| spread_angle | spread | float | 0.4 | 0.5 |
| initial_velocity | drift_strength | float | 3.0 | 2.5 |
| spawn_offset | spawn_offset | Vector3 | (0,-0.5,0) | (0,-0.5,0) |
| particle_material | (removed) | — | — | — |

`enabled` stays. A new `drift_direction: Vector3 = Vector3.UP` is added.

The `.tres` resource files are recreated with new field names.

### ECS Systems

Three systems updated to use `U_DustSpawner` instead of `U_ParticleSpawner`:

1. `S_SpawnParticlesSystem` → `S_SpawnDustSystem`
2. `S_JumpParticlesSystem` → `S_JumpDustSystem`
3. `S_LandingParticlesSystem` → `S_LandingDustSystem`

Each:
- Removes `_u_particle_spawner_activate_frame1/2` callback methods
- Uses `U_DustSpawner.DustConfig` instead of `U_ParticleSpawner.ParticleConfig`
- Returns `void` from `process_tick()` (no GPUParticles3D to return)

### Goal Zone Sparkles

Replace the 2 authored `CPUParticles3D` "Sparkles" nodes with a `Sprite3D`-based sparkle system:

- In `prefab_goal_zone.tscn`, remove the `Sparkles` CPUParticles3D node
- In the goal zone script, add a periodic sparkle effect: 2-3 `Sprite3D` puffs that pulse in scale and alpha on a timer (e.g., every 1.5 seconds, spawn a sparkle puff at a random position within the goal zone radius)
- Same billboard material pattern as dust puffs

### Pause/Visibility Compatibility

**`M_SceneManager._set_particles_paused()`:** Remove the GPUParticles3D/CPUParticles3D collection logic. Sprite3D puffs respect `get_tree().paused` by default — no manual pause handling needed. Remove the method entirely, or leave a no-op stub if called from elsewhere.

**`BaseVolumeController._apply_visual_visibility()`:** Remove the GPUParticles3D/CPUParticles3D emitting toggle. If volume controllers need to toggle dust visibility, add `Sprite3D` detection logic (find Sprite3D children named "DustPuff*" and toggle visibility).

### Test Updates

Replace `test_particle_spawner.gd` with `test_dust_spawner.gd`:
- `DustConfig` default values test
- `DustConfig` custom values test
- `spawn_dust()` creates N Sprite3D nodes as children of container
- Each Sprite3D has billboard material with correct properties
- Each Sprite3D has Tween animation attached
- Each Sprite3D positioned within spread radius of spawn point
- Null container / null config early returns
- `is_dust_enabled()` reads from VFX Redux state

## Files Changed

| File | Change |
|------|--------|
| `scripts/core/utils/u_particle_spawner.gd` | **Renamed** → `u_dust_spawner.gd`, full rewrite |
| `scripts/core/ecs/systems/s_spawn_particles_system.gd` | **Renamed** → `s_spawn_dust_system.gd`, uses U_DustSpawner |
| `scripts/core/ecs/systems/s_jump_particles_system.gd` | **Renamed** → `s_jump_dust_system.gd`, uses U_DustSpawner |
| `scripts/core/ecs/systems/s_landing_particles_system.gd` | **Renamed** → `s_landing_dust_system.gd`, uses U_DustSpawner |
| `scripts/core/resources/ecs/rs_jump_particles_settings.gd` | **Rewrite** with new field names |
| `scripts/core/resources/ecs/rs_landing_particles_settings.gd` | **Rewrite** with new field names |
| `resources/core/base_settings/gameplay/cfg_jump_particles_default.tres` | **Recreate** with new fields |
| `resources/core/base_settings/gameplay/cfg_landing_particles_default.tres` | **Recreate** with new fields |
| `scripts/core/managers/m_scene_manager.gd` | Remove particle pause logic |
| `scripts/core/gameplay/base_volume_controller.gd` | Remove GPU/CPU particle emitting toggle |
| `scenes/core/prefabs/prefab_goal_zone.tscn` | Remove CPUParticles3D Sparkles |
| `scripts/core/gameplay/goal_zone.gd` (or similar) | Add Sprite3D sparkle timer |
| `tests/unit/utils/test_particle_spawner.gd` | **Renamed** → `test_dust_spawner.gd`, full rewrite |
| `tests/scenes/test_exterior.tscn` | Remove CPUParticles3D Sparkles |
| `assets/core/textures/tex_dust_puff.png` | **New** — 32×32 soft circular puff |

## Out of Scope

- No animation spritesheet — each puff is a single static texture, animated via Tween
- No dust pooling/object reuse — create and queue_free is sufficient for low counts (10-15 puffs per event)
- No shader-based effects — purely Sprite3D + Tween
- No changes to `BaseEventVFXSystem` contract (still uses `requests` array pattern)

## Backward Compatibility

`U_ParticleSpawner` is removed entirely. All callers are updated to use `U_DustSpawner`. The `.tres` resource files are recreated with new field names, so old resource files will not load correctly — they must be regenerated.

The `U_ParticleSpawner.activate_particles_frame2/activate_particles_final` static methods and the `_u_particle_spawner_activate_frame1/2` callback protocol are removed. Systems no longer need deferred activation methods.