# vCam Manager PRD

## Overview

- **Feature name**: Virtual Camera (vCam) Manager
- **Project**: Cabaret Template (Godot 4.6)
- **Target release**: TBD
- **Status**: Documentation remediated, implementation not started

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

## Non-Goals

- Replacing `M_CameraManager`
- Replacing `S_CameraStateSystem`
- Replacing `S_InputSystem`
- Adding cinematic timeline tooling
- Adding camera path editors or spline tooling
- Adding dolly/push-in collision response
- Supporting split-screen or 2D camera flows

## User Experience Notes

### For game developers

- Add a vCam by placing `C_VCamComponent` on a gameplay entity and assigning a mode resource.
- Use priority or explicit `M_VCamManager.set_active_vcam(...)` calls to change cameras.
- Configure silhouettes through the persisted VFX settings flow, not through a separate vCam settings system.
- Use the existing gameplay scene template wiring so the feature actually runs at runtime.
- Use the editor-only rule-of-thirds preview for framing without adding runtime overhead.
- Extend the existing touchscreen settings flow for mobile drag-look sensitivity and invert-Y rather than introducing a vCam-only mobile settings path.

### For players

- camera follows smoothly without jitter
- camera transitions feel intentional instead of snapping
- walls between the player and camera become readable silhouettes instead of causing lost visibility
- player-controlled orbit and first-person look reuse the same input profile and sensitivity pipeline as the rest of gameplay
- on mobile, dragging on free screen space should rotate orbit and first-person cameras while still allowing simultaneous move-joystick and button input

## Technical Considerations

### Dependencies

- `M_CameraManager`
- `M_StateStore`
- `BaseECSComponent`
- `BaseECSSystem`
- `U_ServiceLocator`
- `PhysicsDirectSpaceState3D`
- existing gameplay input pipeline (`S_InputSystem`, `U_InputActions`, gameplay `look_input`)
- existing mobile controls pipeline (`UI_MobileControls`, `S_TouchscreenSystem`, `settings.input_settings.touchscreen_settings`)

### Architecture

- `M_VCamManager` is a persistent root manager.
- `S_VCamSystem` is a gameplay ECS system.
- `vcam` is a transient Redux slice for observability only.
- persisted silhouette enablement belongs in `vfx`.
- persisted mobile drag-look tuning belongs in `settings.input_settings.touchscreen_settings`.
- `S_TouchscreenSystem` owns touchscreen gameplay look dispatch, and `S_InputSystem` must not overwrite it with zero touchscreen-source payloads.
- vCam motion feeds into a new shake-safe `M_CameraManager.apply_main_camera_transform(...)` API rather than writing `camera.global_transform` directly.
- vCam-authored FOV writes go to `C_CameraStateComponent.base_fov`; `S_CameraStateSystem` remains the final FOV writer.

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

## Open Questions

| Question | Status |
|----------|--------|
| Should silhouette color/opacity be globally configurable in VFX settings now or later? | Open |
| Should orbit mode eventually support authored zoom behavior? | Open |

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
