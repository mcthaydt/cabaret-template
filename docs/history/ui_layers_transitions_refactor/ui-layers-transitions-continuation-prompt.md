# UI, Layers & Transitions Refactor — Continuation Prompt

## Current Status

- Phase: **Phase 7 closeout + post-audit gap patch complete** (manual GUI smoke remains pending; full-suite aggregate run has one known perf-smoke failure).
- Branch: `UI-Looksmaxxing`.
- Working tree: includes the post-audit HUD ownership/test-guard corrections.
- Next step: Run the interactive/manual smoke pass in a GUI session.

### Phase 7 Gap Patch Summary (2026-03-04)

- Patched remaining HUD ownership/integration gaps discovered during post-closeout audit:
  - removed gameplay-scene HUD embeds from:
    - `scenes/gameplay/gameplay_base.tscn`
    - `scenes/gameplay/gameplay_alleyway.tscn`
    - `scenes/gameplay/gameplay_bar.tscn`
    - `scenes/gameplay/gameplay_exterior.tscn`
    - `scenes/gameplay/gameplay_interior_house.tscn`
  - added style regression guard:
    - `tests/unit/style/test_style_enforcement.gd::test_gameplay_scenes_do_not_embed_hud_instances`
  - fixed style helper iteration regression in `tests/unit/style/test_style_enforcement.gd` (`_collect_interaction_resource_placement_violations`) so file entries advance correctly.
- Synced architecture/docs after patch:
  - `docs/guides/SCENE_ORGANIZATION_GUIDE.md` gameplay hierarchy and UI naming references now match root-managed HUD lifecycle.
  - `docs/guides/DEV_PITFALLS.md` now documents the new style guard.
  - `AGENTS.md` gameplay-scene guidance now explicitly states HUD is root-managed (no gameplay HUD nodes).
- Verification reruns after patch:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (pass `13/13`)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_manager -ginclude_subdirs=true` (pass `97/102` with `5` known pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true` (pass `200/202` with `2` mobile pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_manager -ginclude_subdirs=true` (pass `90/90`)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (pass `51/52` with `1` known pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (pass `414/414`)
  - `tools/run_gut_suite.sh -gdir=res://tests -ginclude_subdirs=true` (pass `2758/2768` with `9` known pending, `1` failing performance-smoke test in aggregate run: `tests/integration/lighting/test_character_zone_lighting_flow.gd::test_multi_character_multi_zone_performance_smoke`)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/lighting -ginclude_subdirs=true` (isolated rerun pass `7/7`; aggregate failure appears load-sensitive/flaky rather than HUD-patch related)

### Phase 7 Completion Summary (2026-03-03)

- Final validation:
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` (pass `2758/2767` with `9` known pending tests, `0` failures).
- Documentation closeout:
  - `docs/guides/SCENE_ORGANIZATION_GUIDE.md` updated with explicit root container ServiceLocator registrations and HUD lifecycle contract.
  - `docs/guides/DEV_PITFALLS.md` updated with `U_CanvasLayers` layer-assignment guidance and manager-instantiated HUD reminder.
  - `docs/history/ui_layers_transitions_refactor/ui-layers-transitions-tasks.md` updated with Phase 7 completion notes/checklist.
- `AGENTS.md` reviewed; no additional updates were required because container/HUD architecture guidance from Phases 4-6 is already captured.
- Manual smoke note:
  - GUI-driven smoke checks (damage flash layering and shell transition HUD toggles) were not run in this headless terminal workflow.

### Phase 6 Implementation Summary (2026-03-03)

- Implementation commit:
  - `31a05703` (`refactor(ui): manager-instantiate hud lifecycle`)
- HUD lifecycle now routes through scene manager + root container contracts:
  - removed HUD instance from `scenes/templates/tmpl_base_scene.tscn` (template gameplay scenes no longer embed HUD);
  - `M_SceneManager` now instantiates/owns `ui_hud_overlay.tscn` under `hud_layer`, with duplicate-guard for existing HUD instances;
  - `UI_HudController` no longer reparenting itself (`_reparent_to_root_hud_layer` removed).
- HUD scene defaults aligned with manager lifecycle:
  - `scenes/ui/hud/ui_hud_overlay.tscn` now starts hidden (`visible = false`) and uses HUD layer ordering (`layer = 6`).
- Added/updated coverage for new contract:
  - `tests/unit/scene_manager/test_m_scene_manager.gd::test_manager_instantiates_hud_under_hud_layer`
  - Scene-manager harness updates now register `hud_layer` where `M_SceneManager` is constructed in lightweight integration/unit suites.
- Phase 6 verification:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (pass 12/12)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_manager -ginclude_subdirs=true` (pass 97/102 with 5 pre-existing pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_manager -ginclude_subdirs=true` (pass 90/90)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true` (pass 200/202 with 2 mobile-only pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/integration -ginclude_subdirs=true` (pass 59/59)
  - `tools/run_gut_suite.sh -gdir=res://tests -ginclude_subdirs=true` (pass 2758/2767 with 9 known pending; 0 failures)

### Phase 5 Implementation Summary (2026-03-03)

- Implementation commits:
  - `7fb773f6` (`refactor(ui): decouple hud visibility from transition internals`)
  - `b8d7ce1e` (`fix(ui): keep hud reparenting while decoupling transitions`)
- `UI_HudController` now owns visibility with Redux state:
  - hides when `scene.is_transitioning` is true or `navigation.shell != "gameplay"`;
  - re-shows automatically when gameplay shell resumes after transition completion;
  - clears active HUD feedback channels when hidden to avoid stale interaction blockers.
  - existing HUD reparent path is intentionally retained in this phase (`_reparent_to_root_hud_layer`) so Phase 6 can handle manager-instantiated HUD lifecycle separately.
- `Trans_LoadingScreen` no longer reaches into HUD internals:
  - removed `_hide_hud_layers`, `_restore_hidden_hud_layers`, `_resolve_hud_controller`, `_toggle_visibility`, and `_temporarily_hidden_hud_nodes`.
- Removed obsolete HUD registration API surface:
  - `I_SceneManager`, `M_SceneManager`, and `MockSceneManagerWithTransition` no longer expose/register/get HUD controller methods.
  - `UI_HudController` no longer registers/unregisters itself with scene manager.
- Added HUD visibility coverage:
  - `tests/unit/ui/test_hud_controller.gd::test_hud_visibility_tracks_transition_state_and_shell`.
- Phase 5 verification:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_manager -ginclude_subdirs=true` (pass 96/101 with 5 pre-existing pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_manager -ginclude_subdirs=true` (pass 90/90)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true` (pass 200/202 with 2 mobile-only pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (pass 414/414)

### Phase 4 Hardening Summary (2026-03-03)

- Implementation commit: `962d19d5` (`refactor(ui): harden service-locator container contracts and endgame snap flow`).
- Closed remaining Phase 1-4 gaps after initial Phase 4 landing:
  - strict ServiceLocator lookups added for remaining phase-adjacent runtime container discovery:
    - `u_display_color_grading_applier` (`post_process_overlay`)
    - `u_display_quality_applier` (`game_viewport`, owner viewport fallback retained for isolated tests)
    - `m_audio_manager` (`game_viewport`)
    - `m_time_manager` (`ui_overlay_stack`)
    - `m_character_lighting_manager` (`active_scene_container`, root-search fallback removed)
    - `ui_hud_controller` (`hud_layer`)
  - duplicate endgame overlay snap internals extracted to shared helper:
    - `scripts/scene_management/helpers/u_transition_overlay_snap.gd`
    - consumed by `ui_game_over.gd` and `ui_victory.gd`
  - snapped-overlay resume timing restored to fast return default in `trans_fade.gd` (`snapped_overlay_fade_in_duration = 0.2`).
- Test harness hardening completed for strict container registration (notably `hud_layer`, `active_scene_container`, and `game_viewport`).
- Verification (post-hardening):
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/localization -ginclude_subdirs=true` (pass 20/20)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_manager -ginclude_subdirs=true -gselect=test_endgame_flows` (pass 5/5)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (pass 414/414)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (pass 51/52 with 1 pre-existing pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true` (pass 199/201 with 2 mobile-only pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_manager -ginclude_subdirs=true` (pass 96/101 with 5 pre-existing pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (pass 12/12)
  - `tools/run_gut_suite.sh -gdir=res://tests -ginclude_subdirs=true` (pass 2756/2765 with 9 known pending; 0 failures)

### Phase 4 Implementation Summary (2026-03-03)

- Implementation commit: `6eb4cf1c` (`refactor(scene): use ServiceLocator-only container discovery`).
- `scripts/root.gd` now registers root container services used by scene/display systems:
  - `hud_layer`, `ui_overlay_stack`, `transition_overlay`, `loading_overlay`, `game_viewport`, `active_scene_container`, `post_process_overlay`.
- `scripts/scene_management/helpers/u_scene_manager_node_finder.gd` now uses ServiceLocator-only lookups for all required containers (no `find_child()` or root walk fallback path).
- `scripts/managers/helpers/display/u_display_post_process_applier.gd` now resolves `post_process_overlay` and fallback `game_viewport` via ServiceLocator.
- `scripts/ui/menus/ui_game_over.gd` and `scripts/ui/menus/ui_victory.gd` now resolve `transition_overlay` via ServiceLocator in `_hide_immediately()`.
- `scripts/scene_management/u_transition_orchestrator.gd` no longer inspects overlay children directly; `scripts/scene_management/transitions/trans_fade.gd` now owns opaque-overlay detection/prep through `setup_for_opaque_overlay_resume(...)`.
- Test harness updates:
  - Scene manager test scaffolds now register container services (`active_scene_container`, `ui_overlay_stack`, `transition_overlay`, `loading_overlay`).
  - Display test scaffolds now register `post_process_overlay` and/or `game_viewport` services where needed.
- Phase 4 verification:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (pass 12/12)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_manager -ginclude_subdirs=true` (pass 96/101 with 5 pre-existing pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_manager -ginclude_subdirs=true` (pass 88/90; 2 failing endgame flow assertions in `test_endgame_flows.gd`)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (pass 51/52 with 1 pre-existing pending)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (pass 414/414)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/integration -ginclude_subdirs=true` (pass 59/59)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/ui -ginclude_subdirs=true` (pass 9/9)

### Phase 3 Implementation Summary (2026-03-03)

- Implementation commit: `018c4a14` (`refactor(vfx): route damage flash tweening through u_tween_manager`).
- `U_DamageFlash` now takes `(flash_rect, owner_node)` and creates tweens via `U_TweenManager.create_transition_tween(...)` using idle process mode plus explicit pause mode.
- Added `U_TweenManager.kill_tween(...)` and used it for damage-flash retrigger/cancel cleanup.
- Updated `M_VFXManager` construction to `U_DamageFlash.new(flash_rect, flash_instance)`.
- Updated damage flash helper tests for owner-node injection and null-owner safety.
- Phase 3 verification:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (pass 414/414)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_manager -ginclude_subdirs=true` (pass 96/101 with 5 pre-existing headless pending tests)

### Phase 2 Implementation Summary (2026-03-03)

- Implementation commit: `57c1db05` (`refactor(vfx): remove dead damage flash tween pause cache`).
- Removed `_tween_pause_mode` from `scripts/managers/helpers/u_damage_flash.gd`.
- Updated `tests/unit/managers/helpers/test_damage_flash.gd` to avoid internal cache assertions and validate tween creation directly.
- Confirmed no remaining `_tween_pause_mode` references in production/tests.
- Phase 2 verification:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (pass 414/414)

### Phase 1 Implementation Summary (2026-03-03)

- Implementation commit: `36e29d9b` (`refactor(ui): centralize canvas layers and lower damage flash z-order`).
- Added `scripts/ui/u_canvas_layers.gd` as the canonical CanvasLayer constants source.
- Moved `DamageFlashOverlay` from layer `110` to `90`.
- Replaced script-side hardcoded layer assignments with `U_CanvasLayers` constants (HUD controller, display post-process applier, cinema-grade applier/preview, debug cinema overlay).
- Updated `docs/guides/SCENE_ORGANIZATION_GUIDE.md` with canonical layer map, root hierarchy updates, and `U_CanvasLayers` references.
- Phase 1 verification:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (pass 12/12)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (pass 414/414)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (pass 51/52, 1 pre-existing pending)

### Phase 1 Outcome

- Layer constants are now centralized.
- Damage flash no longer renders above loading/transition overlays.
- Root and post-process layer documentation now references one constant source.

### Phase 0 Baseline Results (2026-03-03)

- `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`: pass (414/414).
- `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`: pass (51/52) with 1 pre-existing pending test (`test_ui_color_blind_layer_has_higher_layer_than_ui_overlay`, missing `UIOverlayStack` in test environment).
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`: pass (12/12).
- `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_management -ginclude_subdirs=true`: pass (30/30).
- Non-failing pre-existing runtime warning seen during test startup on macOS: `get_system_ca_certificates`.

### Phase 0 Inventory Snapshot

- Layer grep completed for `.tscn` (`layer = ...`) and `.gd` (`.layer = ...`) assignments.
- Full current layer map with source references is recorded in `docs/history/ui_layers_transitions_refactor/ui-layers-transitions-tasks.md` under "Phase 0 Completion Notes".

### Ad-Hoc Fixes Already on Branch

Several commits on `UI-Looksmaxxing` introduced visual fixes **outside** this refactor's phased plan. These work but introduce patterns the refactor must clean up:

| Commit | What it did | Anti-patterns introduced |
|--------|-------------|------------------------|
| `db570323` (fade-in transition) | Endgame screens snap TransitionOverlay to opaque via `_hide_immediately()`, orchestrator detects `already_black` and skips fade-out | **Phase 4 cleanup applied**: `find_child("TransitionOverlay")` removed from endgame screens; overlay introspection moved from orchestrator to `Trans_Fade`; duration mutation encapsulated behind `Trans_Fade` helper |
| `02ed9612` (remove red flash from menus) | `M_VfxManager` subscribes to Redux state, calls `cancel_flash()` when shell leaves gameplay | Good pattern (Redux subscription) — reference as precedent in Phase 5. `cancel_flash()` is new on `U_DamageFlash` and must be accounted for in Phase 3 tween unification |
| `db570323` (root.tscn) | TransitionOverlay explicitly set to `layer = 50` | Correct value per target layer stack, but done without `U_CanvasLayers` constant — Phase 1 should reference this as already done |

**Status update:** duplicated `_hide_immediately()` internals were consolidated into shared helper `U_TransitionOverlaySnap` in the hardening addendum. Endgame screens still intentionally trigger overlay alpha snap, but implementation is now centralized.

## Context

The UI layer stack, scene transitions, VFX overlays, and HUD management have grown organically across multiple feature additions (post-processing, cinema grading, damage flash, loading screen, overlay stack). The result is:

- **Scattered layer constants** — layer numbers are baked into `.tscn` files and hardcoded in scripts with no single source of truth.
- **DamageFlash renders above LoadingOverlay** — layer 110 vs 100, with only a Redux state gate preventing visual overlap (race-prone).
- **HUD self-reparenting removed in Phase 6** — `M_SceneManager` now instantiates HUD directly under root `HUDLayer`; `UI_HudController` no longer reparent-couples to scene structure.
- **Inconsistent node discovery** — mix of `ServiceLocator`, `find_child()`, and fallback chains across transition classes and managers.
- **Transitions know about HUD internals** — **resolved in Phase 5**; `Trans_LoadingScreen` no longer queries or mutates HUD state directly.
- **Inconsistent tween creation** — `Trans_Fade` uses `U_TweenManager`, `U_DamageFlash` manually creates tweens.

### Corrected Findings (from codebase exploration)

- **`_effects_container` is NOT dead code** — it is actively used by `U_ParticleSpawner` → `S_SpawnParticlesSystem`, `S_JumpParticlesSystem`, `S_LandingParticlesSystem`. DO NOT REMOVE.
- **Existing Redux actions already cover transition phases** — no new signals or actions needed. The `scene` slice already has `is_transitioning`, and the `navigation` slice has `shell`. HUD just needs to subscribe and toggle visibility.
- **HUD visibility now Redux-driven** — `UI_HudController` subscribes to scene/navigation slices and toggles `visible` from `scene.is_transitioning` + `navigation.shell` (`"gameplay"` only).
- **Post-process layers are in a separate viewport layer space** — layers 2-5 in `ui_post_process_overlay.tscn` are inside `GameViewport` (different layer space from root viewport). Keep as `.tscn` literals; `U_CanvasLayers.PP_*` constants are reference documentation only.

## Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Node discovery pattern | ServiceLocator only | No `find_child` fallbacks — all containers registered in `root.gd` |
| HUD lifecycle | Persistent show/hide | Toggle `visible`, don't create/destroy — simpler, avoids re-init |
| Transition↔HUD decoupling | Redux actions | HUD subscribes to scene slice (`is_transitioning` + `shell`) — no new signals needed |
| Scope | Full refactor (all phases) | Complete the cleanup in one pass |

## Goals

1. Centralize all canvas layer constants into a single `U_CanvasLayers` class.
2. Fix DamageFlash z-order so gameplay VFX never renders above loading/transition overlays.
3. Replace HUD self-reparenting with explicit manager-driven instantiation.
4. Standardize node discovery to ServiceLocator only (no `find_child` fallbacks).
5. Decouple transitions from HUD knowledge via Redux state subscriptions.
6. Unify tween creation through `U_TweenManager`.
7. Remove dead code (vestigial `_tween_pause_mode` field — but NOT `_effects_container`).

## Key Files

| File | Role |
|------|------|
| `scenes/root.tscn` | Root scene with all CanvasLayer nodes |
| `scripts/root.gd` | ServiceLocator bootstrap, container registration |
| `scripts/managers/m_vfx_manager.gd` | VFX coordinator, damage flash instantiation |
| `scripts/managers/helpers/u_damage_flash.gd` | Damage flash tween helper |
| `scripts/managers/m_scene_manager.gd` | Scene transitions and overlay stack orchestration |
| `scripts/managers/m_display_manager.gd` | Display settings, post-process management |
| `scripts/interfaces/i_scene_manager.gd` | Scene manager interface (HUD registration methods removed in Phase 5) |
| `scripts/scene_management/u_transition_orchestrator.gd` | Transition sequencing |
| `scripts/scene_management/u_transition_factory.gd` | Transition type registry |
| `scripts/scene_management/transitions/trans_fade.gd` | Fade-to-black transition |
| `scripts/scene_management/transitions/trans_loading_screen.gd` | Loading screen transition (HUD reach-in removed in Phase 5) |
| `scripts/scene_management/helpers/u_overlay_stack_manager.gd` | UIOverlayStack push/pop |
| `scripts/scene_management/helpers/u_scene_manager_node_finder.gd` | Container/node discovery (migrate to ServiceLocator) |
| `scripts/managers/helpers/display/u_display_post_process_applier.gd` | Post-process shader management |
| `scripts/managers/helpers/display/u_display_color_grading_applier.gd` | Per-scene cinema grade |
| `scripts/ui/hud/ui_hud_controller.gd` | HUD logic, Redux-driven visibility |
| `scripts/ui/base/base_overlay.gd` | Base overlay class |
| `scenes/ui/overlays/ui_damage_flash_overlay.tscn` | DamageFlash CanvasLayer (layer=110, change to 90) |
| `scenes/ui/overlays/ui_post_process_overlay.tscn` | Post-process CanvasLayers (layers 2-5, inside GameViewport) |
| `scenes/ui/hud/ui_hud_overlay.tscn` | HUD CanvasLayer |
| `scenes/templates/tmpl_base_scene.tscn` | Base scene template (remove HUD instance) |
| `scripts/ui/menus/ui_game_over.gd` | Endgame screen — `_hide_immediately()` now calls shared `U_TransitionOverlaySnap` helper |
| `scripts/ui/menus/ui_victory.gd` | Endgame screen — `_hide_immediately()` now calls shared `U_TransitionOverlaySnap` helper |
| `tests/mocks/mock_scene_manager_with_transition.gd` | Mock scene manager (remove HUD mock methods) |

## Existing Redux Actions (Reference)

The Redux store already dispatches these relevant actions — no new ones needed:

- **`scene` slice**: Contains `is_transitioning` (bool) — set true during transitions, false on completion.
- **`navigation` slice**: Contains `shell` (StringName) — `"gameplay"`, `"main_menu"`, etc.
- `UI_HudController` already subscribes to `slice_updated` and checks `shell` in `_update_health()`. Extend this pattern to toggle the entire HUD's `visible` property.
- **Precedent:** `M_VfxManager` (commit `02ed9612`) already subscribes to the state store and detects shell changes to cancel the damage flash. This validates the Redux-driven approach and can serve as a reference implementation for Phase 5.

## Current Layer Stack (Before Refactor)

```
Layer   Node                        Purpose                                        Status
─────   ──────────────────────────  ────────────────────────                       ──────
2-5     PostProcessOverlay          Shaders (inside GameViewport — separate space)
6       HUDLayer                    HUD (reparented at runtime)
10      UIOverlayStack              Menus/overlays
11      UIColorBlindLayer           Color blind for UI
50      TransitionOverlay           Fade-to-black                                  ✓ layer=50 set in root.tscn (db570323)
100     LoadingOverlay              Loading screen
110     DamageFlashOverlay          Red flash (PROBLEM: above loading)             ✗ still 110, needs → 90
```

## Target Layer Stack (After Refactor)

```
Layer   Node                        Purpose
─────   ──────────────────────────  ────────────────────────
2-5     PostProcessOverlay          Shaders (inside GameViewport — separate layer space)
6       HUDLayer                    HUD (manager-instantiated, persistent show/hide)
10      UIOverlayStack              Menus/overlays
11      UIColorBlindLayer           Color blind for UI
50      TransitionOverlay           Fade-to-black
90      DamageFlashOverlay          Red flash (FIXED: below loading)
100     LoadingOverlay              Loading screen
101     MobileControls              Mobile input overlay
128     DebugOverlay                Debug info
```

## Required Readings (Do Not Skip)

- `AGENTS.md` — project conventions, testing, and update rules.
- `docs/guides/DEV_PITFALLS.md` — known gotchas.
- `docs/guides/STYLE_GUIDE.md` — naming, formatting, prefix rules.
- `docs/guides/SCENE_ORGANIZATION_GUIDE.md` — layer/container reference.
- `docs/history/ui_layers_transitions_refactor/ui-layers-transitions-tasks.md` — the task checklist.

## Process for Completion (Every Phase)

1. Start with the next unchecked task list section.
2. Plan the smallest safe batch of changes; verify references before executing.
3. Execute changes → update references → run headless import if scenes/scripts moved or renamed.
4. Run relevant tests (style suite mandatory after any moves/renames).
5. Update task checklist with [x] and completion notes (commit hash, tests run, deviations).
6. Update this continuation prompt with status, tests run, and next step.
7. Update `AGENTS.md` and/or `DEV_PITFALLS.md` if new patterns or pitfalls emerged.
8. Commit with a clear message; commit documentation updates separately from implementation.
