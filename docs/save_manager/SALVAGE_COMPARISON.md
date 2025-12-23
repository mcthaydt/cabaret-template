# Salvage Comparison: Old vs New Implementation

**Created**: 2025-12-22
**Purpose**: Compare previous implementation (save-manager branch) with new plan (save-manager-v2) to decide what to salvage

---

## Executive Summary

**Previous Implementation Quality**: ✅ **HIGH QUALITY**
- Clean, well-structured code
- Comprehensive error handling
- Good use of type hints and validation
- Proper separation of concerns
- **55% complete** (40/73 tasks through Phase 8)

**Salvage Recommendation**: ✅ **SALVAGE DATA LAYER** - The core data structures are solid and match the new plan

---

## File-by-File Comparison

### 1. U_SaveEnvelope (Data Structures)

**Old Implementation**: `scripts/state/utils/u_save_envelope.gd` (189 lines)

**What it does**:
- SaveEnvelope with version, metadata, state
- Static utility functions for read/write
- Legacy migration support
- Proper JSON serialization with U_SerializationHelper

**Quality**: ✅ **EXCELLENT**
- Clean static utility pattern
- Comprehensive error handling (file errors, parse errors)
- Validates version before loading
- Atomic file operations with error recovery

**Differences from New Plan**:
| Aspect | Old Implementation | New Plan |
|--------|-------------------|----------|
| Metadata Storage | Separate `RS_SaveSlotMetadata` Resource | Embedded `SaveMetadata` class in envelope |
| File Structure | `{version, metadata, state}` | `{metadata, state}` (version in metadata) |
| Serialization | Uses `U_SerializationHelper` | Direct JSON conversion |
| Slot Paths | Via `RS_SaveManagerSettings` resource | Hardcoded constants in envelope |

**Recommendation**: ✅ **SALVAGE WITH MINOR ADAPTATIONS**
- The old approach is actually BETTER (Resource pattern is cleaner)
- Keep `RS_SaveSlotMetadata` resource
- Adapt new tests to work with Resource instead of plain class
- Update new plan to match this architecture

**Why Old Approach is Better**:
1. Resources are inspectable in editor
2. Better type safety than Dictionary
3. Export variables for debugging
4. Matches Godot conventions

---

### 2. RS_SaveSlotMetadata (Metadata Resource)

**Old Implementation**: `scripts/state/resources/rs_save_slot_metadata.gd` (110 lines)

**What it provides**:
```gdscript
- slot_id: int
- slot_type: enum (MANUAL/AUTO)
- scene_id: StringName
- scene_name: String
- timestamp: int
- formatted_timestamp: String
- play_time_seconds: float
- player_health: float
- player_max_health: float
- death_count: int
- completed_areas: Array[String]
- completion_percentage: float
- is_empty: bool
- file_path: String
- file_version: int
```

**Quality**: ✅ **EXCELLENT**
- Complete to_dictionary/from_dictionary roundtrip
- Type-safe array conversion
- StringName ↔ String conversion handled
- Display summary helper (`get_display_summary()`)
- Proper export annotations

**Differences from New Plan**:
- Old uses Resource class (better)
- Old includes `formatted_timestamp` (convenience)
- Old includes `is_empty` flag (useful)
- Old includes `file_path` (helpful for debugging)

**Recommendation**: ✅ **SALVAGE COMPLETELY** - This is production-ready

---

### 3. M_SaveManager vs U_SaveManager

**Old Implementation**: `M_SaveManager` extends Node (333 lines)

**Architecture**:
- Node-based manager (scene tree lifecycle)
- Subscribes to Redux store actions
- Auto-rescan on slot changes
- Autosave delegation via action routing
- Signal-based slot refresh notifications

**Key Features**:
```gdscript
- save_to_slot(slot_index)
- save_to_auto_slot()
- load_from_slot(slot_index)
- delete_slot(slot_index)
- get_most_recent_slot()
- rescan_slots()
- Auto-subscribes to store actions
- Routes save/load/delete actions from Redux
- Autosave triggers (checkpoint, scene transition, return to menu)
- Safety checks (no save during transitions, only in gameplay shell)
```

**New Plan**: `U_SaveManager` static utility (~400 lines planned)

**Quality Comparison**:

| Aspect | Old (M_SaveManager Node) | New (U_SaveManager Static) |
|--------|-------------------------|---------------------------|
| Lifecycle | Scene tree _ready/_exit_tree | Stateless utility |
| Store Access | Injected via export + ServiceLocator | Passed as parameter |
| Action Routing | Auto-subscribes, routes actions | Manual dispatch only |
| Slot Caching | Caches `_slots` array | No caching |
| Signals | Emits `slots_refreshed` | No signals |
| Settings | External Resource | Inline constants |

**Recommendation**: ⚠️ **HYBRID APPROACH**

**Keep from Old**:
- The action routing pattern (`_route_action_deferred`)
- The autosave safety checks (`_is_safe_to_autosave`)
- The legacy migration logic
- The metadata extraction (`_build_metadata_from_state`)

**Use from New**:
- Static utility pattern (simpler to test)
- No node lifecycle dependencies
- Pass store as parameter instead of injection

**Rationale**:
- Old manager works but couples to scene tree
- New static approach is cleaner for testing
- Can copy logic patterns from old to new

---

### 4. Redux Integration (Actions, Reducer, Selectors)

**Old Implementation**:

**Actions** (`u_save_actions.gd` - 79 lines):
```gdscript
- ACTION_REFRESH_SLOTS
- ACTION_SAVE_TO_SLOT
- ACTION_LOAD_FROM_SLOT
- ACTION_DELETE_SLOT
- ACTION_SET_AVAILABLE_SLOTS (reducer-only)
- save_to_slot(slot_id)
- load_from_slot(slot_id)
- delete_slot(slot_id)
- set_available_slots(slots)
```

**Selectors** (`u_save_selectors.gd` - 54 lines):
```gdscript
- get_available_slots(state)
- get_slot_by_id(state, slot_id)
- get_most_recent_slot(state)
- has_any_saves(state)
```

**No dedicated reducer** - Uses `u_menu_reducer.gd` instead

**Quality**: ✅ **GOOD** - Actions and selectors are clean

**Differences from New Plan**:
- Old stores slots in `menu` slice
- New creates dedicated `save` slice with operation state

**Recommendation**: ⚠️ **ADAPT ACTIONS, CREATE NEW REDUCER**
- Salvage action creators (well-written)
- Salvage selectors (useful)
- Create new dedicated `u_save_reducer.gd` as planned
- Move from menu slice to save slice

---

### 5. UI Implementation

**Old Implementation**: `ui_save_slot_selector.gd` (379 lines + extensive stash changes)

**Known Issues** (from LESSONS_LEARNED.md):
1. ❌ Focus navigation completely broken
2. ❌ Load reopened menu + player stuck in air
3. ❌ Mode detection broken

**Quality**: ❌ **BROKEN** - Needs complete rewrite

**Recommendation**: ❌ **DISCARD** - Rewrite from scratch with bug prevention

---

## Test Suite Analysis

**Old Tests**:
- `test_m_save_manager.gd` (249 lines)
- `test_u_save_envelope.gd` (141 lines)
- `test_rs_save_slot_metadata.gd` (88 lines)
- `test_save_slice.gd` (71 lines)
- `test_autosave_delegation.gd` (77 lines)
- `test_save_slot_selector.gd` (107 lines)

**Total**: 733 lines of tests

**Quality**: ✅ **EXCELLENT** - Comprehensive coverage

**Recommendation**: ✅ **SALVAGE TEST PATTERNS**
- Adapt tests for static U_SaveManager
- Keep envelope and metadata tests as-is
- Rewrite UI tests with bug prevention

---

## Stash Analysis (Debug Logs)

**What the stash contains**:
- 474 lines changed across 19 files
- Debug logs in ECS core systems
- Debug logs in physics systems
- Attempted fixes for "player stuck in air" bug

**Files with debug logs**:
```
scripts/ecs/base_ecs_component.gd
scripts/ecs/base_ecs_system.gd
scripts/ecs/systems/s_floating_system.gd
scripts/ecs/systems/s_movement_system.gd
scripts/managers/m_ecs_manager.gd
scripts/managers/m_pause_manager.gd
scripts/managers/m_scene_manager.gd
scripts/managers/m_spawn_manager.gd
```

**Quality**: ❌ **DEBUGGING ATTEMPT** - Not production code

**Recommendation**: ❌ **DISCARD COMPLETELY** - These were failed debugging attempts

---

## Side-by-Side Architecture Comparison

### File Structure

| File | Old Approach | New Approach | Recommendation |
|------|-------------|--------------|----------------|
| **Data Layer** | | | |
| Envelope utility | `u_save_envelope.gd` ✅ | `u_save_envelope.gd` | ✅ Keep old |
| Metadata | `rs_save_slot_metadata.gd` (Resource) ✅ | Embedded class | ✅ Keep old Resource |
| Settings | `rs_save_manager_settings.tres` ✅ | Inline constants | ✅ Keep old Resource |
| **Manager** | | | |
| Core logic | `M_SaveManager` (Node) ⚠️ | `U_SaveManager` (Static) ✅ | ⚠️ Copy logic to static |
| **Redux** | | | |
| Actions | `u_save_actions.gd` ✅ | `u_save_actions.gd` | ✅ Keep old |
| Reducer | Uses `u_menu_reducer` ❌ | `u_save_reducer.gd` ✅ | ✅ Create new |
| Initial state | N/A | `rs_save_initial_state.gd` ✅ | ✅ Create new |
| Selectors | `u_save_selectors.gd` ✅ | `u_save_selectors.gd` | ✅ Keep old |
| **UI** | | | |
| Controller | `ui_save_slot_selector.gd` ❌ | `ui_save_slot_selector.gd` | ❌ Rewrite fresh |
| Scene | `ui_save_slot_selector.tscn` ❌ | `ui_save_slot_selector.tscn` | ❌ Rebuild fresh |

---

## Concrete Salvage Plan

### Phase 1: Copy Proven Data Layer

**Action**: Copy these files from `save-manager` branch to current branch:

```bash
# Core data structures (proven solid)
git checkout save-manager -- scripts/state/utils/u_save_envelope.gd
git checkout save-manager -- scripts/state/resources/rs_save_slot_metadata.gd

# Settings resource
git checkout save-manager -- resources/settings/save_manager_settings.tres

# Test helpers
git checkout save-manager -- tests/helpers/u_save_test_helpers.gd

# Redux actions and selectors (will adapt)
git checkout save-manager -- scripts/state/actions/u_save_actions.gd
git checkout save-manager -- scripts/state/selectors/u_save_selectors.gd
```

**Verify**: Read each file to ensure no debug logs or broken code

---

### Phase 2: Adapt Tests for Salvaged Components

**Action**: Copy and adapt test files:

```bash
# Envelope tests (should work as-is)
git checkout save-manager -- tests/unit/managers/test_u_save_envelope.gd

# Metadata tests (should work as-is)
git checkout save-manager -- tests/unit/resources/test_rs_save_slot_metadata.gd
```

**Then**: Create new `test_save_manager.gd` for static U_SaveManager (already done in current branch)

---

### Phase 3: Create New Components with Old Logic

**New Files to Create** (using logic from old M_SaveManager):

1. **`u_save_manager.gd`** (static utility)
   - Copy `_save_to_path()` logic
   - Copy `_load_from_path()` logic
   - Copy `_build_metadata_from_state()` logic
   - Copy `_is_safe_to_autosave()` checks
   - Make all methods static
   - Remove node lifecycle code

2. **`u_save_reducer.gd`** (new dedicated slice)
   - Handle `ACTION_SET_AVAILABLE_SLOTS`
   - Track operation state (is_saving, is_loading, last_error)
   - Store mode (SAVE vs LOAD)

3. **`rs_save_initial_state.gd`** (new resource)
   - Empty slots array
   - Operation state defaults

---

### Phase 4: Rewrite UI with Bug Prevention

**Action**: Start fresh with `ui_save_slot_selector.gd`
- Reference old file for UI element structure
- Apply all LESSONS_LEARNED bug fixes
- Use new focus configuration pattern
- Implement proper mode state management

---

## Key Insights from Old Implementation

### 1. Legacy Migration Pattern (Brilliant)

Old implementation includes automatic migration:

```gdscript
func try_import_legacy_as_auto_slot(
    legacy_path: String,
    auto_path: String,
    legacy_backup_path: String
) -> Error
```

**This is GREAT** - It:
1. Checks if autosave exists (skip if yes)
2. Checks if legacy save exists (skip if no)
3. Reads legacy JSON
4. Wraps in envelope format
5. Renames legacy to `.backup`

**Recommendation**: ✅ Keep this exactly as-is

---

### 2. Autosave Safety Checks (Well-Designed)

```gdscript
func _is_safe_to_autosave(ignore_overlays: bool) -> bool:
    # Don't save during transitions
    if scene_slice.get("is_transitioning"):
        return false

    # Only save in gameplay shell
    if shell != "gameplay":
        return false

    # Don't save with overlays open (unless ignoring)
    if not ignore_overlays and overlay_stack.size() > 0:
        return false

    # Don't save while paused
    if gameplay_slice.get("paused"):
        return false
```

**Recommendation**: ✅ Keep this logic pattern

---

### 3. Action Routing Pattern (Clever)

Old M_SaveManager routes Redux actions:

```gdscript
U_SaveActions.ACTION_SAVE_TO_SLOT → save_to_slot()
U_SaveActions.ACTION_LOAD_FROM_SLOT → load_from_slot()
U_GameplayActions.ACTION_SET_LAST_CHECKPOINT → _request_autosave()
U_SceneActions.ACTION_TRANSITION_COMPLETED → _request_autosave()
U_NavigationActions.ACTION_RETURN_TO_MAIN_MENU → _request_autosave()
```

**Recommendation**: ⚠️ Rethink for static utility
- Static utility can't subscribe to store
- Need different pattern (maybe middleware or explicit calls)

---

## Final Recommendation: Hybrid Approach

**✅ SALVAGE** (Copy from save-manager):
1. `u_save_envelope.gd` (data structures) - **KEEP AS-IS**
2. `rs_save_slot_metadata.gd` (metadata resource) - **KEEP AS-IS**
3. `rs_save_manager_settings.tres` (settings) - **KEEP AS-IS**
4. `u_save_actions.gd` (actions) - **KEEP AS-IS**
5. `u_save_selectors.gd` (selectors) - **KEEP AS-IS**
6. Test patterns from envelope/metadata tests - **ADAPT FOR NEW TESTS**

**🔄 ADAPT** (Copy logic, new structure):
7. M_SaveManager logic → U_SaveManager static utility - **COPY METHODS, MAKE STATIC**

**❌ DISCARD** (Rewrite fresh):
8. `ui_save_slot_selector.gd` - **REWRITE WITH BUG FIXES**
9. All stash debug logs - **IGNORE COMPLETELY**
10. Menu reducer integration - **CREATE NEW SAVE REDUCER**

**📝 CREATE NEW**:
11. `u_save_reducer.gd` - **NEW DEDICATED SLICE**
12. `rs_save_initial_state.gd` - **NEW RESOURCE**
13. Modified M_StateStore autosave - **NEW DELEGATION CODE**

---

## Updated Test File Strategy

**Current Status**: We already created `test_save_manager.gd` for static utility

**Action Needed**:
1. ✅ Keep current `test_save_manager.gd` (already matches static utility pattern)
2. ✅ Copy `test_u_save_envelope.gd` from old branch (test data structures)
3. ✅ Copy `test_rs_save_slot_metadata.gd` from old branch (test Resource)
4. ❌ Skip old `test_m_save_manager.gd` (node-based, doesn't apply)
5. ✅ Adapt old test patterns where useful

---

## Next Steps

1. **Copy data layer files** from save-manager branch
2. **Run salvaged tests** to verify they work
3. **Create U_SaveManager** as static utility with M_SaveManager logic
4. **Run new tests** against static utility
5. **Create save reducer** (new)
6. **Rewrite UI** with bug prevention
7. **Test end-to-end** flows

**Timeline Estimate**: 2-3 days (vs 4-5 days fresh start)

**Risk**: Low - Data layer is proven, UI rewrite addresses all known bugs

---

**Bottom Line**: The previous implementation's **data layer is excellent** and should be salvaged. The UI layer is broken and should be rewritten. The manager logic is good but should be adapted to static utility pattern.
