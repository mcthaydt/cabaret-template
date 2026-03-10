# vCam Manager - Continuation Prompt

## Current Focus

- **Feature / story**: Virtual Camera (vCam) Manager
- **Branch**: `vcam`
- **Status summary**: Phase 0A and Phase 0A2 are complete as of March 10, 2026 (touchscreen drag-look persistence + keyboard-look action/settings/UI plumbing). Next implementation target is Phase 0B (`vfx.occlusion_silhouette_enabled` persistence and VFX settings integration).

## Phase 0 Progress (March 10, 2026)

- Completed Phase 0A:
  - Persisted touchscreen look settings (`look_drag_sensitivity`, `invert_look_y`) through reducer/serialization paths.
  - Patched `UI_TouchscreenSettingsOverlay` scene/controller for new controls, localization, and apply/reset flow.
  - Updated touchscreen settings resource defaults and unit/UI localization tests.
- Completed Phase 0A2:
  - Added dedicated `look_left/right/up/down` actions to InputMap bootstrap and keyboard profiles.
  - Added keyboard-look action/reducer/serialization plumbing in input settings.
  - Extended `KeyboardMouseSource` + `S_InputSystem` to emit keyboard-look through shared `gameplay.look_input`.
  - Added `UI_KeyboardMouseSettingsOverlay` + scene-registry/UI-registry wiring + settings-menu entrypoint.
  - Updated rebind action category/localization surface and added overlay/unit/integration tests.
- Validation run (green):
  - `tests/unit/input_manager/test_u_input_reducer.gd`
  - `tests/unit/input/test_input_map.gd`
  - `tests/unit/resources/test_rs_touchscreen_settings.gd`
  - `tests/unit/ecs/systems/test_input_system.gd`
  - `tests/unit/ui/test_touchscreen_settings_overlay.gd`
  - `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd`
  - `tests/unit/ui/test_input_rebinding_overlay.gd`
  - `tests/unit/ui/test_keyboard_mouse_settings_overlay.gd`
  - `tests/unit/integration/test_rebinding_flow.gd`
  - `tests/unit/style/test_style_enforcement.gd`

## What Changed In The Docs

- Runtime wiring is now explicit: `M_VCamManager` belongs in `scenes/root.tscn`, and `S_VCamSystem` belongs in gameplay system trees.
- The `vcam` Redux slice is now defined as transient runtime observability only.
- The silhouette enable/disable toggle moved to the persisted `vfx` slice.
- VFX settings UI integration is now explicit: wire the silhouette toggle into `UI_VFXSettingsOverlay` (`scripts/ui/settings/ui_vfx_settings_overlay.gd` + `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn`) and localize it in all `cfg_locale_*_ui.tres` files.
- The blend design now evaluates both outgoing and incoming cameras live during blends.
- The camera integration now requires a shake-safe `M_CameraManager.apply_main_camera_transform(...)` API instead of direct `camera.global_transform` writes.
- Soft-zone math is now defined as projection-based rather than basis-vector offset math.
- Soft-zone projection and occlusion raycasts are now explicitly tied to the active gameplay camera viewport and `World3D` inside `GameViewport`, not the root manager node's viewport/world.
- Mobile drag-look is now a hard requirement for rotatable orbit and first-person support.
- Mobile drag-look settings belong in `settings.input_settings.touchscreen_settings`, and the touch look path must extend `UI_MobileControls` plus `S_TouchscreenSystem`.
- `S_InputSystem` must be gated so it does not overwrite touchscreen gameplay input with zero `TouchscreenSource` payloads.
- Fixed-mode anchor ownership is now explicit: fixed cameras must resolve `C_VCamComponent.fixed_anchor_path` first, then fall back to a vCam host entity-root `Node3D`; never read component transform.
- Path-follow helpers for `use_path` stay scene-local in the gameplay world; do not parent them under the persistent root manager.
- Occlusion rollout is now explicit: naming layer 6 `vcam_occludable` is not enough; authored occluding geometry in gameplay/prefab scenes must be migrated to that layer.
- Stale test paths were corrected (`test_u_input_reducer.gd`, `test_input_system.gd`, `tests/integration/camera_system/test_camera_manager.gd`).
- ECS Event Bus integration added: `M_VCamManager` publishes lifecycle events (`EVENT_VCAM_ACTIVE_CHANGED`, `EVENT_VCAM_BLEND_STARTED`, `EVENT_VCAM_BLEND_COMPLETED`, `EVENT_VCAM_RECOVERY`) through `U_ECSEventBus` so `S_GameEventSystem`, `S_CameraStateSystem`, and QB rules can subscribe to vCam state changes.
- vCam event constants must be added to `scripts/events/ecs/u_ecs_event_names.gd` following existing `EVENT_*` pattern.
- Entity-based target resolution added: `C_VCamComponent` supports `follow_target_entity_id` and `follow_target_tag` exports as fallbacks when NodePath is empty. `S_VCamSystem` resolves targets via `M_ECSManager.get_entity_by_id()` / `get_entities_by_tag()`, leveraging the existing `BaseECSEntity` ID/tag system. Multiple tag matches resolve to the first valid ECS-registration-order match and emit a debug warning.
- QB rule context enrichment: `S_CameraStateSystem._build_camera_context()` is extended with `vcam_active_mode`, `vcam_is_blending`, `vcam_active_vcam_id` so camera rules can condition on vCam state using standard `RS_ConditionContextField`.
- Per-phase doc cadence is now explicit and mandatory: update continuation prompt + tasks after each phase, and update AGENTS/DEV_PITFALLS when new stable contracts or pitfalls appear.
- Camera slice migration is now explicitly marked pending: as of March 10, 2026, `S_CameraStateSystem` and QB camera tests still read `state.camera.in_fov_zone`. Phase 0F updates those reads and only then retires the `camera` slice.
- Touch look gating uses a planned `gameplay.touch_look_active` Redux flag. If implemented as a top-level gameplay field, it must be registered as transient so it does not persist through save/load or shell handoff.
- Keyboard-look scope is now complete: patch `U_InputMapBootstrapper`, `tests/unit/input/test_input_map.gd`, `U_GlobalSettingsSerialization`, `U_RebindActionListBuilder`, locale action keys, and a new `UI_KeyboardMouseSettingsOverlay` instead of treating the settings surface as optional.
- Same-frame camera apply is now explicit: `S_VCamSystem` submits the authoritative current-frame result, and `M_VCamManager` consumes that handoff instead of relying on root `_physics_process` order against gameplay ECS.
- Silhouette rendering routes through `M_VFXManager`: vCam publishes `EVENT_SILHOUETTE_UPDATE_REQUEST` with `{entity_id, occluders, enabled}`, VFX manager subscribes and delegates to `U_VCamSilhouetteHelper`. This is what lets existing player gating and transition blocking apply.
- Naming paths now follow the repo style guide:
  - `scripts/resources/display/vcam/`
  - `scripts/utils/display/`
  - `assets/shaders/sh_vcam_silhouette_shader.gdshader`

## Required Reading

- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/vcam_manager/vcam-manager-plan.md`
- `docs/vcam_manager/vcam-manager-overview.md`
- `docs/vcam_manager/vcam-manager-prd.md`
- `docs/vcam_manager/vcam-manager-tasks.md`
- `scripts/managers/m_camera_manager.gd`
- `scripts/interfaces/i_camera_manager.gd`
- `tests/mocks/mock_camera_manager.gd`
- `scripts/ecs/systems/s_input_system.gd`
- `scripts/ecs/systems/s_touchscreen_system.gd`
- `scripts/input/u_input_map_bootstrapper.gd`
- `scripts/ecs/systems/s_camera_state_system.gd` (QB rule context, FOV composition, shake trauma)
- `scripts/ecs/components/c_camera_state_component.gd` (base_fov, target_fov, shake_trauma API)
- `scripts/events/ecs/u_ecs_event_bus.gd` (event subscription/publish pattern)
- `scripts/events/ecs/u_ecs_event_names.gd` (event constant pattern — vCam events added here)
- `scripts/utils/qb/u_rule_scorer.gd` (QB rule scoring for camera rules)
- `scripts/state/utils/u_state_slice_manager.gd`
- `scripts/utils/u_global_settings_serialization.gd`
- `scripts/utils/display/u_cinema_grade_preview.gd`
- `scripts/ui/helpers/u_rebind_action_list_builder.gd`
- `scripts/managers/m_vfx_manager.gd`
- `scripts/ui/hud/ui_mobile_controls.gd`
- `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`
- `scripts/ui/overlays/ui_input_rebinding_overlay.gd`
- `scripts/ui/settings/ui_vfx_settings_overlay.gd`
- `scripts/resources/input/rs_touchscreen_settings.gd`
- `resources/localization/cfg_locale_en_ui.tres`
- `resources/localization/cfg_locale_es_ui.tres`
- `resources/localization/cfg_locale_ja_ui.tres`
- `resources/localization/cfg_locale_pt_ui.tres`
- `resources/localization/cfg_locale_zh_CN_ui.tres`
- `tests/unit/input_manager/test_u_input_reducer.gd`
- `tests/unit/input/test_input_map.gd`
- `tests/unit/ecs/systems/test_input_system.gd`
- `tests/unit/qb/test_camera_state_system.gd`
- `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd`
- `tests/unit/ui/test_input_rebinding_overlay.gd`
- `tests/integration/camera_system/test_camera_manager.gd`
- `scenes/root.tscn`
- `scenes/templates/tmpl_base_scene.tscn`
- `scenes/templates/tmpl_camera.tscn`
- `scenes/gameplay/gameplay_base.tscn`

## Next Steps

1. Implement Phase 0 Commit 0.1: add persisted `vfx.occlusion_silhouette_enabled`, wire it into VFX settings UI, and add localization keys across all UI locales.
2. Implement Phase 0 Commit 0.2: create `RS_VCamInitialState` and `cfg_default_vcam_initial_state.tres`.
3. Implement Phase 0 Commit 0.3: create vCam actions and reducer.
4. Implement Phase 0 Commit 0.4: add selectors, wire the new state export in `M_StateStore`, register `vcam` as transient, and patch `scenes/root.tscn`.
5. Implement Phase 0F before claiming camera-slice migration is done: patch `S_CameraStateSystem`, `tests/unit/qb/test_camera_state_system.gd`, and any remaining `set_slice("camera", ...)` usage to `state.vcam.in_fov_zone`.
6. Before considering orbit/first-person done, implement mobile drag-look in `UI_MobileControls` and `S_TouchscreenSystem`, wire `gameplay.touch_look_active` Redux flag for input gating, make that flag transient, and gate `S_InputSystem` so touch input is not clobbered (`tests/unit/ecs/systems/test_input_system.gd`).
7. When wiring `S_VCamSystem`, make its node order explicit after input/movement and preserve the same-frame handoff contract instead of relying on root `_physics_process` order.
8. During occlusion work, migrate authored occluding geometry to physics layer 6 in gameplay/prefab scenes; do not stop at `project.godot` layer naming.
9. After each completed phase, update continuation prompt + tasks immediately and commit docs separately from implementation.

## Key Decisions To Preserve

- vCam does not replace `M_CameraManager`.
- vCam does not replace `S_CameraStateSystem`.
- vCam does not bypass the gameplay input pipeline.
- Keyboard look uses dedicated `look_*` actions (not `ui_*`) so bindings stay correct across input profiles; settings live in `mouse_settings`.
- Keyboard-look work is not complete unless the InputMap bootstrapper, input-map tests, rebind category/action labels, localization keys, and settings-save triggers are patched together.
- vCam does not treat mobile as special at the camera layer; touch look must still feed the shared `gameplay.look_input` path.
- vCam does not persist runtime slice state.
- vCam does not write `camera.fov` directly.
- vCam does not write `camera.global_transform` directly.
- vCam blends are live blends between two evaluated cameras, not frozen-transform lerps.
- fixed-mode world anchoring resolves from `fixed_anchor_path` first, then host entity-root `Node3D` fallback; not from component transform assumptions.
- vCam publishes lifecycle events through `U_ECSEventBus`, not just Redux — enabling reactive integration with QB rules and other systems.
- QB camera rules can condition on vCam state via enriched context fields (`vcam_active_mode`, `vcam_is_blending`) — no vCam-specific rule types needed.
- Follow target resolution uses existing entity ID/tag system as fallback when NodePaths are empty. Multiple tag matches resolve to the first valid ECS-registration-order match and emit a debug warning.
- The informal `camera` slice is not retired yet. Phase 0F must migrate `in_fov_zone` reads to `state.vcam.in_fov_zone` before docs can claim that retirement.
- Touch input gating uses `gameplay.touch_look_active` Redux flag, not device-type checks, and that flag stays transient if implemented in the gameplay slice.
- Projection math and occlusion raycasts use the active gameplay camera viewport/world inside `GameViewport`.
- Silhouette rendering lifecycle is owned by `M_VFXManager` (detection in vCam, rendering in VFX) via `{entity_id, occluders, enabled}` request payload. This follows the `U_ScreenShake` helper pattern.

## Known Risks

- shake layering can regress if the camera-manager integration is implemented with direct global-transform writes
- soft-zone math can drift if depth-aware reprojection is skipped
- silhouettes can leak on scene swap if the persistent manager keeps stale occluder references
- root/gameplay scene wiring can be missed if only templates are edited
- orbit/first-person can appear “done” on desktop while still being broken on mobile if `S_TouchscreenSystem` continues to dispatch zero look input
- touch-look can conflict with joystick/buttons if `UI_MobileControls` does not claim a dedicated free-screen look touch
- touch gameplay input can be silently overwritten if `S_InputSystem` continues processing `TouchscreenSource` zero payloads
- silhouette persistence can ship without user control if `UI_VFXSettingsOverlay` is not updated alongside state/actions/reducer/selectors
- keyboard look can appear implemented but still fail in runtime/profile/rebind flows if `U_InputMapBootstrapper`, `test_input_map.gd`, `U_RebindActionListBuilder`, locale keys, or save-trigger actions are left behind
- collision detector can appear correct in tests but fail in gameplay if authored occluding geometry is not migrated to layer 6 `vcam_occludable`
- gameplay camera math can pass isolated helper tests but still fail in live scenes if projection/raycast work accidentally uses the persistent root manager's viewport/world instead of the gameplay `SubViewport`
- same-frame camera application can hitch or lag a frame if implementation relies on root `_physics_process` tree order instead of the explicit `S_VCamSystem` -> `M_VCamManager` handoff
- **orientation continuity**: mode switches can cause disorienting heading jumps if rotation carry/reseed policy is not implemented in `S_VCamSystem` (see overview Rotation Continuity Contract)
- **reentrant blend**: a second `set_active_vcam()` during an active blend can pop or wedge blend state if mid-blend interruption semantics are not implemented
- **invalid target recovery**: freed follow targets or fixed anchors during gameplay can produce NaN transforms or crashes if per-tick validity checks are missing
- **tag ambiguity**: `follow_target_tag` can silently retarget the camera after scene-authoring changes unless multiple-match behavior is defined and warned
- **path recovery**: `use_path` cameras can drift or jump if path progress keeps advancing after the follow target becomes invalid
- **silhouette flicker**: occluders on marginal ray boundaries can cause per-frame material churn without debounce/hysteresis logic in `U_VCamSilhouetteHelper`
- **performance**: per-frame dictionary allocations in blend evaluation, soft-zone, and occlusion can cause frame-pacing regressions on mobile without reuse patterns
- silhouette color/opacity configurability is deferred to post-v1 (ship with single authored shader values)
- orbit zoom behavior is deferred to post-v1 (static authored distance for v1)

## Links

- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Tasks](vcam-manager-tasks.md)
