# Save Manager PRD

## Overview

- **Feature name**: Save Manager
- **Owner**: TBD
- **Target release**: TBD
- **Status**: READY FOR IMPLEMENTATION

## Problem Statement

Players need reliable, crash-safe progress persistence in a Godot-based game with complex state management. The game uses a Redux-style state store (M_StateStore) as the single source of truth, and requires:

1. **Automatic progress preservation** without player intervention (autosave)
2. **User-controlled save points** for intentional progress snapshots (manual saves)
3. **Mid-session recovery** via loading from the pause overlay without restarting the game
4. **Data integrity** across crashes, version updates, and state migrations

**Why now?** The core gameplay systems (state store, scene management) are established, and the game requires persistent progress to be playable. Without coordinated save/load orchestration, players risk losing progress, experiencing corruption, or having inconsistent state after loads.

## Goals

- **Reliable persistence**: Crash-safe, atomic writes prevent partial saves and data corruption
- **Dual save workflows**: Support one autosave slot (automatic, coalesced) + 3 manual save slots (user-controlled)
- **Load from pause**: Allow players to load saves from the pause overlay with safe state + scene restoration
- **Centralized orchestration**: Keep save/load timing, slot management, and versioning in one testable layer
- **Migration support**: Handle save version changes with pure, deterministic Dictionary transforms
- **Intelligent autosave**: Trigger saves on meaningful milestones (checkpoints, area completion, settings changes) while avoiding high-frequency/bad-state overwrites
- **Replace existing autosave**: Remove timer-based autosave from M_StateStore in favor of event-driven system

## Non-Goals

- **No second snapshot system**: The Redux-style M_StateStore remains the single source of truth; the Save Manager orchestrates when/how to serialize it, but doesn't define gameplay data
- **No high-frequency saving**: Avoid per-frame or per-tick autosaves to prevent disk thrash and "bad autosave" overwrites during death/combat
- **No direct scene graph serialization**: Entities and components restore via state + scene load flow, not by serializing the scene tree directly
- **No cloud sync**: Initial scope is local persistence only
- **No multi-profile management**: Single player profile for initial implementation
- **No async/threaded saves**: Synchronous blocking writes only (acceptable for expected save file sizes)

## User Experience

### Primary Entry Points

1. **Autosave (invisible to player)**:
   - Triggers automatically on milestones (checkpoints, area completion, scene transitions)
   - No UI interruption; subtle toast feedback ("Saving..." / "Game Saved") during gameplay
   - Coalesces multiple requests to avoid spam
   - Blocked during death states (`death_in_progress` flag)

2. **Manual Save (from pause menu)**:
   - Accessible via Save button in pause menu overlay
   - Opens save slot overlay showing available slots with metadata
   - **Overwrite confirmation** required before saving to occupied slot
   - Immediate write with inline UI feedback (no toasts while paused)
   - Player chooses slot; blocked if all slots full (must delete first)

3. **Load (from pause menu)**:
   - Accessible via Load button in pause menu overlay
   - Opens load slot overlay showing saves with metadata (timestamp, playtime, area, thumbnail placeholder)
   - Selecting a save shows **inline spinner**, disables all buttons
   - On success: seamless transition to loaded state + scene (using **StateHandoff** pattern)
   - On failure: inline error display, remains paused in current session

### UI Flow

```
Pause Menu
├── Resume
├── Settings → [existing settings overlay]
├── Save → Save/Load Overlay (save mode)
│   ├── Mode: SAVE (from navigation.save_load_mode)
│   ├── Slot List (autosave + slot_01-03)
│   │   └── Per slot: timestamp, area, playtime, [Save] [Delete*]
│   │   └── *Autosave slot: Delete button hidden (not deletable)
│   │   └── Occupied slot: [Save] shows overwrite confirmation
│   └── Back → Pause Menu
├── Load → Save/Load Overlay (load mode)
│   ├── Mode: LOAD (from navigation.save_load_mode)
│   ├── Slot List (autosave + slot_01-03)
│   │   └── Per slot: timestamp, area, playtime, thumbnail, [Load] [Delete*]
│   │   └── *Autosave slot: Delete button hidden (not deletable)
│   │   └── Loading: inline spinner, all buttons disabled
│   └── Back → Pause Menu
└── Quit
```

**Combined overlay rationale**: Single scene for all save management provides better UX - players can see existing saves before deciding to save or load, reducing accidental overwrites.

### Toast Notifications

Reuse checkpoint toast pattern (`ui_hud_controller.gd`):

| Event | Toast Text | Duration |
|-------|-----------|----------|
| Autosave started | "Saving..." | Until complete |
| Save completed | "Game Saved" | 1.5s |
| Save failed | "Save Failed" | 2s |
| Load failed | "Load Failed - Try Backup" | 2s |

**Important**: Toasts are suppressed while paused (consistent with checkpoint toasts). Manual saves from pause menu rely on inline UI feedback instead.

### Critical Interactions

**Autosave triggers**:

- **Priority milestones**: Checkpoint updates, area completion, major unlocks, scene transition completion
- **Anti-triggers**: High-frequency updates (position, timers, combat ticks), death states (`death_in_progress` flag), mid-transition states
- **Settings**: NOT autosave triggers (handled separately if needed)

**Load workflow** (using StateHandoff pattern):

1. Pause overlay requests load; UI shows inline spinner, disables buttons
2. Save Manager checks `_is_loading` lock, rejects if already loading
3. Save Manager rejects if scene transition in progress
4. Sets `_is_loading = true`, cancels pending autosaves, blocks new ones
5. Reads save file -> validates -> applies migrations (raw Dictionary, before state application)
6. Uses StateHandoff: stores loaded state for scene transition
7. Transitions via M_SceneManager to loaded scene
8. StateHandoff applies state after scene loads (normalization runs)
9. Scene transition closes pause overlay, `_is_loading = false`, re-enables autosaves
10. On failure: inline error in UI, keeps current session intact

## Technical Considerations

### Existing Code Migration

**Remove from `scripts/state/m_state_store.gd`**:

- `_autosave_timer: Timer` variable
- `_setup_autosave_timer()` function
- `_on_autosave_timeout()` function

**Keep in M_StateStore**:

- `get_state()` method (Save Manager reads current state)
- `dispatch()` method (Save Manager applies loaded state via actions)
- `state_loaded` signal (may be useful for downstream listeners)
- Existing `save_state()`/`load_state()` methods (kept for legacy; Save Manager uses its own IO)

### Dependencies

- **M_StateStore**: State access via `get_state()` and `dispatch()`; normalization via existing validators
- **M_SceneManager**: Handles scene transitions to restored `current_scene_id` and spawn point restoration
- **U_SceneRegistry**: Scene metadata and display names for area_name header field
- **ServiceLocator**: Primary discovery mechanism (with group fallback)
- **U_ECSEventBus**: For publishing save events (toast notifications subscribe)

**Note**: Save Manager writes its OWN file format (`{header, state}`) using `m_save_file_io.gd`. It does NOT call `M_StateStore.save_state(filepath)` directly because that method writes raw state without the header wrapper.

### Gameplay Slice Additions

**New gameplay slice fields**:

1. `playtime_seconds: int`
   - Add to `RS_GameplayInitialState` with default value `0`
   - Persist across scene transitions (NOT in transient_fields)
   - Read by Save Manager when building header metadata
   - Display formatted as HH:MM:SS in UI

2. `death_in_progress: bool`
   - Add to `RS_GameplayInitialState` with default value `false`
   - Set to `true` on death trigger, `false` on respawn/reset
   - Autosave scheduler checks this flag and blocks saves during death

**New system**: `S_PlaytimeSystem` (`scripts/ecs/systems/s_playtime_system.gd`)

- Extends `BaseECSSystem`, runs in `process_tick(delta)`
- Tracks elapsed time as float internally, dispatches whole seconds only
- Carries sub-second remainder to prevent precision loss
- Pauses when: navigation shell != "gameplay", game is paused, or transitioning
- Dispatches `U_GameplayActions.increment_playtime(seconds)` action

**New actions**: `U_GameplayActions`

- `increment_playtime(seconds: int)` - adds seconds to `playtime_seconds` field
- `set_death_in_progress(value: bool)` - sets `death_in_progress` flag

### File Format & Slot Model

**Slots**:

- `autosave`: Reserved slot ID, overwritten by autosave events
- `slot_01`, `slot_02`, `slot_03`: User-created manual save slots
- **Total**: 4 slots (1 autosave + 3 manual)

**File paths** (flat structure):

```
user://saves/autosave.json
user://saves/autosave.json.bak
user://saves/slot_01.json
user://saves/slot_01.json.bak
...
```

**File structure**:

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

**Header fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| save_version | int | Yes | Schema version for migrations |
| timestamp | String | Yes | ISO 8601 format |
| build_id | String | Yes | Game version |
| playtime_seconds | int | Yes | Total play time |
| current_scene_id | String | Yes | Scene at save time |
| last_checkpoint | String | No | Checkpoint marker |
| target_spawn_point | String | No | Spawn point marker |
| area_name | String | Yes | Human-readable location |
| thumbnail_path | String | No | Screenshot path (deferred) |

### Atomic Writes & Backup Strategy

1. Write to `.tmp` file first
2. Rename current `.json` to `.bak` (backup)
3. Rename `.tmp` to `.json` (atomic on most filesystems)
4. On load failure: attempt `.bak` before giving up

### Migration System

- Compare `save_version` in header to current game version
- Apply pure `Dictionary -> Dictionary` transforms for each version increment
- Migrations are deterministic, testable, and fail gracefully
- If migration fails, do not load; surface error to user

### Autosave Timing & Coalescing

**Configuration** (in `RS_SaveManagerSettings`):

| Setting | Default | Description |
|---------|---------|-------------|
| cooldown_duration | 5.0s | Minimum time between routine autosaves |
| enable_autosave | true | Global autosave toggle |

**Priority levels**:

| Priority | Behavior | Use Case |
|----------|----------|----------|
| NORMAL | Respects cooldown | Routine saves |
| HIGH | Override if >2s since last | Checkpoint, area complete |
| CRITICAL | Always override | Critical state changes |

**Locking**: Save Manager maintains `_is_saving` and `_is_loading` flags to prevent concurrent operations.

### Risks / Mitigations

| Risk | Mitigation |
|------|------------|
| Partial/corrupted saves | Atomic writes via `.tmp` + rename; `.bak` fallback |
| Bad autosave (death/unstable) | `death_in_progress` flag blocks autosave; priority/cooldown logic |
| Load during scene transition | Reject load if transition in progress; `_is_loading` lock |
| Concurrent save/load requests | `_is_saving` and `_is_loading` flags + disabled UI buttons |
| Migration failures | Pure transforms with tests; graceful failure without mutating session |
| Disk full / write failure | Catch IO errors, surface to user via inline UI, preserve `.bak` |
| Legacy saves incompatible | v0 migration wraps headerless saves; import on first launch |
| Accidental overwrite | Confirmation dialog before saving to occupied slot |

## Success Metrics

- **Crash-safe writes**: No reported cases of corrupted or partial save files
- **Successful migrations**: All test cases for version migrations pass; no data loss during upgrades
- **Proper autosave coalescing**: Only one write per cooldown window; no disk thrash
- **Load from pause reliability**: 100% success rate for valid saves; graceful failure for corrupted saves
- **Milestone coverage**: All defined autosave triggers result in successful saves
- **No bad autosaves**: Zero reports of autosaves overwriting good progress with death/unstable states

## Configuration Details

### Slot Configuration

- **Manual slot cap**: 3 slots (`slot_01`, `slot_02`, `slot_03`)
- **Overflow behavior**: Block new saves when full (user must delete a slot)
- **Total slots**: 4 (1 autosave + 3 manual)

### Save Accessibility

- **Manual save access**: Pause menu only (Save button -> overlay)
- **Load access**: Pause menu only (Load button -> overlay)
- **Autosave access**: Automatic, invisible to player

### Post-Load Behavior

- **Autosave after load**: No
- **Wait for next milestone**: Yes (checkpoint update, area complete, etc.)
- **Rationale**: Prevents accidentally overwriting the loaded save immediately

### UI Metadata Display

Load screen shows for each save slot:

- **Timestamp**: Formatted date/time (e.g., "Dec 25, 2025 10:30 AM")
- **Area name**: Human-readable location (e.g., "Main Hall")
- **Playtime**: Formatted as HH:MM:SS (e.g., "01:30:45")
- **Thumbnail**: Placeholder greyed box (capture deferred)

### Testing Configuration

- **Test directory**: `user://test/` (isolated from production `user://saves/`)
- **Cleanup**: Delete test files in teardown
- **Pattern**: Real filesystem operations, not mocked

## Resolved Decisions

| Question | Decision |
|----------|----------|
| Load sequence | Use existing StateHandoff pattern (state stored before transition, applied after scene loads) |
| Death autosave prevention | Explicit `death_in_progress` flag in gameplay slice blocks autosave |
| Autosave slot deletable | No; delete button hidden/disabled for autosave slot |
| Toasts during pause | Suppress all toasts while paused; rely on inline UI feedback for manual saves |
| Overlay mode passing | Add `save_load_mode` to navigation slice (set before opening overlay) |
| Overwrite confirmation | Always confirm before overwriting an occupied slot |
| Legacy save migration | Import `user://savegame.json` to autosave slot on first launch, then delete original |
| Concurrent request protection | Lock flags (`_is_saving`, `_is_loading`) + disabled UI buttons |
| Load progress UI | Inline spinner in save/load menu, disable all buttons during load |
| Settings autosave | Removed; only checkpoint and area completion trigger autosave |
