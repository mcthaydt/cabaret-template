# Style & Scene Cleanup – Continuation Guide

## 🚨 CRITICAL WORKFLOW REQUIREMENT 🚨

Before doing ANY work on style/scene cleanup:

1. **Open `docs/general/cleanup/style-scene-cleanup-tasks.md` FIRST.**
2. **Find the next unchecked task `[ ]` in sequence** (top to bottom, unless marked `[P]` for parallel).
3. **Complete one task at a time**, keeping changes as small and focused as possible.
4. **Immediately change `[ ]` to `[x]`** once a task is completed and tests/docs are updated.
5. **Keep documentation changes and implementation in separate commits**, per `AGENTS.md`.
6. **After each completed phase**, update THIS continuation prompt with:
   - Current status (which phases are done).
   - Any deviations from the plan.
   - Pointers to relevant commits.

If you are ever unsure what to do next, **read the tasks file** and follow the next `[ ]` entry.

---

## Current Status (2025-12-08 – Phase 5 Complete + Bonus Refactoring)

- **PRD**: `docs/general/cleanup/style-scene-cleanup-prd.md` – Drafted.
- **Plan**: `docs/general/cleanup/style-scene-cleanup-plan.md` – Phases 0–9 defined with user-approved policies.
- **Tasks**: `docs/general/cleanup/style-scene-cleanup-tasks.md` – Phase 0-5 tasks complete (T050-T056 ✅).

**Execution Status**:

- Phase 0 – Discovery & Inventory: **✅ COMPLETE** (Commit: 032bb7d - documentation updates)
- Phase 1 – Spec & Guide Updates: **✅ COMPLETE** (Commit: 032bb7d)
- Phase 2 – Responsibility Consolidation (Pause/Cursor): **✅ COMPLETE**
- Phase 3 – Naming & Prefix Migration: **✅ COMPLETE**
- Phase 4 – Tests & Tooling Hardening: **✅ COMPLETE** (2025-12-08)
- Phase 5 – Docs & Planning Alignment: **✅ COMPLETE** (2025-12-08, Commits: 30dd4d6, 8b1ae15, 011c4fa)
  - **T050-T056 Complete**: All subsystem PRDs marked PRODUCTION READY + UI→Redux→Scene Manager rule codified
  - ECS: Batches 1-4 complete, debugger tooling de-scoped
  - State Store: Phases 1-16.5 complete, mock data removed, entity coordination ready
  - Scene Manager: All phases complete, post-hardening done
  - Input Manager: All planned features implemented (profiles, rebinding, device detection)
  - UI Manager: All planned features implemented (navigation slice, registry, settings)
  - **T055**: All subsystem continuation prompts updated with style/scene references
  - **T056**: UI→Redux→Scene Manager architectural rule codified with 4 violations inventoried
- **Bonus Work** – UI→Redux→Scene Manager Refactoring: **✅ COMPLETE** (2025-12-08, Commits: c9c6a26, 20978da)
  - **Added**: `navigate_to_ui_screen()` Redux action for UI scene transitions
  - **Refactored**: 4 UI scripts to eliminate direct M_SceneManager calls
    - ui_settings_menu.gd ✅
    - ui_input_profile_selector.gd ✅
    - ui_input_rebinding_overlay.gd ✅
    - ui_touchscreen_settings_overlay.gd ✅
  - **Tests**: All 128 UI tests passing ✅ (fixed 3 failing tests)
  - **Architecture**: UI scripts now dispatch Redux actions exclusively
- Phase 6 – ECS Entity IDs & Tagging: **NOT STARTED**
- Phase 7 – Spawn Registry & Spawn Conditions: **NOT STARTED**
- Phase 8 – Multi-Slot Save Manager: **NOT STARTED**
- Phase 9 – Final Validation & Regression Sweep: **NOT STARTED**

**Policy Decisions Approved**:
- ✅ UI screen controllers: Add `ui_` prefix
- ✅ UI scenes: Migrate all 16 to `ui_` prefix
- ✅ Pause authority: M_PauseManager is sole authority
- ✅ Hazard/objective scenes: Add `prefab_` prefix
- ✅ Style enforcement: Comprehensive automated testing in place

---

## How to Continue

1. **Read the PRD and Plan**
   - `docs/general/cleanup/style-scene-cleanup-prd.md`
   - `docs/general/cleanup/style-scene-cleanup-plan.md`
2. **Re‑read core guidelines** (once per session):
   - `AGENTS.md`
   - `docs/general/DEV_PITFALLS.md`
   - `docs/general/STYLE_GUIDE.md`
   - `docs/general/SCENE_ORGANIZATION_GUIDE.md`
3. **Start with Phase 0 tasks** in `style-scene-cleanup-tasks.md`:
   - T000–T008 establish the actual, current deviations and inventory.
4. **Use TDD where applicable**:
   - For style/scene enforcement tests, write failing tests first, then implement changes.
5. **Keep changes scoped**:
   - Do not mix Phase 2 pause refactors with Phase 3 naming changes in one commit.

---

## After Each Phase – Required Updates

When you complete a phase (e.g., Phase 0 or Phase 1):

1. **Update this file**:
   - Mark the phase as complete in “Execution Status”.
   - Add a short bullet list of what changed and any deviations from the original plan.
2. **Update relevant docs**:
   - If Phase 1 changed `STYLE_GUIDE.md`, ensure the PRD/Plan references are still accurate.
3. **Commit discipline**:
   - Implementation commit(s) for that phase (code/tests).
   - Separate documentation commit updating PRD/Plan/Tasks/Continuation prompt.

---

## Related Documents

- `docs/general/STYLE_GUIDE.md`
- `docs/general/SCENE_ORGANIZATION_GUIDE.md`
- `docs/general/DEV_PITFALLS.md`
- `AGENTS.md`

- `docs/ecs/ecs_architecture.md`
- `docs/state store/redux-state-store-prd.md`
- `docs/scene manager/scene-manager-prd.md`
- `docs/input manager/input-manager-prd.md`
- `docs/ui manager/ui-manager-prd.md`

These subsystem PRDs/plans will be referenced in Phase 5 when aligning documentation.

---

## Notes for Future Contributors

- The ultimate goal of this cleanup is to:
  - Achieve **10/10** ratings for modularity, scalability, and architecture.
  - Ensure **every production file** has a documented prefix and fits into a well‑defined category.
  - Keep `STYLE_GUIDE.md` and `SCENE_ORGANIZATION_GUIDE.md` as living documents that accurately describe the current codebase.
- If you discover new gaps or edge cases:
  - Do **not** “just fix them” silently.
  - Add new tasks to `style-scene-cleanup-tasks.md` and update the PRD/Plan if needed.
