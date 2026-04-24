# Add vCam Effect / State

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new vCam effect (camera modification applied after mode evaluation)
- A new vCam state field (persisted or transient in the `vcam` Redux slice)
- A new vCam mode resource type

This recipe does **not** cover:

- ECS component/system authoring (see `ecs.md`)
- State slice creation (see `state.md`)
- Manager registration (see `managers.md`)

## Governing ADR(s)

- [ADR 0001: Channel Taxonomy](../adr/0001-channel-taxonomy.md) (ECS events for camera, Redux for manager state)

## Canonical Example

- Effect helper: `scripts/ecs/systems/helpers/u_vcam_landing_impact.gd`
- Mode resource: `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd`
- State slice: `scripts/state/actions/u_vcam_actions.gd`
- vCam system: `scripts/ecs/systems/s_vcam_system.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `S_VCamSystem` | ECS system that evaluates modes and applies the effect pipeline each tick. |
| `U_VCamEffectPipeline` | Ordered chain of effect modifiers applied after mode evaluation. |
| `RS_VCamModeOrbit` | Camera behavior resource with `get_resolved_values() -> Dictionary`. |
| `RS_VCamBlendHint` | Transition parameters (duration, ease, cut threshold). |
| `RS_VCamSoftZone` | Dead/soft zone dimensions and damping. |
| `RS_VCamResponse` | Second-order dynamics (frequency, damping, look-ahead, auto-level). |
| `M_CameraManager` | Applies final transforms; vCam never writes `camera.global_transform` directly. |
| `vcam` slice | Transient Redux slice (`is_transient = true`). Never persisted to save. |

Resources live under `scripts/resources/display/vcam/`. Helpers live under `scripts/ecs/systems/helpers/`.

## Recipe

### Adding a new vCam effect

1. Create helper at `scripts/ecs/systems/helpers/u_vcam_<effect_name>.gd`: extend `RefCounted`, implement effect logic, keep per-vcam-id state in internal Dictionary keyed by `vcam_id: StringName`, implement `prune(active_ids)`, `clear_for_vcam(vcam_id)`, `clear_all()`.
2. Instantiate in `S_VCamSystem`, call in `process_tick()` flow (before or after `apply_vcam_effect_pipeline`).
3. Add pruning in `_prune_smoothing_state()` and cleanup in `_clear_all_smoothing_state()`.
4. If configurable: create `RS_VCam*` resource in `scripts/resources/display/vcam/` with `@export` fields and `get_resolved_values() -> Dictionary`.
5. If Redux state needed: add action to `U_VCamActions`, handle in `U_VCamReducer.reduce()`, add selector to `U_VCamSelectors`.

### Adding a new vCam state field

1. Add `@export` field to `RS_VCamInitialState` and `to_dictionary()`.
2. Add to `U_VCamReducer.DEFAULT_VCAM_STATE`.
3. Add action constant + creator to `U_VCamActions` (register in `_static_init`).
4. Handle in `U_VCamReducer.reduce()`.
5. Add selector to `U_VCamSelectors`.
6. `vcam` slice is transient — no save/load impact.

## Anti-patterns

- **Writing `camera.global_transform` directly**: Must go through `M_CameraManager.apply_main_camera_transform()` for shake layering.
- **Applying player look input in fixed mode**: Fixed cameras are authored viewpoints; `runtime_yaw`/`runtime_pitch` must be ignored.
- **Consuming `look_multiplier` in evaluator helpers**: Double-scales input; must only be applied in `S_VCamSystem`.
- **Using `state.camera.in_fov_zone`**: Migration complete; use `state.vcam.in_fov_zone`.
- **Applying stale submitted camera results**: `M_VCamManager` only applies results whose `frame` matches current physics frame.
- **Silhouette flicker from per-frame clear/reapply**: Use `U_VCamSilhouetteHelper.update_silhouettes()` with debounce/grace.

## Out Of Scope

- ECS component/system: see `ecs.md`
- State slice creation: see `state.md`
- Display presets: see `display_post_process.md`

## References

- [vCam Manager Overview](../../systems/vcam_manager/vcam-manager-overview.md)
- [vCam Pitfalls](../../systems/vcam_manager/vcam-pitfalls.md)