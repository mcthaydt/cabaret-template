# Save Manager Overview

**Project**: Cabaret Template (Godot 4.5)
**Created**: 2025-12-25
**Last Updated**: 2025-12-25
**Status**: READY FOR IMPLEMENTATION
**Scope**: Single-slot autosave + 3 manual slots; loads allowed from pause overlay

## Summary

The Save Manager is a persistent orchestration layer that coordinates save/load timing, slot management, atomic disk IO, versioning/migrations, and user-facing status/errors. It does **not** define gameplay data; the Redux-style `M_StateStore` remains the single source of truth for what gets serialized and how transient fields are excluded/normalized.

## Goals

- Persist player progress reliably (crash-safe, atomic writes).
- Support **one autosave slot** plus **3 manual slots** with metadata for UI.
- Allow loading from the **pause overlay** safely (state + scene restore).
- Keep save/load logic centralized and testable (migrations as pure transforms).
- Replace existing `M_StateStore` autosave timer with intelligent, event-driven autosave.

## Non-Goals

- No second gameplay snapshot system outside Redux state.
- No per-frame/high-frequency saving (avoid disk thrash and "bad autosave" overwrites).
- No direct scene graph serialization (entities/components restore via state + scene load flow).
- No async/threaded saves (synchronous writes for simplicity; acceptable for small save files).
- No cloud sync (local persistence only for initial implementation).

## Responsibilities & Boundaries

**Save Manager owns**

- Slot registry (autosave + manual slots) and "last used slot" bookkeeping.
- Save/load requests, debouncing/coalescing, and priority handling.
- Atomic writes (`.tmp` -> rename) and `.bak` last-good backup strategy.
- Save file header metadata and `save_version` migrations (pure `Dictionary -> Dictionary`).
- Reporting to UI/state: started/succeeded/failed signals (and/or dispatching Redux status actions).
- Playtime tracking coordination (reads from gameplay slice).

**Save Manager depends on**

- `M_StateStore`: state access via `get_state()` and `dispatch()`; normalization via existing validators.
- `M_SceneManager`: transitions to restored `current_scene_id` and spawn restore flow.
- `U_SceneRegistry`: scene metadata and display names for area_name header field.
- Service discovery: ServiceLocator first, group fallback (consistent with other managers).

**Note on file format**: Save Manager writes its OWN file format (`{header, state}`) using `u_save_file_io.gd`. It does NOT use `M_StateStore.save_state(filepath)` directly because that method writes raw state without our header wrapper. The Save Manager:
1. Gets state snapshot via `M_StateStore.get_state()`
2. Builds header metadata (playtime, timestamp, scene_id, etc.)
3. Writes combined `{header, state}` via atomic file IO helper

## Public API

```gdscript
# Save to a specific slot (manual save)
M_SaveManager.save_to_slot(slot_id: StringName) -> Error

# Load from a specific slot
M_SaveManager.load_from_slot(slot_id: StringName) -> Error

# Delete a save slot
M_SaveManager.delete_slot(slot_id: StringName) -> Error

# Get metadata for all slots (for UI display)
M_SaveManager.get_all_slot_metadata() -> Array[Dictionary]

# Get metadata for a specific slot
M_SaveManager.get_slot_metadata(slot_id: StringName) -> Dictionary

# Check if a slot has a valid save
M_SaveManager.slot_exists(slot_id: StringName) -> bool

# Request autosave (internal, called by scheduler)
M_SaveManager.request_autosave(priority: int) -> void
```

## Existing Code Migration

**Remove from M_StateStore** (`scripts/state/m_state_store.gd`):
- `_autosave_timer: Timer`
- `_setup_autosave_timer()`
- `_on_autosave_timeout()`

**Keep in M_StateStore**:
- `get_state()` method (Save Manager reads current state)
- `dispatch()` method (Save Manager applies loaded state via actions)
- `state_loaded` signal (may be useful for downstream listeners)
- Existing `save_state()`/`load_state()` methods (kept for legacy; Save Manager uses its own IO)

## Slot Model & File Layout

### Slots

- **Autosave**: reserved slot id (`autosave`) overwritten by autosave events.
- **Manual**: user-created slots (`slot_01`, `slot_02`, `slot_03`) written on explicit user intent.
- **Slot cap**: 4 total (1 autosave + 3 manual). Block new saves when full.

### Files (flat structure at `user://saves/`)

```
user://saves/
  autosave.json
  autosave.json.bak
  slot_01.json
  slot_01.json.bak
  slot_02.json
  slot_02.json.bak
  slot_03.json
  slot_03.json.bak
```

- `{slot}.json`: `{ "header": { ... }, "state": { ... } }`
- `{slot}.json.bak`: last known good save (backup)
- `{slot}.json.tmp`: temp file used for atomic write (ignored/cleaned on boot)

### Header Fields

| Field | Type | Description |
|-------|------|-------------|
| `save_version` | int | Schema version for migration logic |
| `timestamp` | String | ISO 8601 formatted (e.g., "2025-12-25T10:30:00Z") |
| `build_id` | String | Game version/build identifier |
| `playtime_seconds` | int | Total seconds played (from gameplay slice) |
| `current_scene_id` | String | Scene ID at time of save |
| `last_checkpoint` | String | Checkpoint marker name (if present) |
| `target_spawn_point` | String | Spawn point marker name (if present) |
| `area_name` | String | Human-readable location for UI display (from scene registry) |
| `thumbnail_path` | String | Path to screenshot (nullable, deferred implementation) |

**area_name derivation**: Obtained from `U_SceneRegistry` using the `current_scene_id`. If the scene has a `display_name` metadata field, use that; otherwise fall back to a formatted version of the scene_id (e.g., "gameplay_base" -> "Gameplay Base").

## Playtime Tracking

**New gameplay slice field**: `playtime_seconds: int`

- Incremented by dedicated `S_PlaytimeSystem` every second during active gameplay.
- System pauses tracking when: game is paused, in menus, or during scene transitions.
- Excluded from transient fields (persists across scene transitions).
- Read by Save Manager when building header metadata.

**New system**: `S_PlaytimeSystem` (`scripts/ecs/systems/s_playtime_system.gd`)
- Extends `BaseECSSystem`
- Queries navigation state to determine if gameplay is active
- Dispatches `U_GameplayActions.increment_playtime(delta_seconds)` periodically

## Save Workflow

### Manual save (explicit user action)

- Treat as **immediate** and user-intent:
  - Snapshot current Redux state once.
  - Write atomically + update slot metadata.
  - Surface success/failure to UI via toast.

### Autosave (single slot)

- Treat as "dirty flag + coalesced write":
  - Autosave requests mark the autosave slot as dirty with a priority.
  - A scheduler writes the latest pending autosave once the state is stable.
  - Apply a cooldown to routine autosaves, but allow priority overrides for critical events.

## Load Workflow (Allowed From Pause Overlay)

Loading from pause is a controlled "state + scene reset" using the existing **StateHandoff** pattern:

1. Pause overlay requests load; UI shows inline spinner and disables all buttons.
2. Save Manager checks `_is_loading` lock and rejects if already loading.
3. Save Manager rejects load if a scene transition is already in progress.
4. Save Manager sets `_is_loading = true`, cancels pending autosaves, blocks new autosaves.
5. Read `{slot}.json` -> validate header/version -> apply migrations (raw Dictionary, before state application).
6. Use **StateHandoff** pattern: store loaded state for scene transition (existing pattern in codebase).
7. Transition via `M_SceneManager` to the loaded `current_scene_id`.
8. StateHandoff applies state after scene loads (existing normalization runs: scene id, spawn fallback, checkpoint sanitization).
9. Scene transition closes pause overlay automatically, set `_is_loading = false`, re-enable autosaves.
10. On failure: show inline error in UI, remain paused, keep current session state unchanged.

## Autosave Triggers (Event List)

Autosave should trigger on **milestones** (rare, meaningful, low-frequency), not continuous gameplay changes.

### Progress milestones (save ASAP; priority)

- **Checkpoint updated**: `last_checkpoint` and/or `target_spawn_point` changes (primary "don't lose progress" moment).
- **Area/progression marked complete**: `completed_areas` (or equivalent) changes.
- **Unlock/major acquisition milestone**: new persistent unlock flags or inventory milestones (coalesce if multiple happen together).
- **Scene transition completed**: after `M_SceneManager` finishes loading the target gameplay scene and the Store reflects the new `current_scene_id` + spawn context (save after completion, not at request time).

### Settings/profile milestones

Settings changes are **not** autosave triggers. Settings are saved via separate settings persistence (if implemented) or simply applied in-memory. This avoids complexity and reduces disk writes.

## Autosave Anti-Triggers (Avoid)

- High-frequency state updates: per-tick movement/position/velocity, timers, combat tick damage, UI focus churn.
- **Death states**: Check `gameplay.death_in_progress == false` before allowing autosave. This flag is set `true` on death trigger, `false` on respawn/reset.
- During transitions or loads: block until stable to avoid inconsistent snapshots.

## Timing & Coalescing Rules

- Snapshot only after the Store has settled for the frame in which the milestone actions are reduced.
- Coalesce multiple autosave requests into **one** write (latest request wins), with priority escalation when needed.
- Enforce a global cooldown for routine autosaves; allow overrides for checkpoint/victory/rebind.

**Default timing configuration**:
- Cooldown duration: 5.0 seconds
- Priority overrides: HIGH (>2s since last), CRITICAL (always)

## UI Integration

### Pause Menu Integration

Add Save and Load buttons to `ui_pause_menu.gd` (between Settings and Quit):
- Save button -> opens save/load overlay in "save" mode
- Load button -> opens save/load overlay in "load" mode

Pattern: `U_NavigationActions.open_overlay(StringName("save_load_menu_overlay"))`

### Save/Load Overlay Screen (Combined)

Single overlay scene (`ui_save_load_menu.tscn`) with mode switching:
- **Mode indicator**: Read from `navigation.save_load_mode` (set before opening overlay)
- **Slot list**: All 4 slots (autosave + slot_01-03) with metadata
  - Timestamp (formatted: "Dec 25, 2025 10:30 AM")
  - Area name (human-readable, derived from `U_SceneRegistry.get_display_name()`)
  - Playtime (formatted: HH:MM:SS)
  - Thumbnail placeholder (greyed box)
- **Per-slot actions**:
  - Save mode: [Save] button (shows confirmation if slot occupied), [Delete] button
  - Load mode: [Load] button, [Delete] button
  - Empty slot: [New Save] in save mode, disabled in load mode
  - **Autosave slot**: Delete button hidden/disabled (autosave cannot be deleted)
- **Overwrite confirmation**: Before saving to occupied slot, show "Overwrite existing save?" dialog
- **Loading state**: Inline spinner + all buttons disabled during load operation
- **Back button**: Returns to pause menu

**Registration requirements**:
1. Scene in `U_SceneRegistry` with `SceneType.UI`
2. Overlay definition in `resources/ui_screens/cfg_save_load_menu_overlay.tres`

### Toast Notifications

Reuse existing checkpoint toast pattern in `ui_hud_controller.gd`:
- **Autosave started**: subtle "Saving..." indicator
- **Save completed**: "Game Saved" toast
- **Save failed**: "Save Failed" error toast
- **Load failed**: "Load Failed" error toast

**Important**: Toasts are suppressed while paused (consistent with checkpoint toasts). Manual saves from pause menu rely on inline UI feedback (slot refresh, confirmation dialog) instead of toasts.

Subscribe to ECS events via `U_ECSEventBus`:
- `save_started` (payload: slot_id, is_autosave)
- `save_completed` (payload: slot_id)
- `save_failed` (payload: slot_id, error_code)

## Error Handling & Fallbacks

- Atomic write prevents partial saves; `.tmp` is ignored on startup.
- Keep `.bak` as last-good; on load failure/corruption, attempt `.bak` before giving up.
- If migration fails or save is invalid, do not mutate current session; surface an actionable error message via toast.

## Testing Strategy

### Test Directory

Use `user://test/` for integration tests with real filesystem:
- Create directory in test setup
- Clean up files in teardown
- Isolated from production saves at `user://saves/`

### Test Categories

- **Migration unit tests**: `Dictionary -> Dictionary` transforms (pure, deterministic).
- **Save/load integration**: write save -> load save -> assert Store normalization and scene id/spawn fallback behave.
- **Corruption handling**: truncated/invalid JSON yields graceful failure and/or `.bak` fallback.
- **Atomic write verification**: interrupt mid-write, verify `.tmp` ignored and original intact.

## Resolved Questions

| Question | Decision |
|----------|----------|
| Slot cap/retention policy | 3 manual slots max; block when full (user must delete) |
| UI metadata requirements | Timestamp, area name, playtime (formatted HH:MM:SS) |
| Autosave after manual load | No; wait for next milestone |
| Thumbnail capture | Schema ready (`thumbnail_path`); capture deferred to future |
| Threading model | Synchronous only (blocking writes acceptable for save file size) |
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
