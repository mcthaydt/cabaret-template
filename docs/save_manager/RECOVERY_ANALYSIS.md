# Save Manager Recovery Analysis

**Date**: 2025-12-22
**Branch**: `save-manager` (still exists, not deleted)
**Stash**: `stash@{0}` - "broken" (attempted bug fixes)

---

## Executive Summary

The `save-manager` branch contains a **55% complete implementation** (40/73 tasks). The stash contains **attempted bug fixes** with extensive debug logging. The bugs match exactly what was documented in LESSONS_LEARNED.md.

**Decision Point**: Start fresh with new architecture OR salvage and fix existing code.

---

## What Exists (Completed Phases)

### ✅ Phase 1-8 Complete (Commits on `save-manager` branch)

| Phase | Status | Commit |
|-------|--------|--------|
| Phase 1: Decisions | ✅ Complete | `cad1858` |
| Phase 2: Data Envelope | ✅ Complete | `e6bc7b7` |
| Phase 3: Core Manager | ✅ Complete | `b5e591a` |
| Phase 4: Root Integration | ✅ Complete | `fedf317`, `099eaa5`, `1e12768` |
| Phase 5: Playtime/Metadata | ✅ Complete | `09da5c4` |
| Phase 6: Redux Integration | ✅ Complete | `269a70b` |
| Phase 7: Autosave Delegation | ✅ Complete | `1f7c629` |
| Phase 8: UI Overlay | ✅ Complete | `bc8e237` |
| Phase 9: Validation | ❌ Incomplete | Bugs discovered |

**Total Code**: ~2,924 lines added

**Files Created**:
```
✅ scripts/managers/m_save_manager.gd (333 lines)
✅ scripts/state/utils/u_save_envelope.gd (189 lines)
✅ scripts/state/resources/rs_save_slot_metadata.gd (110 lines)
✅ scripts/state/resources/rs_save_manager_settings.gd (14 lines)
✅ scripts/state/actions/u_save_actions.gd (79 lines)
✅ scripts/state/selectors/u_save_selectors.gd (54 lines)
✅ scripts/ui/ui_save_slot_selector.gd (379 lines)
✅ scenes/ui/ui_save_slot_selector.tscn
✅ resources/ui_screens/save_slot_selector_overlay.tres
✅ resources/scene_registry/ui_save_slot_selector.tres
✅ resources/settings/save_manager_settings.tres
✅ tests/unit/managers/test_m_save_manager.gd (249 lines)
✅ tests/unit/managers/test_u_save_envelope.gd (141 lines)
✅ tests/unit/resources/test_rs_save_slot_metadata.gd (88 lines)
✅ tests/unit/state/test_save_slice.gd (71 lines)
✅ tests/unit/state/test_autosave_delegation.gd (77 lines)
✅ tests/unit/ui/test_save_slot_selector.gd (107 lines)
✅ tests/helpers/u_save_test_helpers.gd (96 lines)
```

---

## What's Broken (Stashed Attempted Fixes)

### ❌ Critical Bugs (From Stash Analysis)

The stash (`stash@{0}`) contains **debug logging** trying to fix:

1. **ECS Components Not Registering**
   ```gdscript
   // Added debug logs in base_ecs_component.gd:
   print("[ECS DEBUG] Component '%s' FAILED to find ECS manager")
   print("[ECS DEBUG] Component '%s' registered with manager")
   ```

2. **ECS Systems Not Processing**
   ```gdscript
   // Added debug logs in base_ecs_system.gd:
   print("[ECS DEBUG] System '%s' FAILED to find ECS manager")
   print("[ECS DEBUG] System '%s' registered with...")
   ```

3. **Player Stuck in Air (Floating/Movement Not Working)**
   ```gdscript
   // s_floating_system.gd:
   print("[FLOAT DEBUG] No ECS manager found - S_FloatingSystem not processing")
   print("[FLOAT DEBUG] Processing player body: vel.y=%.3f")
   print("[FLOAT DEBUG] Player support: has_hit=%s, hit_count=%d")
   print("[FLOAT DEBUG] Player no support - applied gravity: new vel.y=%.3f")

   // s_movement_system.gd:
   print("[MOVE DEBUG] Before move_and_slide: vel=%s, pos=%s")
   print("[MOVE DEBUG] After move_and_slide: vel=%s, pos=%s, on_floor=%s")
   ```

4. **Physics Process Verification Issues**
   ```gdscript
   // m_ecs_manager.gd:
   print("[ECS DEBUG] M_ECSManager._ready() completed")
   print("[ECS DEBUG] Verifying physics state:")
   print("[ECS DEBUG]   is_physics_processing() = %s")
   print("[ECS DEBUG]   process_mode = %d")
   ```

**Root Cause Analysis**: Load operation broke ECS manager registration and physics processing

---

## Architectural Differences: Old vs New

| Aspect | Old Implementation | New Documentation |
|--------|-------------------|-------------------|
| **Reducer** | Menu slice (`u_menu_reducer.gd`) | Dedicated save slice (`u_save_reducer.gd`) |
| **Metadata** | Separate resource (`rs_save_slot_metadata.gd`) | Embedded in envelope (`SaveMetadata` class) |
| **Manager** | `M_SaveManager` (333 lines) | `U_SaveManager` static utility (plan: ~400 lines) |
| **Envelope** | `u_save_envelope.gd` (189 lines) | `u_save_envelope.gd` (similar structure) |
| **UI Mode** | Stored in menu slice | Stored in save slice |
| **Screenshots** | ❌ Not implemented | ✅ Planned in new docs |
| **Slot Count** | 4 (0-3) | ✅ Same (4 slots) |

**Key Difference**: Old used `M_SaveManager` (manager node), new plans `U_SaveManager` (static utility)

---

## What Can Be Salvaged

### ✅ Reusable (High Quality)

1. **Test Files** - Well-written, comprehensive:
   - `tests/unit/managers/test_m_save_manager.gd` (249 lines)
   - `tests/unit/managers/test_u_save_envelope.gd` (141 lines)
   - `tests/helpers/u_save_test_helpers.gd` (96 lines)

2. **Save Envelope** - Core data structures likely solid:
   - `scripts/state/utils/u_save_envelope.gd` (189 lines)

3. **Settings Resources**:
   - `resources/settings/save_manager_settings.tres`

### ⚠️ Needs Major Fixes

1. **UI Overlay** - Focus navigation completely broken:
   - `scripts/ui/ui_save_slot_selector.gd` (379 lines) - Needs full rewrite
   - `scenes/ui/ui_save_slot_selector.tscn` - Focus neighbors wrong

2. **Load Flow** - Causes physics bugs:
   - Scene transition handling broken
   - ECS manager registration lost
   - Physics processing disabled

3. **Menu Integration** - Mode detection broken:
   - `scripts/ui/ui_main_menu.gd`
   - `scripts/ui/ui_pause_menu.gd`

### ❌ Must Discard

1. **Debug Logs in Core Systems** (from stash):
   - All debug prints in `base_ecs_component.gd`
   - All debug prints in `base_ecs_system.gd`
   - All debug prints in `s_floating_system.gd`
   - All debug prints in `s_movement_system.gd`
   - All debug prints in `m_ecs_manager.gd`

2. **Broken Scene File**:
   - `scenes/prefabs/prefab_player.tscn` - Has transform corruption

---

## Recovery Options

### Option A: Salvage & Fix (Faster, Risky)

**Approach**:
1. Cherry-pick working files from `save-manager` branch
2. Fix the 8 bugs using LESSONS_LEARNED.md strategies
3. Discard stash (debug logs not helpful)

**Pros**:
- 55% already done
- Tests already written
- Core data structures proven

**Cons**:
- Bugs might be deep architectural issues
- Unknown unknowns in existing code
- Focus navigation needs complete rewrite anyway

**Estimated Work**: 2-3 days fixing bugs + testing

---

### Option B: Fresh Start (Slower, Safer)

**Approach**:
1. Start from scratch using new documentation
2. Copy ONLY the test patterns (not the tests themselves)
3. Use new architecture (static `U_SaveManager`, save slice)

**Pros**:
- Clean slate, bug prevention built-in
- Better architecture (static vs node manager)
- Screenshot feature from start
- All 8 bugs explicitly prevented

**Cons**:
- Redo work that was already done
- Tests need rewriting for new architecture

**Estimated Work**: 4-5 days full implementation

---

### Option C: Hybrid (Balanced)

**Approach**:
1. Use old envelope & metadata structures (proven)
2. Use old test patterns (adapt to new architecture)
3. Rewrite UI overlay from scratch (broken anyway)
4. Rewrite load flow from scratch (broken anyway)
5. Use new static manager design (cleaner)

**Pros**:
- Best of both worlds
- Proven data structures
- Clean UI/load flow
- Moderate timeline

**Cons**:
- Complexity in mixing old/new
- Need careful integration

**Estimated Work**: 3-4 days

---

## Recommended Path: **Option C (Hybrid)**

**Rationale**:
1. Data layer (envelope, metadata) is solid - reuse it
2. UI and load flow are broken - rewrite with bug prevention
3. Static manager cleaner than node manager - use new design
4. Tests are valuable - adapt them to new architecture

**Salvage List**:
```
✅ Keep: u_save_envelope.gd (data structures)
✅ Keep: Test patterns from test_u_save_envelope.gd
✅ Keep: rs_save_manager_settings.tres
✅ Keep: Autosave delegation concept from Phase 7

❌ Discard: ui_save_slot_selector.gd (rewrite)
❌ Discard: All debug logs from stash
❌ Discard: Menu reducer approach (use save slice)
❌ Discard: M_SaveManager node (use U_SaveManager static)

🔄 Adapt: Load flow (rewrite with bug prevention)
🔄 Adapt: Menu integration (new mode detection)
🔄 Adapt: Tests (new architecture)
```

---

## Next Steps (If Using Option C)

1. **Extract from `save-manager` branch**:
   ```bash
   git checkout save-manager -- scripts/state/utils/u_save_envelope.gd
   git checkout save-manager -- resources/settings/save_manager_settings.tres
   git checkout save-manager -- tests/unit/managers/test_u_save_envelope.gd
   ```

2. **Verify extracted files** against new documentation
3. **Adapt envelope** if needed (add screenshot support)
4. **Write new tests** following old patterns but new architecture
5. **Implement fresh UI** with LESSONS_LEARNED prevention strategies
6. **Implement fresh load flow** with explicit physics reset

---

## Commit Message Archaeology

Understanding the progression:

```
cad1858 - Documentation (initial planning)
e6bc7b7 - Phase 1 Complete (data structures)
b5e591a - Phase 2 Complete (core manager)
6640012 - Add save envelope helper
9369008 - Update save manager docs for Phase 3
fedf317 - Add SaveManager core and settings
099eaa5 - Update save manager docs for Phase 4
1e12768 - Wire SaveManager into root and ServiceLocator
60dba57 - Update save manager docs for Phase 4 integration
b06ca56 - docs(save-manager): mark Phase 5 complete
09da5c4 - feat(save-manager): Phase 5 playtime + metadata
02c7b78 - docs(save-manager): update Phase 6 status
269a70b - feat(save-manager): Redux actions + command routing
6a2b8bc - docs(save-manager): update Phase 7 status
1f7c629 - feat(save-manager): autosave delegation + triggers
2a8b2b9 - docs(save-manager): phase 8 completion + phase 9 next steps
bc8e237 - feat(save-manager): slot selector overlay + menu wiring
[STASH] - broken (attempted fixes with debug logs)
```

**Pattern**: Methodical phase-by-phase implementation, hit bugs in Phase 9 validation

---

## Risk Assessment

**Salvaging Risk**: Medium
- Data structures proven solid
- UI/load bugs well-documented
- Fresh implementation safer for broken parts

**Timeline Risk**: Low (with Option C)
- Hybrid approach balances speed vs safety
- 3-4 days reasonable with clear bug prevention

**Technical Risk**: Low
- All bugs documented with solutions
- New architecture addresses root causes
- Test coverage already designed

---

**Recommendation**: **Hybrid Option C** - Salvage data layer, rewrite UI/load flow
