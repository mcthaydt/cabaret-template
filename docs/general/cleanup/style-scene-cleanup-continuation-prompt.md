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
- **Phase 5B – Audit Findings: **✅ COMPLETE** (2025-12-09)
  - **T057**: Renamed `event_vfx_system.gd` → `base_event_vfx_system.gd` ✅
    - File now matches `class_name BaseEventVFXSystem`
    - Updated test references and style enforcement rules
  - **T058**: Added `class_name E_EndgameGoalZone` ✅
  - **T059**: SKIPPED - `tmp_invalid_gameplay.tscn` actively used in tests
  - **T059a**: Updated DEV_PITFALLS.md (removed "future Phase 5" refs) ✅
  - **T059b**: Added historical note to STYLE_GUIDE.md Phase 1-10 checklist ✅
  - **T059c**: Updated AGENTS.md ("Phase 5 Complete", removed `so_*` prefix) ✅
  - **T059d**: Clarified M_GameplayInitializer is optional in SCENE_ORGANIZATION_GUIDE.md ✅
  - **T059e**: Verified T022 checkbox (already correct) ✅
  - **Tests**: All passing (64 ECS, 7 style, 90 scene manager) ✅
  - **Commits**: 6 commits (3 implementation, 3 documentation)
- Phase 6 – ECS Entity IDs & Tagging: **✅ COMPLETE** (T060-T064v)
  - **T060**: Design complete ✅ (2025-12-08)
    - Plan file: `/Users/mcthaydt/.claude/plans/zesty-sleeping-alpaca.md`
    - Design decisions approved:
      - ID Assignment: Auto-generated from node name (E_Player → "player"), manual override via export
      - ID Scope: Required for all entities (supports systemic/emergent gameplay)
      - State Store Integration: Loosely coupled (manual sync)
      - Tagging: Multiple freeform tags (Array[StringName])
    - Architecture: Uses existing U_ECSEventBus for entity registration events
    - Patterns audited: Follows BaseECSComponent const preload, BaseTest autofree, async spawn helpers
  - **T061**: Core ID support ✅ COMPLETE (2025-12-09)
    - base_ecs_entity.gd: entity_id, tags exports, get_entity_id(), tag methods
    - m_ecs_manager.gd: entity registration, tag indexing, query methods
    - u_ecs_utils.gd: get_entity_id(), get_entity_tags(), build_entity_snapshot()
    - u_entity_query.gd: get_entity_id(), get_tags(), has_tag()
  - **T062**: State Store integration ✅ COMPLETE (2025-12-09)
    - u_entity_actions.gd: StringName support for entity_id parameters
    - u_entity_selectors.gd: StringName support for entity_id parameters
    - u_ecs_utils.gd: build_entity_snapshot() includes entity_id and tags
  - **T063**: Tests ✅ COMPLETE (2025-12-09)
    - 27 new tests in test_entity_ids.gd
    - All 91 ECS unit tests passing
    - Documentation updated (ecs_architecture.md, AGENTS.md)
  - **T064a-i**: Entity migration ✅ COMPLETE (2025-12-09)
    - Templates: tmpl_character.tscn (generic), tmpl_camera.tscn
    - Prefabs: 5 prefabs (checkpoint, death_zone, spike_trap, goal_zone, door_trigger)
    - Gameplay scenes: gameplay_exterior.tscn, gameplay_interior_house.tscn
    - All entities have unique IDs and appropriate tags
    - All 181 tests passing (91 ECS + 90 Scene Manager)
    - Commits: 6be2509 (implementation), 89fbfc1 (documentation)
  - **T064j-k**: Verification ✅ COMPLETE (2025-12-09)
    - Automated coverage via `tests/unit/ecs/test_entity_scene_registration.gd` (entities + tags in templates and gameplay scenes)
    - ECS unit suite passing (includes new test)
  - **T064l**: Documentation ✅ COMPLETE (2025-12-09)
    - Added entity ID/tag inventory and tagging strategy table to docs/ecs/ecs_architecture.md
  - **T064m-v**: Template/prefab refactor ✅ COMPLETE (2025-12-09)
    - Split player template into `tmpl_character.tscn` (generic) + `prefab_player.tscn`
    - Converted ragdoll to `tmpl_character_ragdoll.tscn` + `prefab_player_ragdoll.tscn`
    - Updated gameplay/base scenes to use player prefab
    - Updated docs (AGENTS, SCENE_ORGANIZATION_GUIDE) with Templates vs Prefabs section
    - Tests: style enforcement, ECS unit suite, scene manager integration suite all passing
- Phase 7 – ECS Event Bus Migration: **IN PROGRESS**
  - **7A COMPLETE (2025-12-09)**: C_HealthComponent now publishes `health_changed`/`entity_death` via U_ECSEventBus; S_GamepadVibrationSystem listens for death events; added health event tests; ECS unit suite passing.
  - **7B COMPLETE (2025-12-09)**: C_VictoryTriggerComponent publishes `victory_zone_entered`/`victory_triggered`; S_VictorySystem subscribes to victory events; added unit coverage for component + system; ECS unit suite passing.
  - Remaining: 7C damage zone events, 7D checkpoint events, 7E registration events, 7F cleanup/docs.
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

**Current Phase: Phase 7 – ECS Event Bus Migration (continuing with 7C next)**

Phase 6 is complete through T064v; optional T064t manual gameplay check remains if desired.

1. **Next phase options**:
   - Phase 7 (ECS Event Bus Migration)
   - Phase 8 (Spawn Registry & Spawn Conditions)
   - Phase 9 (Large File Splitting)

2. **Optional**:
   - T064t manual gameplay verification (player spawn/input/death ragdoll) if we want a manual sanity sweep post-refactor.

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
