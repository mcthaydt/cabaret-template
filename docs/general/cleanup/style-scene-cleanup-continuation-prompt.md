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

## Current Status (2025-12-03 – Phase 0 & 1 Complete)

- **PRD**: `docs/general/cleanup/style-scene-cleanup-prd.md` – Drafted.
- **Plan**: `docs/general/cleanup/style-scene-cleanup-plan.md` – Phases 0–9 defined with user-approved policies.
- **Tasks**: `docs/general/cleanup/style-scene-cleanup-tasks.md` – Phase 0 & 1 tasks complete.

**Execution Status**:

- Phase 0 – Discovery & Inventory: **✅ COMPLETE** (Commit: 032bb7d - documentation updates)
  - Comprehensive inventory of 175 scripts, 31 scenes, 57 resources
  - Identified 36 files requiring renaming (UI scripts, UI scenes, prefab scenes)
  - Documented pause authority conflict (M_PauseManager vs M_SceneManager)
  - Cross-checked all subsystem PRDs vs implementation

- Phase 1 – Spec & Guide Updates: **✅ COMPLETE** (Commit: 032bb7d)
  - Added complete prefix matrix to STYLE_GUIDE.md (6 subsystem layers + exceptions)
  - Updated SCENE_ORGANIZATION_GUIDE.md with manager init order and current system roster
  - Updated AGENTS.md with mandatory style/scene test requirement
  - All T010-T017 tasks checked off

- Phase 2 – Responsibility Consolidation (Pause/Cursor): **IN PROGRESS**
- Phase 3 – Naming & Prefix Migration: **NOT STARTED** (36 files in 5 batches)
- Phase 4 – Tests & Tooling Hardening: **NOT STARTED**
- Phase 5 – Docs & Planning Alignment: **NOT STARTED**
- Phase 6 – Final Validation & Regression Sweep: **NOT STARTED**

**Policy Decisions Approved**:
- ✅ UI screen controllers: Add `ui_` prefix
- ✅ UI scenes: Migrate all 16 to `ui_` prefix
- ✅ Pause authority: M_PauseManager is sole authority
- ✅ Hazard/objective scenes: Add `prefab_` prefix

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

