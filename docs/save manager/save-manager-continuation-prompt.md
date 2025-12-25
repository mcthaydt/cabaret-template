# Save Manager Continuation Prompt

Use this prompt to resume Save Manager implementation in a new session.

---

## Context

You are implementing a Save Manager for a Godot 4.5 game using a Redux-style state architecture. The Save Manager orchestrates save/load timing, slot management, atomic disk IO, and migrations.

## Documentation

Read these files before starting work:

1. `docs/save manager/save-manager-overview.md` - Architecture and API
2. `docs/save manager/save-manager-prd.md` - Requirements and specs
3. `docs/save manager/save-manager-tasks.md` - Implementation tasks with checkboxes

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

## Current Progress

Check `save-manager-tasks.md` for current phase and completed tasks. Look for `- [x]` vs `- [ ]`.

## Implementation Patterns

Follow existing codebase patterns:

- **Managers**: See `m_scene_manager.gd` - ServiceLocator registration, group fallback
- **Helpers**: See `scripts/managers/helpers/` - extracted logic with `m_` prefix
- **Actions**: See `u_gameplay_actions.gd` - const action names, static creators, registry
- **ECS Systems**: See `s_checkpoint_system.gd` - extends BaseECSSystem
- **Overlays**: See `ui_pause_menu.gd` and `base_overlay.gd`
- **Events**: See `u_ecs_event_bus.gd` - `publish(event_name, payload)`

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
    "thumbnail_path": null
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

2. **Remove from M_StateStore**: `_autosave_timer`, `_setup_autosave_timer()`, `_on_autosave_timeout()`

3. **Scene registration required**: UI overlays need BOTH:
   - `resources/ui_screens/save_load_menu_overlay.tres`
   - Registration in `U_SceneRegistry` with `SceneType.UI`

4. **Autosave anti-triggers**: Never autosave during death, mid-transition, or high-frequency updates.

## Next Steps

1. Check `save-manager-tasks.md` for current phase
2. Find the first unchecked task `- [ ]`
3. Follow TDD: Red → Green → Refactor
4. Mark tasks complete as you finish them
5. Run manual tests from Phase 14 when feature-complete

---

## Quick Start Prompt

Copy this to start a new session:

```
I'm continuing implementation of the Save Manager.

Read the documentation at:
- docs/save manager/save-manager-overview.md
- docs/save manager/save-manager-tasks.md

Check which phase I'm on and continue with the next unchecked task. Follow TDD and mark tasks complete as you finish them.
```
