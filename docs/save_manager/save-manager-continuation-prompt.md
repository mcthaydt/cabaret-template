# Save Manager - Continuation Prompt

## Current Status (2026-01-31)

**Status:** Phase 16 In Progress - Screenshot/Thumbnail Capture
**Current Phase:** Phase 16C (Save Integration)
**Next Action:** Task 16C.1 - Write tests for save integration with thumbnails

## Prerequisites Completed

- ✅ **Phase 0**: Preparation & Existing Code Migration (5 tasks)
- ✅ **Phase 1**: Manager Lifecycle and Discovery (3 tasks)
- ✅ **Phase 2**: Slot Registry and Metadata (3 tasks + edge case tests)
- ✅ **Phase 3**: File I/O with Atomic Writes and Backups (3 tasks)
- ✅ **Phase 4**: Save Workflow - Manual Saves (4 tasks)
- ✅ **Phase 5**: Load Workflow with M_SceneManager Integration (3 tasks)
- ✅ **Phase 6**: Autosave Scheduler and Coalescing (3 tasks)
- ✅ **Phase 7**: Migration System (5 tasks)
- ✅ **Phase 8**: Error Handling and Corruption Recovery (3 tasks)
- ✅ **Phase 9**: UI - Pause Menu Integration (6 tasks)
- ✅ **Phase 10**: UI - Save/Load Overlay Screen (7 tasks)
- ✅ **Phase 11**: UI - Toast Notifications (3 tasks)
- ✅ **Phase 12**: Test Infrastructure Setup (2 tasks)
- ✅ **Phase 13**: Integration Tests for Full Save/Load Cycle (3 tasks)
- ✅ **Phase 14**: Automated Tests - Additional Coverage (30 tests)
- ✅ **Phase 15**: Manual Testing / QA Checklist (20 tests)

## Current State

**Core Files:**
- `M_SaveManager`: Save/load orchestration, slot management (ServiceLocator)
- `U_SaveFileIO`: Atomic writes with `.tmp` → `.bak` → `.json` pattern
- `U_AutosaveScheduler`: Event-driven coalescing scheduler
- `U_SaveMigrationEngine`: Version migration and legacy import
- `S_PlaytimeSystem`: ECS system tracking playtime (increments every second)
- UI overlays: `ui_pause_menu.gd`, `ui_save_load_menu.gd`, `ui_save_toast.gd`

**Tests:**
- Added `tests/unit/save/test_screenshot_cache.gd` (8 tests passing)
- Last run: `tools/run_gut_suite.sh -gtest=res://tests/unit/save/test_screenshot_cache.gd -gexit` (8/8 passed)

**Save Format:**
```json
{
  "header": {
    "save_version": 1,
    "timestamp": "2025-12-25T10:30:00Z",
    "build_id": "1.0.0",
    "playtime_seconds": 3600,
    "current_scene_id": "gameplay_base",
    "last_checkpoint": "sp_checkpoint_1",
    "target_spawn_point": "sp_checkpoint_1",
    "area_name": "Main Hall",
    "thumbnail_path": "user://saves/slot_01_thumb.png"
  },
  "state": { ... }
}
```

## Architecture Goal

Redux-style state architecture with save/load orchestration:

1. **Phases 0-3:** Core manager lifecycle, slot registry, atomic file I/O
2. **Phases 4-5:** Save/load workflows with StateHandoff pattern
3. **Phases 6-8:** Autosave scheduler, migrations, error recovery
4. **Phases 9-11:** UI integration (pause menu, overlay, toasts)
5. **Phases 12-15:** Test infrastructure and comprehensive testing
6. **Phase 16:** Screenshot/thumbnail capture for save slots

## Phase 16 Summary (IN PROGRESS)

Phase 16 adds screenshot thumbnails (320x180 PNG) to save slots. Split into sub-phases:

**Phase 16A: Screenshot Capture Utility (3 tasks) - ✅ Complete**
- Added `u_screenshot_capture.gd` helper with thumbnail constants + Lanczos resize
- Added unit tests for capture/resize/save (viewport capture test pending in headless)

**Phase 16B: Screenshot Cache Manager (3 tasks) - ✅ Complete**
- Added `m_screenshot_cache.gd` manager with ServiceLocator registration
- Cache uses gameplay-only capture on `ACTION_OPEN_PAUSE`
- Added unit tests for cache lifecycle + pause event handling

**Phase 16C: Save Integration (3 tasks)**
- Add live capture to autosave path
- Add cache retrieval to manual save path
- Update `_build_metadata()` for thumbnail path

**Phase 16D: Cleanup (2 tasks)**
- Update `delete_slot()` to remove thumbnail files
- Add orphaned thumbnail cleanup on startup

**Phase 16E: UI Display (3 tasks)**
- Update slot item layout with TextureRect
- Implement async thumbnail loading
- Create placeholder texture for missing thumbnails

**Phase 16F: Manual Testing (2 tasks)**
- Visual verification + mobile-specific testing

**Key Design Decisions:**
- **Autosave**: Capture live viewport at save time (gameplay is active)
- **Manual save**: Use cached screenshot from BEFORE pause menu opened (game is paused when user saves)
- **File format**: PNG, 320x180 (16:9), ~50-100KB per file
- **File path**: `user://saves/{slot_id}_thumb.png` alongside JSON
- **Mobile**: Resize captured Image immediately to reduce footprint (4K capture = ~32MB before resize)

## Critical Implementation Notes

1. **Do NOT use `M_StateStore.save_state(filepath)`** - Save Manager builds its own format using `get_state()` + header metadata

2. **Screenshot capture strategies differ**:
   - Autosave: Capture live viewport (gameplay active)
   - Manual save: Use cached screenshot from before pause (game paused)

3. **Autosave anti-triggers**: Never autosave during death, mid-transition, or high-frequency updates

4. **Follow existing patterns**:
   - Managers: ServiceLocator registration (see `m_scene_manager.gd`)
   - Helpers: Extracted logic in `scripts/managers/helpers/` (prefix `u_`)
   - ECS Systems: Extend BaseECSSystem (see `s_checkpoint_system.gd`)
   - Overlays: Extend BaseOverlay (see `ui_pause_menu.gd`)

## Reference Documents

- **Tasks:** `docs/save_manager/save-manager-tasks.md` (detailed checklist)
- **Overview:** `docs/save_manager/save-manager-overview.md` (architecture and API)
- **PRD:** `docs/save_manager/save-manager-prd.md` (requirements and specs)
- **Patterns:** `AGENTS.md` (ECS, state, testing patterns)

## After Each Task

1. Update task checkboxes in `save-manager-tasks.md`
2. Run tests to verify no regressions
3. Update this file with progress notes if completing a phase
4. Commit with descriptive message following TDD workflow
