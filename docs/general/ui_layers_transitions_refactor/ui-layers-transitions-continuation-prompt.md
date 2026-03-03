# UI, Layers & Transitions Refactor — Continuation Prompt

## Current Status

- Phase: **Phase 0 complete** (Baseline & Inventory done on 2026-03-03).
- Branch: `UI-Looksmaxxing`.
- Working tree: docs-only updates pending commit.
- Next step: Phase 1 — Centralize `U_CanvasLayers` constants and move DamageFlash from layer 110 to 90.

### Phase 0 Baseline Results (2026-03-03)

- `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`: pass (414/414).
- `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`: pass (51/52) with 1 pre-existing pending test (`test_ui_color_blind_layer_has_higher_layer_than_ui_overlay`, missing `UIOverlayStack` in test environment).
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`: pass (12/12).
- `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_management -ginclude_subdirs=true`: pass (30/30).
- Non-failing pre-existing runtime warning seen during test startup on macOS: `get_system_ca_certificates`.

### Phase 0 Inventory Snapshot

- Layer grep completed for `.tscn` (`layer = ...`) and `.gd` (`.layer = ...`) assignments.
- Full current layer map with source references is recorded in `docs/general/ui_layers_transitions_refactor/ui-layers-transitions-tasks.md` under "Phase 0 Completion Notes".

### Ad-Hoc Fixes Already on Branch

Several commits on `UI-Looksmaxxing` introduced visual fixes **outside** this refactor's phased plan. These work but introduce patterns the refactor must clean up:

| Commit | What it did | Anti-patterns introduced |
|--------|-------------|------------------------|
| `db570323` (fade-in transition) | Endgame screens snap TransitionOverlay to opaque via `_hide_immediately()`, orchestrator detects `already_black` and skips fade-out | `find_child("TransitionOverlay")` in `ui_game_over.gd` and `ui_victory.gd`; orchestrator iterates overlay children by name to read `TransitionColorRect` alpha; orchestrator mutates `effect.duration` directly |
| `02ed9612` (remove red flash from menus) | `M_VfxManager` subscribes to Redux state, calls `cancel_flash()` when shell leaves gameplay | Good pattern (Redux subscription) — reference as precedent in Phase 5. `cancel_flash()` is new on `U_DamageFlash` and must be accounted for in Phase 3 tween unification |
| `db570323` (root.tscn) | TransitionOverlay explicitly set to `layer = 50` | Correct value per target layer stack, but done without `U_CanvasLayers` constant — Phase 1 should reference this as already done |

**Key concern:** `_hide_immediately()` is copy-pasted identically in both `ui_game_over.gd:98-108` and `ui_victory.gd:127-137`. Both use `tree.root.find_child()` and directly manipulate overlay internals. Phase 4 must migrate these to ServiceLocator, and Phase 4/5 should consider whether this logic belongs in the transition system rather than individual menu screens.

## Context

The UI layer stack, scene transitions, VFX overlays, and HUD management have grown organically across multiple feature additions (post-processing, cinema grading, damage flash, loading screen, overlay stack). The result is:

- **Scattered layer constants** — layer numbers are baked into `.tscn` files and hardcoded in scripts with no single source of truth.
- **DamageFlash renders above LoadingOverlay** — layer 110 vs 100, with only a Redux state gate preventing visual overlap (race-prone).
- **HUD self-reparents at runtime** — `UI_HudController` uses deferred `find_child("HUDLayer")` to escape the SubViewport, coupling itself to the root scene structure.
- **Inconsistent node discovery** — mix of `ServiceLocator`, `find_child()`, and fallback chains across transition classes and managers.
- **Transitions know about HUD internals** — `Trans_LoadingScreen` does a ServiceLocator round-trip to find and hide the HUD controller.
- **Inconsistent tween creation** — `Trans_Fade` uses `U_TweenManager`, `U_DamageFlash` manually creates tweens.

### Corrected Findings (from codebase exploration)

- **`_effects_container` is NOT dead code** — it is actively used by `U_ParticleSpawner` → `S_SpawnParticlesSystem`, `S_JumpParticlesSystem`, `S_LandingParticlesSystem`. DO NOT REMOVE.
- **Existing Redux actions already cover transition phases** — no new signals or actions needed. The `scene` slice already has `is_transitioning`, and the `navigation` slice has `shell`. HUD just needs to subscribe and toggle visibility.
- **HUD already subscribes to scene/navigation slices** — `UI_HudController` already subscribes to `slice_updated` for the `"scene"` slice (line 131-133) and calls `_update_display()`. Just needs a visibility toggle added.
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
| `scripts/managers/m_scene_manager.gd` | Scene transitions, overlay stack, HUD registration |
| `scripts/managers/m_display_manager.gd` | Display settings, post-process management |
| `scripts/interfaces/i_scene_manager.gd` | Scene manager interface (HUD methods to remove) |
| `scripts/scene_management/u_transition_orchestrator.gd` | Transition sequencing |
| `scripts/scene_management/u_transition_factory.gd` | Transition type registry |
| `scripts/scene_management/transitions/trans_fade.gd` | Fade-to-black transition |
| `scripts/scene_management/transitions/trans_loading_screen.gd` | Loading screen transition (HUD hiding to remove) |
| `scripts/scene_management/helpers/u_overlay_stack_manager.gd` | UIOverlayStack push/pop |
| `scripts/scene_management/helpers/u_scene_manager_node_finder.gd` | Container/node discovery (migrate to ServiceLocator) |
| `scripts/managers/helpers/display/u_display_post_process_applier.gd` | Post-process shader management |
| `scripts/managers/helpers/display/u_display_cinema_grade_applier.gd` | Per-scene cinema grade |
| `scripts/ui/hud/ui_hud_controller.gd` | HUD logic, viewport escape reparenting |
| `scripts/ui/base/base_overlay.gd` | Base overlay class |
| `scenes/ui/overlays/ui_damage_flash_overlay.tscn` | DamageFlash CanvasLayer (layer=110, change to 90) |
| `scenes/ui/overlays/ui_post_process_overlay.tscn` | Post-process CanvasLayers (layers 2-5, inside GameViewport) |
| `scenes/ui/hud/ui_hud_overlay.tscn` | HUD CanvasLayer |
| `scenes/templates/tmpl_base_scene.tscn` | Base scene template (remove HUD instance) |
| `scripts/ui/menus/ui_game_over.gd` | Endgame screen — has `_hide_immediately()` with `find_child()` and overlay manipulation (migrate in Phase 4/5) |
| `scripts/ui/menus/ui_victory.gd` | Endgame screen — identical `_hide_immediately()` pattern (migrate in Phase 4/5) |
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
- `docs/general/DEV_PITFALLS.md` — known gotchas.
- `docs/general/STYLE_GUIDE.md` — naming, formatting, prefix rules.
- `docs/general/SCENE_ORGANIZATION_GUIDE.md` — layer/container reference.
- `docs/general/ui_layers_transitions_refactor/ui-layers-transitions-tasks.md` — the task checklist.

## Process for Completion (Every Phase)

1. Start with the next unchecked task list section.
2. Plan the smallest safe batch of changes; verify references before executing.
3. Execute changes → update references → run headless import if scenes/scripts moved or renamed.
4. Run relevant tests (style suite mandatory after any moves/renames).
5. Update task checklist with [x] and completion notes (commit hash, tests run, deviations).
6. Update this continuation prompt with status, tests run, and next step.
7. Update `AGENTS.md` and/or `DEV_PITFALLS.md` if new patterns or pitfalls emerged.
8. Commit with a clear message; commit documentation updates separately from implementation.
