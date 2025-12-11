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

## Current Status (2025-12-10 – Phase 10 Detailed Plan Ready)

- **PRD**: `docs/general/cleanup/style-scene-cleanup-prd.md` – Drafted.
- **Plan**: `docs/general/cleanup/style-scene-cleanup-plan.md` – Phases 0–11 defined with user-approved policies.
- **Tasks**: `docs/general/cleanup/style-scene-cleanup-tasks.md` – Phase 10 expanded (2025-12-10), task numbers renumbered.

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
- Phase 9 – Large File Splitting for Maintainability: **✅ COMPLETE**
  - **9A (Scene Manager helpers)**: ✅ COMPLETE (2025-12-10)
  - **9B (Input Rebinding Overlay)**: ✅ COMPLETE (2025-12-10)
  - **9C (State Store split)**: ✅ COMPLETE (2025-12-11)
  - **9D (Input Rebind Utils split)**: ✅ COMPLETE (2025-12-11)
  - **9E (Minor Splits)**: ✅ COMPLETE (T094-T097)
  - **9F (Validation)**: Pending (T098-T099)
- **Phase 10 – Multi-Slot Save Manager**: **NOT STARTED** (Detailed plan ready - T100-T122)
- **Phase 10B – Architectural Hardening**: **NOT STARTED** (Tasks renumbered T130-T143)
- Phase 11 – Final Validation & Regression Sweep: **NOT STARTED** (Tasks renumbered T150-T154)

**Policy Decisions Approved**:
- ✅ UI screen controllers: Add `ui_` prefix
- ✅ UI scenes: Migrate all 16 to `ui_` prefix
- ✅ Pause authority: M_PauseManager is sole authority
- ✅ Hazard/objective scenes: Add `prefab_` prefix
- ✅ Style enforcement: Comprehensive automated testing in place

---

## How to Continue

**Current Phase: Phase 10 – Multi-Slot Save Manager (Design & Implementation)**

Phase 10 has been expanded into 8 sub-phases with 23 detailed tasks (T100-T122):

### Phase 10 Configuration (User Approved)
- **3 manual save slots** + **1 dedicated auto-save slot** (4 total)
- **Access points**: Main menu + Pause menu (full slot selection from both)
- **Metadata preview**: Rich (scene name, timestamp, play time, health, deaths, completion %)

### Implementation Order
1. **Phase 10.0 (T100-T101)**: Data model - Create `RS_SaveSlotMetadata`, define envelope format
2. **Phase 10.1 (T102-T106)**: M_SaveManager core - slot enumeration, save/load/delete operations
3. **Phase 10.2 (T107-T109)**: Redux integration - actions, reducer updates, selectors
4. **Phase 10.3 (T110)**: Auto-save integration with existing 60s timer
5. **Phase 10.4 (T111-T114)**: UI implementation - save slot selector overlay
6. **Phase 10.5 (T115-T116)**: Menu integration - main menu + pause menu buttons
7. **Phase 10.6 (T117)**: Settings resource for configuration
8. **Phase 10.7 (T118-T121)**: Testing - unit + integration tests
9. **Phase 10.8 (T122)**: Documentation updates

### Key Files to Create
- `scripts/managers/m_save_manager.gd` - Core save manager
- `scripts/state/resources/rs_save_slot_metadata.gd` - Slot metadata model
- `scripts/state/actions/u_save_actions.gd` - Redux actions
- `scripts/ui/ui_save_slot_selector.gd` - Overlay controller
- `scenes/ui/ui_save_slot_selector.tscn` - Overlay scene

### Key Files to Modify
- `scripts/state/m_state_store.gd` - Route auto-save to M_SaveManager
- `scripts/state/reducers/u_menu_reducer.gd` - Handle save slot actions
- `scripts/ui/ui_main_menu.gd` - Add Continue/Load Game buttons
- `scripts/ui/ui_pause_menu.gd` - Add Save/Load Game buttons

### Patterns to Follow
- UI overlays: Extend `BaseOverlay`, register in `U_UIRegistry`
- List selection: Follow `ui_input_profile_selector.gd` pattern
- Navigation: Use `U_NavigationActions` - never call Scene Manager directly

**Note**: Phase 10B (T130-T143) and Phase 11 (T150-T154) have been renumbered to avoid conflicts.

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
