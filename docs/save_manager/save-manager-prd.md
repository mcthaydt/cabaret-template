# Save Manager PRD - Multi-Slot Save System

**Feature**: Save Manager (3 Manual Slots + Autosave)
**Branch**: `save-manager-v2`
**Status**: Planning
**Created**: 2025-12-22

---

## Executive Summary

Enhance the existing single-file save system to support 3 manual save slots plus a dedicated autosave slot, providing players with better save management, progress protection, and quality-of-life improvements.

---

## User Stories (Prioritized)

### P1: Manual Save to Slot

**As a player**, I want to manually save my game progress to one of three available slots so that I can preserve my progress at key moments.

**Acceptance Criteria**:
- Can save from pause menu during gameplay
- Saves include timestamp and game state
- Overwriting existing saves is allowed
- Saves blocked during scene transitions

**Test**: Pause → Save Game → Select Slot 1 → Verify save with timestamp

---

### P1: Load from Slot

**As a player**, I want to load my saved game from any slot to resume progress.

**Acceptance Criteria**:
- Can load from main menu or pause menu
- Empty slots cannot be loaded
- Loaded state includes correct scene, spawn point, health, checkpoints
- Loading triggers scene transition

**Test**: Main Menu → Load Game → Select populated slot → Verify game state restored

---

### P2: View Save Metadata

**As a player**, I want to see save slot information (timestamp, location, progress) before loading.

**Acceptance Criteria**:
- Display: date/time, scene name, health %, completion %
- Human-readable scene names (not IDs)
- Visual distinction between empty and populated slots

**Test**: Load Game menu → Verify each slot displays metadata correctly

---

### P2: Autosave to Dedicated Slot

**As a player**, I want automatic periodic saves so I don't lose progress if I forget to manually save.

**Acceptance Criteria**:
- Autosave at configurable interval (default: 60s)
- Only autosaves during active gameplay (not menus)
- Autosave slot visually distinct in UI
- Silent operation (no interruption)

**Test**: Play for 60s → Force quit → Verify autosave slot has recent progress

---

### P2: Continue from Most Recent

**As a player**, I want a "Continue" button that loads my most recent save automatically.

**Acceptance Criteria**:
- Finds most recent save across all slots
- Hidden/disabled when no saves exist
- Works with autosave or manual slots

**Test**: Save to any slot → Main Menu → Continue → Verify correct save loads

---

### P3: Delete Save Slot

**As a player**, I want to delete unwanted saves.

**Acceptance Criteria**:
- Can delete manual slots (1-3)
- Autosave slot (0) cannot be deleted
- Requires confirmation dialog
- Deleted slots show as empty

**Test**: Select slot → Delete → Confirm → Verify slot empty

---

## Functional Requirements

- **FR-001**: Support 3 manual slots + 1 autosave (4 total files)
- **FR-002**: Persist: scene ID, spawn point, health, completed areas, last checkpoint
- **FR-003**: Store metadata: timestamp, scene name, completion %, health
- **FR-004**: Manual save from pause menu (gameplay only)
- **FR-005**: Load from main menu and pause menu
- **FR-006**: Autosave at configurable interval (60s default)
- **FR-007**: Block save/load during transitions
- **FR-008**: Visual feedback on save completion
- **FR-009**: Integrate with existing `U_StatePersistence` infrastructure
- **FR-010**: File paths: `user://save_slot_0.json` (autosave), `user://save_slot_{1,2,3}.json` (manual)

---

## Success Criteria

- **SC-001**: Save/load works reliably for all 3 manual slots
- **SC-002**: Operations complete in <500ms
- **SC-003**: Autosave triggers without frame drops
- **SC-004**: Metadata displays correctly in UI
- **SC-005**: Corrupted saves handled gracefully
- **SC-006**: Legacy `savegame.json` migrated to Slot 1 on first launch

---

## Edge Cases & Error Handling

| Scenario | Behavior |
|----------|----------|
| Corrupted save file | Display error, mark slot "Corrupted", allow delete |
| Disk full | Display error, don't overwrite valid saves |
| Old save version | Validate/migrate schema, or warn user |
| Autosave during transition | Defer until transition completes |
| All slots full | Allow overwriting with confirmation |

---

## Design Decisions

1. **Continue Button**: Main menu shows "Continue" loading most recent save
2. **Autosave Protection**: Slot 0 (autosave) cannot be deleted
3. **New Game**: Auto-selects first empty slot; prompts to overwrite if all full

---

## Out of Scope (v1)

- Cloud save sync
- Save slot renaming/custom labels
- Save slot copying
- Quicksave/quickload hotkeys
- Screenshot thumbnails for saves
