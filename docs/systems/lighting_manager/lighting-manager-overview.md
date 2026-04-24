# Character Lighting Manager Overview

Character lighting is the zone-driven character shading pipeline. It replaces character-driving physical `Light3D` mood/objective/signpost lights with authored lighting zones and an unlit shader so player and NPC readability stays deterministic across scenes.

## Status

- Lighting Manager story is complete through Phase 8.
- Task history lives in `docs/systems/lighting_manager/lighting-manager-tasks.md`.
- Runtime math details live in `docs/systems/lighting_manager/lighting-math-contract.md`.

## Locked Decisions

- Character shading is full unlit. Character appearance does not respond to physical `Light3D`.
- Zone authoring uses dedicated `Inter_CharacterLightZone` controllers.
- Runtime source of truth is scene/resources, not a Redux slice.
- Target entities are gameplay actors tagged `character`: player, NPCs, enemies, and companions.
- Non-character proxies/dummies should not use the `character` tag.
- Outside zones use the scene default profile.
- Zone overlap uses weighted blending with priority and deterministic tie-break rules.
- Mood/objective/signpost physical lights that drove character readability are replaced with equivalent zones.

## Key Files

- `scripts/interfaces/i_character_lighting_manager.gd`
- `scripts/managers/m_character_lighting_manager.gd`
- `scripts/gameplay/inter_character_light_zone.gd`
- `scripts/demo/resources/lighting/rs_character_lighting_profile.gd`
- `scripts/demo/resources/lighting/rs_character_light_zone_config.gd`
- `scripts/utils/lighting/u_character_lighting_blend_math.gd`
- `scripts/utils/lighting/u_character_lighting_material_applier.gd`
- `assets/shaders/sh_character_zone_lighting.gdshader`

## Resource Contracts

- Lighting resource scripts live under `scripts/demo/resources/lighting/` with `rs_` prefixes.
- `RS_CharacterLightingProfile` is the base data contract. Use `get_resolved_values()` for clamped runtime values (`tint`, `intensity`, `blend_smoothing`) instead of reading raw exports directly in blend code.
- `RS_CharacterLightZoneConfig` is the zone-side contract. Use `get_resolved_values()` for clamped dimensions/weights and deep-copied `profile` snapshots.
- Authored resource instances live under:
  - `resources/lighting/profiles/cfg_character_lighting_profile_*.tres`
  - `resources/lighting/zones/cfg_character_light_zone_*.tres`

## Blend Math

Blend calculations live in `U_CharacterLightingBlendMath`.

- Deterministic ordering: priority descending, weight descending, then `zone_id` ascending.
- Weighted blending normalizes source weights.
- Empty/invalid zone inputs fall back to a sanitized default profile.
- Boundary hysteresis is per character/per zone key with a deadband (`enter >= 0.02`, `exit < 0.01`) to reduce edge flicker.
- Temporal smoothing uses blended `blend_smoothing` per character (`alpha = 1.0 - blend_smoothing`) for tint/intensity transitions.
- Clear smoothing/hysteresis runtime state whenever lighting is blocked/disabled or scene bindings are refreshed so stale history does not bleed across transitions.

See `lighting-math-contract.md` for exact equations and clamp ranges.

## Zone Controller Contract

`Inter_CharacterLightZone` extends `BaseVolumeController` and remains config-driven.

- Build runtime `RS_SceneTriggerSettings` from `RS_CharacterLightZoneConfig` in `_apply_config_to_volume_settings()`.
- Use `resource_local_to_scene = true` for generated trigger settings.
- Keep passive overlap behavior (`ignore_initial_overlap = false`) so spawn-inside zones still apply.
- Auto-register/unregister with `character_lighting_manager` in `_ready()`/`_exit_tree()` so zones authored outside `Lighting` hierarchies are still consumed by the manager.
- `get_influence_weight(world_position)` returns shape-aware weight with falloff and transition gating.
- `get_zone_metadata()` returns deterministic cache inputs: `zone_id`, `stable_key`, `priority`, `blend_weight`, and deep-copied `profile` snapshot.

## Material Application

`U_CharacterLightingMaterialApplier` owns shader/material swaps.

- `collect_mesh_targets(entity)` recursively gathers `MeshInstance3D` nodes with valid mesh resources.
- `apply_character_lighting(...)` swaps each target to `ShaderMaterial` using `assets/shaders/sh_character_zone_lighting.gdshader`, carries forward `albedo_texture`, and sets `base_tint`, `effective_tint`, `effective_intensity`.
- Missing mesh/material/albedo texture is a deliberate no-op: skip target, do not cache.
- Call `restore_character_materials(entity)` on entity cleanup.
- Call `restore_all_materials()` on broader scene teardown.

## Manager Runtime

`M_CharacterLightingManager`:

- discovers dependencies via injection-first plus ServiceLocator fallback (`state_store`, `scene_manager`, `ecs_manager`);
- discovers active scene lighting data from `ActiveSceneContainer/<GameplayScene>/Lighting`;
- resolves scene defaults from `Lighting/CharacterLightingSettings.default_profile` when available, otherwise uses a sanitized white/default fallback profile;
- listens for `scene/swapped` via `state_store.action_dispatched` and marks lighting caches dirty for the next physics tick;
- discovers character targets from ECS tag query (`get_entities_by_tag("character")`);
- restores materials for removed/non-3D entities;
- applies transition gating via Redux scene/navigation slices and `scene_manager.is_transitioning()`;
- restores all character lighting overrides on blocked frames.

## Scene Authoring

- Every migrated gameplay scene should provide `Lighting/CharacterLightingSettings` with a `default_profile` (`RS_CharacterLightingProfile`) resource.
- Author light zones as explicit `Inter_CharacterLightZone` nodes with `config = ExtResource("res://resources/lighting/zones/cfg_*.tres")`.
- Replace character-driving `OmniLight3D` nodes only after equivalent zone config is present.
- Preserve non-light visuals (`Visual`, `Sparkles`, meshes) for readability.

## Pitfalls

- **Cache invalidation is required on `scene/swapped` for lighting managers**: Character lighting caches built from `ActiveSceneContainer/<GameplayScene>/Lighting` can go stale after a scene transition unless the manager listens to `state_store.action_dispatched` and marks cache state dirty when action type is `scene/swapped`.
- **Zones authored outside `Lighting` need explicit registration**: Manager discovery only crawls `Lighting` by default, so objective/signpost/prefab zones under `Entities/...` must register with `character_lighting_manager` on `_ready()` and unregister on `_exit_tree()`.
- **Boundary smoothing needs explicit runtime-state resets**: If per-character lighting smoothing/hysteresis history is preserved across scene refreshes or transition-blocked frames, newly loaded scenes can briefly inherit stale tint/intensity targets from the previous scene.

## Verification

- Unit: `tests/unit/lighting/test_character_lighting_blend_math.gd`
- Unit: `tests/unit/managers/test_character_lighting_manager.gd`
- Unit: `tests/unit/interactables/test_inter_character_light_zone.gd`
- Integration: `tests/integration/lighting/test_character_zone_lighting_flow.gd`
