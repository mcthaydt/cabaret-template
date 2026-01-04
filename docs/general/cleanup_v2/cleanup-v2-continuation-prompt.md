# Cleanup V2 Continuation Prompt

Use this prompt to resume Cleanup V2 work in a new session.

---

## Context

Cleanup V2 is a focused maintenance pass to reduce scaling risk and improve long-term readability:

1. **Reduce “big orchestrator” change risk** (notably `M_SceneManager` and `M_StateStore`) by extracting cohesive helpers and tightening boundaries.
2. **Increase type/shape safety** for Redux actions/state by using action payload schemas for high-risk domains (scene/navigation/input/save).
3. **Tighten enforcement** so naming/organization standards don’t drift (expand style/org tests to currently-uncovered core dirs).
4. **Minor organization cleanups** (odd scene placements, inconsistent UI settings foldering, optional spawn-point ordering).

Work should be **behavior-preserving by default** and executed with **TDD** where behavior/contracts change.

---

## Read First

- `docs/general/STYLE_GUIDE.md`
- `docs/general/SCENE_ORGANIZATION_GUIDE.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/general/cleanup_v2/cleanup-v2-tasks.md`

---

## Decisions Locked (So Work Is Unambiguous)

1. **Action validation:** Do **not** rewrite actions to “payload-only”. Extend `U_ActionRegistry` to validate **root action keys** (for `U_NavigationActions`) via `required_root_fields`.
2. **Input sources naming:** Keep existing filenames under `scripts/input/sources/` and enforce via a **suffix rule**: `*_source.gd`.
3. **UI overlay foldering:** Remove the one-off `scenes/ui/settings/` folder by moving `ui_vfx_settings_overlay.tscn` into `scenes/ui/`.

---

## Current Progress

- Phase 0 complete:
  - Baseline style + unit suites pass (see tasks doc for warning notes).
  - Hotspot inventory recorded (largest scripts list + UI TODOs + `tmp_invalid_gameplay` references).
- Phase 1 complete:
  - Style enforcement now covers additional production dirs (`scripts/core`, `scripts/interfaces`, `scripts/utils`, `scripts/input`, `scripts/scene_management`, `scripts/events`).
  - Input sources enforced via suffix rule: `scripts/input/sources/*_source.gd`.
  - Scene naming checks recurse into subdirectories (e.g., `scenes/ui/settings/`).
- Phase 2 complete:
  - `U_ActionRegistry` now supports `required_root_fields` (with non-empty checks for `StringName`/`String` fields).
  - High-risk action schemas applied for scene/navigation/input actions.

 - Phase 3A (Scene Manager) complete:
  - Recorded current size/dup seams for `scripts/managers/m_scene_manager.gd` (1039 lines; see tasks doc).
  - Removed manager-local cache wrapper methods and routed caching/preload usage through `U_SceneCache`.
  - Removed manager-local loader wrapper methods and routed scene load/unload through `U_SceneLoader`.
  - Refactored `U_OverlayStackManager` to avoid reading `M_SceneManager` internals (now takes explicit callables/nodes); updated `M_SceneManager` + `U_NavigationReconciler` call sites.
 - Phase 3B (State Store) complete:
  - Recorded current size/dup seams for `scripts/state/m_state_store.gd` (555 lines; see tasks doc).
  - Extracted action history into `scripts/state/utils/u_action_history_buffer.gd` (store API unchanged).
  - Extracted perf metrics into `scripts/state/utils/u_store_performance_metrics.gd` (store API unchanged).

Next: Phase 4 organization + naming cleanups (Task 4.1).

---

## Ground Rules (TDD + Safety)

1. **Follow TDD** for any contract change: Red → Green → Refactor.
2. **Prefer characterization tests** before refactors of large orchestrators (lock in current behavior first).
3. **Run style + scene org test** whenever moving/renaming scripts/scenes/resources:
   - `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
4. Keep public surfaces stable unless the tasks doc explicitly calls for policy changes.

---

## Suggested Execution Order (Lowest Risk → Highest Impact)

1. **Baseline** (Phase 0.3): run unit + style suites and record results.
2. **Enforcement tightening** (Phase 1): expand style/scene org tests to cover currently-unchecked dirs + recurse scene checks; enforce `scripts/input/sources/*_source.gd`.
3. **Action schemas** (Phase 2): add schema tests + required_fields to “scene/navigation/input/save” actions.
4. **Orchestrator decomposition** (Phase 3): characterization tests first, then extract one helper at a time.
5. **Small org/UX polish** (Phase 4–5) as cleanup after the safety nets exist.

---

## Quick Start Prompt

Copy this to start a new session:

```
I’m continuing Cleanup V2.

Read:
- docs/general/cleanup_v2/cleanup-v2-tasks.md
- docs/general/STYLE_GUIDE.md
- docs/general/SCENE_ORGANIZATION_GUIDE.md

Start with Phase 0 Task 0.3 (baseline test runs), then continue in order. Follow TDD and update checkboxes as tasks complete.
```
