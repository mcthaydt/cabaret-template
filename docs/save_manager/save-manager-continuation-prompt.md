# Save Manager Continuation Prompt

Use this prompt to resume Save Manager implementation in a new session.

---

## Context

You are implementing a Save Manager for a Godot 4.5 game using a Redux-style state architecture. The Save Manager orchestrates save/load timing, slot management, atomic disk IO, and migrations.

## Documentation

Read these files before starting work:

1. `docs/save_manager/save-manager-overview.md` - Architecture and API
2. `docs/save_manager/save-manager-prd.md` - Requirements and specs
3. `docs/save_manager/save-manager-tasks.md` - Implementation tasks with checkboxes

## Key Decisions

| Decision | Choice |
|----------|--------|
| Slot model | 1 autosave + 3 manual slots |
| File paths | Flat at `user://saves/` (e.g., `autosave.json`, `slot_01.json`) |
| File format | `{ "header": {...}, "state": {...} }` - Save Manager owns this format |
| Atomic writes | Write `.tmp` → rename `.json` to `.bak` → rename `.tmp` to `.json` |
| Threading | Synchronous only (no async) |
| Playtime tracking | Dedicated `S_PlaytimeSystem` increments every second |
| UI | Combined `ui_save_load_menu.tscn` with mode switching (save/load) |
| Toasts | Suppress while paused; inline UI feedback for manual saves |
| Test directory | `user://test/` for integration tests |
| Autosave events | `checkpoint_activated` (ECS), `scene/transition_completed` (Redux) |
| Load sequence | StateHandoff pattern (existing pattern in codebase) |
| Death prevention | `death_in_progress` flag in gameplay slice blocks autosave |
| Autosave deletable | No; delete button hidden for autosave slot |
| Overlay mode | `save_load_mode` field in navigation slice |
| Overwrite confirm | Always confirm before saving to occupied slot |
| Legacy migration | Import `user://savegame.json` to autosave on first launch |
| Concurrent protection | `_is_saving` and `_is_loading` lock flags |
| Settings autosave | Removed; only checkpoint/area events trigger saves |
| Thumbnail format | PNG, 320x180 (16:9), ~50-100KB per file |
| Thumbnail path | `user://saves/{slot_id}_thumb.png` alongside JSON |
| Thumbnail capture | Autosave=live viewport, Manual save=cached from before pause |
| Screenshot cache | Single Image in memory, captured on ACTION_OPEN_PAUSE |

## Current Progress

**Last Updated**: 2026-01-30

**Completed Phases**:
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

**Test Status**:
- 99 unit tests passing (save manager, file I/O, migrations, autosave scheduler, playtime)
- 19 integration tests passing
- 339 total assertions

**Next Phase**: Phase 16 - Screenshot/Thumbnail Capture for Save Slots

Check `save-manager-tasks.md` for detailed task list and current phase. Look for `- [x]` vs `- [ ]`.

## Implementation Patterns

Follow existing codebase patterns:

- **Managers**: See `m_scene_manager.gd` - ServiceLocator registration, group fallback
- **Helpers**: See `scripts/managers/helpers/` - extracted logic (u_save_file_io.gd, u_autosave_scheduler.gd, u_save_migration_engine.gd)
- **Actions**: See `u_gameplay_actions.gd` - const action names, static creators, registry
- **ECS Systems**: See `s_checkpoint_system.gd` - extends BaseECSSystem
- **Overlays**: See `ui_pause_menu.gd` and `base_overlay.gd`
- **Events**: See `u_ecs_event_bus.gd` - `publish(event_name, payload)`
  - Emits save_started, save_completed, save_failed events

## File Format

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
  "state": {
    "gameplay": { ... },
    "settings": { ... },
    ...
  }
}
```

## Critical Notes

1. **Do NOT use `M_StateStore.save_state(filepath)`** - that writes raw state without header. Save Manager builds its own format using `get_state()` + header metadata.

2. **Autosave anti-triggers**: Never autosave during death, mid-transition, or high-frequency updates.

3. **Screenshot capture requires two strategies**:
   - **Autosave**: Capture live viewport at save time (gameplay is active)
   - **Manual save**: Use cached screenshot from BEFORE pause menu opened (game is paused when user saves)

4. **Thumbnail file management**: Screenshots stored as `{slot_id}_thumb.png` alongside JSON saves. Clean up on slot deletion.

## Next Steps (Phase 16)

Phase 16 is split into sub-phases:

**Phase 16A: Screenshot Cache Infrastructure**
1. Create `u_screenshot_capture.gd` helper for viewport capture and resize
2. Create `m_screenshot_cache.gd` manager to cache screenshot on pause
3. Subscribe to `ACTION_OPEN_PAUSE` to capture before menu shows

**Phase 16B: Save Integration**
4. Add live capture to autosave path
5. Add cache retrieval to manual save path
6. Update `_build_metadata()` for thumbnail path

**Phase 16C: Cleanup**
7. Update `delete_slot()` to remove thumbnail files
8. Add orphaned thumbnail cleanup on startup

**Phase 16D: UI Display**
9. Update slot item layout with TextureRect
10. Implement async thumbnail loading
11. Create placeholder texture for missing thumbnails

**Phase 16E: Testing**
12. Unit tests for capture utility and cache manager
13. Integration tests for save/load with thumbnails
14. Mobile-specific testing (performance, touch controls visibility)

**Mobile Considerations:**
- Touch controls (CanvasLayer) appear in autosave screenshots - decision needed: accept or hide
- Memory: Resize captured Image immediately to reduce footprint (4K capture = ~32MB before resize)
- Performance: Capture/resize/encode may cause frame drop on low-end devices

Check `save-manager-tasks.md` for detailed task breakdown (18 tasks total).

---

## Quick Start Prompt

Copy this to start a new session:

```
I'm continuing implementation of the Save Manager - Phase 16: Screenshot/Thumbnail Capture.

Read the documentation at:
- docs/save_manager/save-manager-overview.md
- docs/save_manager/save-manager-tasks.md

The core save system (Phases 0-15) is complete with 118 tests passing.

Phase 16 adds screenshot thumbnails to save slots and is split into sub-phases:
- 16A: Screenshot cache infrastructure (capture on pause for manual saves)
- 16B: Save integration (autosave captures live, manual saves use cache)
- 16C: Cleanup (delete thumbnails with saves, orphan cleanup)
- 16D: UI display (async loading, placeholder for missing)
- 16E: Testing

IMPORTANT: Manual saves cannot capture at save time (game is paused, showing menu). A screenshot cache must capture BEFORE pause menu opens.

Continue with the next unchecked task. Follow TDD and mark tasks complete as you finish them.
```
