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

## Current Status (2025-12-11 – Phase 9E Complete, Phase 9F Next)

- **PRD**: `docs/general/cleanup/style-scene-cleanup-prd.md` – Drafted.
- **Plan**: `docs/general/cleanup/style-scene-cleanup-plan.md` – Phases 0–11 defined with user-approved policies.
- **Tasks**: `docs/general/cleanup/style-scene-cleanup-tasks.md` – Phase 0-5 complete, Phase 5B & 10B added (2025-12-09 audit).

**Execution Status**:

- Phase 0 – Discovery & Inventory: **✅ COMPLETE** (Commit: 032bb7d - documentation updates)
- Phase 1 – Spec & Guide Updates: **✅ COMPLETE** (Commit: 032bb7d)
- Phase 2 – Responsibility Consolidation (Pause/Cursor): **✅ COMPLETE**
- Phase 3 – Naming & Prefix Migration: **✅ COMPLETE**
- Phase 4 – Tests & Tooling Hardening: **✅ COMPLETE** (2025-12-08)
- Phase 5 – Docs & Planning Alignment: **✅ COMPLETE** (2025-12-08, Commits: 30dd4d6, 8b1ae15, 011c4fa)
- **Phase 5B – Audit Findings: **✅ COMPLETE** (2025-12-09)
- Phase 6 – ECS Entity IDs & Tagging: **✅ COMPLETE** (T060-T064v)
- Phase 7 – ECS Event Bus Migration: **COMPLETE (2025-12-09)**
- Phase 8 – Spawn Registry & Spawn Conditions: **IN PROGRESS** (T080-T083 complete - registry + integration)
- Phase 9 – Large File Splitting for Maintainability: **IN PROGRESS**
  - **9A (Scene Manager helpers)**: ✅ IMPLEMENTED (2025-12-10)
  - **9B (Input Rebinding Overlay)**: ✅ COMPLETE (2025-12-10)
  - **9C (State Store split)**: ✅ COMPLETE (2025-12-11)
  - **9D (Input Rebind Utils split)**: ✅ COMPLETE (2025-12-11)
  - **9E (Minor Splits)**: ✅ COMPLETE (T094-T097 – helpers + refactors; ECS query metrics, input profile loader, scene registry loader, touchscreen preview builder)
- Phase 10 – Multi-Slot Save Manager: **NOT STARTED**
- **Phase 10B – Architectural Hardening: **NOT STARTED** (Added 2025-12-09)
- Phase 11 – Final Validation & Regression Sweep: **NOT STARTED** (Tasks renumbered T120-T124)

**Policy Decisions Approved**:
- ✅ UI screen controllers: Add `ui_` prefix
- ✅ UI scenes: Migrate all 16 to `ui_` prefix
- ✅ Pause authority: M_PauseManager is sole authority
- ✅ Hazard/objective scenes: Add `prefab_` prefix
- ✅ Style enforcement: Comprehensive automated testing in place

---

## How to Continue

**Current Phase: Phase 9 – Large File Splitting for Maintainability (9E – Minor Splits)**

Focus on Phase 9E tasks (T094–T097), then proceed to Phase 9F validation/documentation before moving on to Phase 10/10B.

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
