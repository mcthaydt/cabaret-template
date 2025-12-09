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

## Current Status (2025-12-09 – Phase 5B & 10B Added)

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
- **Phase 5B – Audit Findings: **🔄 IN PROGRESS** (Added 2025-12-09)
  - 8 quick-fix tasks from codebase audit (T057-T059e)
  - **T057**: Rename `event_vfx_system.gd` → `base_event_vfx_system.gd`
  - **T058**: Add `class_name E_EndgameGoalZone`
  - **T059**: Delete orphaned `tmp_invalid_gameplay.tscn`
  - **T059a-e**: Documentation updates (DEV_PITFALLS, STYLE_GUIDE, AGENTS.md, T022 checkbox)
- Phase 6 – ECS Entity IDs & Tagging: **NOT STARTED** (Planning complete, ready for implementation)
  - **T060**: Design complete ✅ (2025-12-08)
    - Plan file: `/Users/mcthaydt/.claude/plans/zesty-sleeping-alpaca.md`
    - Design decisions approved:
      - ID Assignment: Auto-generated from node name (E_Player → "player"), manual override via export
      - ID Scope: Required for all entities (supports systemic/emergent gameplay)
      - State Store Integration: Loosely coupled (manual sync)
      - Tagging: Multiple freeform tags (Array[StringName])
    - Architecture: Uses existing U_ECSEventBus for entity registration events
    - Patterns audited: Follows BaseECSComponent const preload, BaseTest autofree, async spawn helpers
  - **T061-T064**: Detailed implementation steps in `style-scene-cleanup-tasks.md`
    - 23 sub-tasks for core ID support (base_ecs_entity.gd, m_ecs_manager.gd, u_ecs_utils.gd)
    - 8 sub-tasks for state store integration (u_entity_actions.gd, u_entity_selectors.gd)
    - 10 sub-tasks for tests + documentation
    - **12 sub-tasks** for migrating ALL existing entities:
      - 2 templates (player_template, camera_template)
      - 5 prefabs (checkpoint, death_zone, spike_trap, goal_zone, door_trigger)
      - 2 gameplay scene instances (E_FinalGoal, E_TutorialSign)
      - 2 verification steps
      - 1 documentation update
- Phase 7 – ECS Event Bus Migration: **NOT STARTED**
  - Migrate 7 components/systems from direct signals to U_ECSEventBus
  - **7A**: Health & death events (C_HealthComponent → event bus)
  - **7B**: Victory events (C_VictoryTriggerComponent → event bus)
  - **7C**: Damage zone events (C_DamageZoneComponent → event bus)
  - **7D**: Checkpoint events (refactor mixed pattern)
  - **7E**: Component registration events (BaseECSComponent)
  - **7F**: Cleanup & documentation
- Phase 8 – Spawn Registry & Spawn Conditions: **NOT STARTED**
- Phase 9 – Large File Splitting for Maintainability: **NOT STARTED**
  - Split 8 files over 400 lines into smaller helpers (~400 lines max)
  - **9A**: m_scene_manager.gd (1,565 → ~400) - 3 helpers
  - **9B**: ui_input_rebinding_overlay.gd (1,254 → ~400) - 3 helpers
  - **9C**: m_state_store.gd (809 → ~400) - 2 helpers
  - **9D**: u_input_rebind_utils.gd (509 → ~180) - 2 utilities
  - **9E**: Minor splits for 4 files (500-451 lines each)
  - **9F**: Validation & documentation
- Phase 10 – Multi-Slot Save Manager: **NOT STARTED**
- **Phase 10B – Architectural Hardening: **NOT STARTED** (Added 2025-12-09)
  - 9 sub-phases, 42 tasks total (T104-T117c)
  - **10B-1**: Manager coupling reduction (decouple systems from M_SceneManager)
  - **10B-2**: Extract Transition subsystem from M_SceneManager
  - **10B-3**: Scene type handler pattern (plugin-based scene types)
  - **10B-4**: Input device abstraction (IInputSource interface)
  - **10B-5**: State persistence extraction
  - **10B-6**: Unified event bus enhancement (typed events)
  - **10B-7**: Service locator pattern (replace 33 group lookups)
  - **10B-8**: Testing infrastructure (interfaces + mocks)
  - **10B-9**: Documentation & contracts (ADRs, dependency graphs)
  - **Dependencies**: Requires Phase 7 complete; overlaps with Phase 9
- Phase 11 – Final Validation & Regression Sweep: **NOT STARTED** (Tasks renumbered T120-T124)

**Policy Decisions Approved**:
- ✅ UI screen controllers: Add `ui_` prefix
- ✅ UI scenes: Migrate all 16 to `ui_` prefix
- ✅ Pause authority: M_PauseManager is sole authority
- ✅ Hazard/objective scenes: Add `prefab_` prefix
- ✅ Style enforcement: Comprehensive automated testing in place

---

## How to Continue

**Current Phase: Phase 5B – Audit Findings (Quick Fixes)**

1. **Read the Tasks**
   - Tasks file: `docs/general/cleanup/style-scene-cleanup-tasks.md` (Phase 5B section)
   - 8 quick-fix tasks from codebase audit (T057-T059e)

2. **Implementation Order**:
   - **T057**: Rename `event_vfx_system.gd` → `base_event_vfx_system.gd`
     - Update all references in imports/preloads
   - **T058**: Add `class_name E_EndgameGoalZone` to endgame_goal_zone.gd
   - **T059**: Delete orphaned `tmp_invalid_gameplay.tscn`
   - **T059a**: Update DEV_PITFALLS.md with class_name policy
   - **T059b**: Update STYLE_GUIDE.md with class_name examples
   - **T059c**: Update AGENTS.md with class_name requirement
   - **T059d**: Mark T022 checkbox in tasks file
   - **T059e**: Update continuation prompt when Phase 5B complete

3. **Testing Strategy**:
   - Run full test suite after T057 to catch any broken imports
   - Verify scenes load correctly after T058
   - Git grep to find any references to tmp_invalid_gameplay.tscn before T059

4. **Keep changes scoped**:
   - Each task is independent and can be done separately
   - Commit after each logical group (e.g., T057, then T058-059, then T059a-e docs)

**Next Phase After 5B**: Phase 6 – ECS Entity IDs & Tagging (Planning complete, see below for details)

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
