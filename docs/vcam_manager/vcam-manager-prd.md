# vCam Manager PRD

## Overview

- **Feature name**: Virtual Camera (vCam) Manager
- **Project**: Cabaret Template (Godot 4.6)
- **Target release**: TBD
- **Status**: Phases 0A-0F + 1A-1F + 2A-2B + 3A-3B + 4A-4B + 5 + 6A + 6B + 6A2 + 6A.3 + 6A3a + 6A3b + 6A3c + Phase 8 (2C1/2C2) complete (state/persistence + base authoring resources + dynamics + response tuning + mode resource/evaluator baselines + component/interface/manager core + `S_VCamSystem` baseline + runtime scene wiring + response-driven second-order smoothing integration + rotation continuity policy/tests + camera-state landing-impact scaffolding + QB-driven speed-FOV and landing-impact composition/rule wiring + orbit look-ahead/auto-level feel pass); Phase 2C3+ next

## Problem Statement

The project already has:

- `M_CameraManager` for main-camera discovery, scene-transition blending, and shake layering
- `S_CameraStateSystem` for QB-driven FOV and trauma
- `S_InputSystem` for gameplay look input capture

What it does not yet have is a gameplay-facing virtual camera orchestration layer. Without that layer, teams still have to build common camera behaviors from scratch:

- reusable orbit, fixed, and first-person camera modes
- soft-zone follow behavior
- smooth vCam-to-vCam blending
- occlusion handling when walls block the player
- editor framing tools
- a mobile drag-look path that can drive rotatable orbit and first-person cameras

## Goals

- Add a Cinemachine-style gameplay camera layer above the existing camera stack.
- Support orbit, fixed, and first-person virtual cameras as resource-driven behaviors.
- Reuse the existing gameplay input pipeline for player-controlled look.
- Ensure that same look pipeline works on mobile via drag-look, not just mouse and gamepad.
- Blend smoothly between virtual cameras, including moving-to-moving blends.
- Handle occlusion with silhouettes instead of camera push-in.
- Provide an editor-only rule-of-thirds preview.
- Expose active runtime camera state through Redux without persisting it incorrectly.
- Allow fixed cameras to optionally follow an authored `Path3D`, driven by player proximity with speed-clamped smoothing.

## Non-Goals

- Replacing `M_CameraManager`
- Replacing `S_CameraStateSystem`
- Replacing `S_InputSystem`
- Adding cinematic timeline tooling
- Adding camera path **editors** or spline authoring tooling
- Adding dolly/push-in collision response
- Supporting split-screen or 2D camera flows

## User Experience Notes

### For game developers

- Add a vCam by placing `C_VCamComponent` on a gameplay entity and assigning a mode resource.
- Use priority or explicit `M_VCamManager.set_active_vcam(...)` calls to change cameras.
- Configure silhouettes through the persisted VFX settings flow, not through a separate vCam settings system.
- Ensure `UI_VFXSettingsOverlay` exposes the silhouette toggle and localization keys so the persisted VFX field is player-controllable.
- Use the existing gameplay scene template wiring so the feature actually runs at runtime.
- Use the editor-only rule-of-thirds preview for framing without adding runtime overhead.
- Extend the existing touchscreen settings flow for mobile drag-look sensitivity and invert-Y rather than introducing a vCam-only mobile settings path.

### For players

- camera follows smoothly without jitter
- camera transitions feel intentional instead of snapping
- walls between the player and camera become readable silhouettes instead of causing lost visibility
- players can enable/disable silhouette behavior from the existing VFX settings screen
- player-controlled orbit and first-person look reuse the same input profile and sensitivity pipeline as the rest of gameplay
- on mobile, dragging on free screen space should rotate orbit and first-person cameras while still allowing simultaneous move-joystick and button input

## Technical Considerations

### Dependencies

- `M_CameraManager` (shake-safe transform API via `apply_main_camera_transform()` [new — Phase 9], named shake sources via `set_shake_source()` / `clear_shake_source()`, transition blend gating via `is_blend_active()` [new — Phase 9])
- `M_StateStore` (transient `vcam` slice, persisted `vfx` slice for silhouette toggle)
- `S_CameraStateSystem` (QB-driven FOV composition, shake trauma decay; vCam enriches its rule context with `vcam_active_mode` / `vcam_is_blending`)
- `C_CameraStateComponent` (vCam writes `base_fov`; system owns `target_fov`, `shake_trauma`, `fov_blend_speed`)
- `BaseECSComponent` / `BaseECSSystem`
- `BaseECSEntity` (entity ID and tag system for dynamic follow target resolution via `M_ECSManager.get_entity_by_id()` / `get_entities_by_tag()`)
- `U_ECSEventBus` / `U_ECSEventNames` (vCam publishes lifecycle events: active changed, blend started/completed, recovery)
- `U_ServiceLocator` (manager discovery: `camera_manager`, `state_store`, `ecs_manager`)
- `PhysicsDirectSpaceState3D` (occlusion raycasting)
- QB Rule Engine (`U_RuleScorer`, `U_RuleSelector`, `U_RuleStateTracker`, `U_RuleValidator`) — camera rules can condition on vCam context fields
- existing gameplay input pipeline (`S_InputSystem`, `U_InputActions`, gameplay `look_input`)
- existing mobile controls pipeline (`UI_MobileControls`, `S_TouchscreenSystem`, `settings.input_settings.touchscreen_settings`)

### Architecture

- `M_VCamManager` is a persistent root manager.
- `S_VCamSystem` is a gameplay ECS system.
- `vcam` is a transient Redux slice for observability only.
- persisted silhouette enablement belongs in `vfx`.
- persisted mobile drag-look tuning belongs in `settings.input_settings.touchscreen_settings`.
- fixed-mode world anchors resolve from `C_VCamComponent.fixed_anchor_path` when set, with fallback to the vCam host entity-root `Node3D`; do not read `C_VCamComponent` transform assumptions.
- `follow_target_tag` fallback is deterministic: first valid ECS-registration-order match wins, with a debug warning when multiple matches exist. Use `follow_target_entity_id` when deterministic targeting matters.
- `S_TouchscreenSystem` owns touchscreen gameplay look dispatch, and `S_InputSystem` must not overwrite it with zero touchscreen-source payloads.
- if `gameplay.touch_look_active` is kept as a top-level gameplay field, it must be registered as transient so it does not persist through save/load or shell transitions.
- vCam motion feeds into a new shake-safe `M_CameraManager.apply_main_camera_transform(...)` API rather than writing `camera.global_transform` directly.
- vCam-authored FOV writes go to `C_CameraStateComponent.base_fov`; `S_CameraStateSystem` remains the final FOV writer.
- the `state.camera.in_fov_zone` to `state.vcam.in_fov_zone` migration is complete. Keep runtime/tests on `vcam` and do not reintroduce legacy `camera`-slice reads.
- soft-zone projection and occlusion raycasts use the active gameplay camera's viewport and `World3D` inside the root `GameViewport` `SubViewport`, never the persistent manager node's viewport/world.
- same-frame camera apply must not depend on root-vs-gameplay `_physics_process` tree order. `S_VCamSystem` submits evaluated results as the explicit handoff, and `M_VCamManager` consumes only current-frame submissions.
- `use_path` helpers such as `PathFollow3D` stay scene-local in the gameplay world, not under the persistent root manager.
- silhouette rendering routes through `M_VFXManager`. vCam publishes `EVENT_SILHOUETTE_UPDATE_REQUEST` with `{entity_id, occluders, enabled}` so VFX can reuse existing player gating and transition blocking.
- occluder rollout requires both naming physics layer 6 (`vcam_occludable`) and migrating authored occluding geometry in gameplay/prefab scenes onto that layer.

### Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| gameplay vCam code fights camera shake | add a shake-safe `M_CameraManager` transform API instead of direct camera writes |
| soft-zone jitter or framing drift | use projection-based correction at tracked depth |
| blends break when either camera is moving | evaluate both outgoing and incoming cameras live every frame |
| silhouette logic ignores common repo geometry | support `GeometryInstance3D`, including `CSGShape3D` |
| persistence leaks runtime state | keep `vcam` fully transient and store only player-facing toggle in `vfx` |
| docs describe wiring that never reaches runtime | explicitly patch `root.tscn`, `tmpl_base_scene.tscn`, and `gameplay_base.tscn` |
| mobile orbit/first-person ship half-finished | extend `UI_MobileControls` and `S_TouchscreenSystem` so drag-look writes shared `gameplay.look_input` |
| touch-look conflicts with movement/buttons | claim a dedicated look touch only when the touch starts outside joystick/button hit regions |
| touchscreen input gets overwritten by zeros | gate `S_InputSystem` so touch gameplay input remains owned by `S_TouchscreenSystem` when touchscreen is active |
| keyboard-look plan updates only profiles but not runtime plumbing | patch `U_InputMapBootstrapper`, input-map tests, settings-save triggers, rebind category wiring, and localization together |
| silhouette field persists but players cannot control it | add silhouette toggle wiring + localization in `UI_VFXSettingsOverlay` |
| root manager computes projection/raycast math in the wrong world | always use the active gameplay camera viewport and gameplay `World3D` from `GameViewport` |
| same-frame apply depends on scene-tree order | define an explicit current-frame handoff from `S_VCamSystem` into `M_VCamManager` rather than relying on root `_physics_process` ordering |
| detector works in isolation but misses gameplay occluders | migrate authored scene/prefab camera blockers to layer 6 `vcam_occludable` |
| active follow target freed or disappears during gameplay | define system-level recovery policy: hold last valid pose, cut to fallback vCam, or reseat to entity root |
| fixed anchor freed after scene churn | guard anchor resolution every tick; fall back to entity root or hold last valid pose |
| `follow_target_tag` becomes ambiguous after scene changes | resolve first valid registration-order match, warn in debug, recommend `follow_target_entity_id` where determinism matters |
| `use_path` keeps moving after target loss | treat invalid follow target as normal recovery; do not fabricate path progress from stale data |
| outgoing or incoming vCam becomes invalid mid-blend | clear blend immediately and cut to whichever side is still valid |
| silhouette flicker on marginal occluders | add debounce / hysteresis / grace-frame logic so silhouette set stays stable frame-to-frame |

### Compatibility

- `M_CameraManager` remains the low-level runtime owner of transition cameras and shake.
- `S_CameraStateSystem` remains the low-level owner of final FOV application.
- `S_InputSystem` and `S_TouchscreenSystem` together remain the source of gameplay `look_input`.
- `tmpl_camera.tscn` is extended, not replaced.
- naming and paths stay within existing style-guide categories by using:
  - `scripts/resources/display/vcam/`
  - `scripts/utils/display/`
  - `assets/shaders/sh_*_shader.gdshader`

## Success Metrics

- all three camera modes evaluate correctly in unit tests
- runtime wiring exists in both root and gameplay scene trees
- vCam blends are visually smooth even when both cameras are moving
- gameplay camera motion and shake coexist without canceling each other
- silhouettes work on mesh and CSG occluders
- `vcam` Redux state reflects runtime camera status and is marked transient
- silhouette enablement persists through the existing VFX/global-settings flow
- mobile drag-look feeds the same `gameplay.look_input` path and remains configurable through touchscreen settings
- editor rule-of-thirds preview is visible in the editor and absent at runtime
- mode switches preserve facing direction when appropriate, or intentionally reseed to authored angles by explicit policy — no disorienting camera heading jumps
- occlusion silhouettes remain stable and do not flicker on marginal blockers
- no avoidable per-frame allocations in steady-state camera evaluation
- occlusion pass stays within frame-time budget (no regression in frame pacing from blend + soft-zone + occlusion combined)
- a new switch mid-blend produces a visually coherent transition, not a pop or wedged state

## Open Questions

| Question | Status |
|----------|--------|
| Should silhouette color/opacity be globally configurable in VFX settings now or later? | Deferred to post-v1. Ship with a single authored color/opacity in the shader; add VFX-settings configurability only if player feedback requests it. |
| Should orbit mode eventually support authored zoom behavior? | Deferred to post-v1. Orbit distance is authored and static for v1; zoom tuning can be added later without breaking the resource contract. |

## Resolved Decisions

| Topic | Decision |
|------|----------|
| runtime ownership | `M_VCamManager` in root, `S_VCamSystem` in gameplay |
| input integration | consume gameplay `look_input` from the existing mouse/gamepad/touch pipeline |
| persistence | `vcam` transient, silhouette toggle in `vfx` |
| shake compatibility | use `M_CameraManager.apply_main_camera_transform(...)` |
| FOV composition | set `C_CameraStateComponent.base_fov`; do not write `camera.fov` directly |
| blend correctness | evaluate both cameras live during blends |
| style alignment | use display resource/util directories and `sh_*_shader.gdshader` |
| fixed-mode anchor source | use `fixed_anchor_path` first, then host entity-root `Node3D` fallback; never component transform |
| silhouette ownership | detect in vCam, render in `M_VFXManager` via `{entity_id, occluders, enabled}` requests |
| gameplay viewport contract | projection and raycasts use the active gameplay camera viewport/world inside `GameViewport` |
