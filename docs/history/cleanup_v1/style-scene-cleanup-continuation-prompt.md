# Style & Scene Cleanup – Continuation Guide

## 🚨 CRITICAL WORKFLOW REQUIREMENT 🚨

Before doing ANY work on style/scene cleanup:

1. **Open `docs/history/cleanup_v1/style-scene-cleanup-tasks.md` FIRST.**
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

## Current Status (2025-12-17 – Phase 10B Complete)

- **PRD**: `docs/history/cleanup_v1/style-scene-cleanup-prd.md` – Drafted.
- **Plan**: `docs/history/cleanup_v1/style-scene-cleanup-plan.md` – Phases 0–11 defined with user-approved policies.
- **Tasks**: `docs/history/cleanup_v1/style-scene-cleanup-tasks.md` – Phase 10 expanded (2025-12-10), task numbers renumbered.

**Execution Status**:

- Phase 0 – Discovery & Inventory: **✅ COMPLETE** (Commit: 032bb7d - documentation updates)
- Phase 1 – Spec & Guide Updates: **✅ COMPLETE** (Commit: 032bb7d)
- Phase 2 – Responsibility Consolidation (Pause/Cursor): **✅ COMPLETE**
- Phase 3 – Naming & Prefix Migration: **✅ COMPLETE**
- Phase 4 – Tests & Tooling Hardening: **✅ COMPLETE** (2025-12-08)
- Phase 5 – Docs & Planning Alignment: **✅ COMPLETE** (2025-12-08, Commits: 30dd4d6, 8b1ae15, 011c4fa)
- **Phase 5B – Audit Findings**: **✅ COMPLETE** (2025-12-09)
- Phase 6 – ECS Entity IDs & Tagging: **✅ COMPLETE** (T060-T064v)
- Phase 7 – ECS Event Bus Migration: **✅ COMPLETE** (2025-12-09)
- Phase 8 – Spawn Registry & Spawn Conditions: **✅ COMPLETE** (T080-T087)
- Phase 9 – Large File Splitting for Maintainability: **✅ COMPLETE** (Commit: e271cac)
  - **9A (Scene Manager helpers)**: ✅ COMPLETE (2025-12-10)
  - **9B (Input Rebinding Overlay)**: ✅ COMPLETE (2025-12-10)
  - **9C (State Store split)**: ✅ COMPLETE (2025-12-11)
  - **9D (Input Rebind Utils split)**: ✅ COMPLETE (2025-12-11)
  - **9E (Minor Splits)**: ✅ COMPLETE (T094-T097)
  - **9F (Validation)**: ✅ COMPLETE (T098-T099)
- **Phase 10 – Multi-Slot Save Manager**: **⏸️ DEFERRED** (Will be handled as separate PRD)
- **Phase 10B – Architectural Hardening**: **✅ COMPLETE** (T130-T143)
  - Phase 10B-9 deliverables (T143a-T143c) completed:
    - `docs/architecture/ecs_state_contract.md`
    - `docs/architecture/dependency_graph.md` (includes mermaid)
    - `docs/architecture/adr/0002-redux-state-management.md` .. `0005-service-locator.md`
- Phase 11 – Final Validation & Regression Sweep: **NOT STARTED** (Tasks renumbered T150-T154)

---

## How to Continue

**Current Phase: Phase 11 – Final Validation & Regression Sweep**

Phase 10B is complete. Phase 10 (Multi-Slot Save Manager) remains deferred to a separate PRD.

**Next Steps**:
1. Start Phase 11 tasks (T150-T154) in `docs/history/cleanup_v1/style-scene-cleanup-tasks.md`
2. Run full GUT test suites and record baseline
3. Manually verify core user flows (menu → gameplay → transitions → overlays)

**Note**: Phase 10 (Multi-Slot Save Manager) is deferred and will be handled as a separate PRD later.

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

## Related Documents **MUST READ**

- `docs/guides/STYLE_GUIDE.md`
- `docs/guides/SCENE_ORGANIZATION_GUIDE.md`
- `docs/guides/DEV_PITFALLS.md`
- `AGENTS.md`

- `docs/ecs/ecs_architecture.md`
- `docs/state_store/redux-state-store-prd.md`
- `docs/scene_manager/scene-manager-prd.md`
- `docs/input_manager/input-manager-prd.md`
- `docs/ui_manager/ui-manager-prd.md`

- `docs/history/cleanup_v1/phase-10b-implementation-plan.md` (Architectural Hardening detailed plan)

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
