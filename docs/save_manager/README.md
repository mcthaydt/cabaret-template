# Save Manager Documentation

**Feature**: Multi-Slot Save System (3 Manual Slots + Autosave)
**Status**: ✅ Planning Complete - Ready for Implementation
**Branch**: `save-manager-v2`
**Created**: 2025-12-22

---

## 📋 Documentation Package

This directory contains the complete planning documentation for the Save Manager feature.

| Document | Purpose | Lines | Status |
|----------|---------|-------|--------|
| [save-manager-prd.md](save-manager-prd.md) | Product requirements, user stories, success criteria | 152 | ✅ Complete |
| [save-manager-plan.md](save-manager-plan.md) | Technical implementation plan with code examples | 421 | ✅ Complete |
| [save-manager-tasks.md](save-manager-tasks.md) | Phase-by-phase task checklist (TDD format) | 289 | ✅ Complete |
| [save-manager-test-plan.md](save-manager-test-plan.md) | Test specifications and GUT test code | 330 | ✅ Complete |
| [save-manager-continuation-prompt.md](save-manager-continuation-prompt.md) | Context for resuming work | 233 | ✅ Complete |
| [AUDIT_FINDINGS.md](AUDIT_FINDINGS.md) | Comprehensive audit report | 407 | ✅ Complete |
| [LESSONS_LEARNED.md](LESSONS_LEARNED.md) | **🔴 CRITICAL: Bugs from previous implementation** | 650+ | ✅ Complete |

**Total Documentation**: 2,482+ lines

⚠️ **CRITICAL**: Read [LESSONS_LEARNED.md](LESSONS_LEARNED.md) FIRST - contains bugs from deleted previous implementation

---

## 🎯 Quick Start

### For Implementation

1. **Read in Order**:
   1. `save-manager-prd.md` - Understand requirements
   2. `save-manager-plan.md` - Learn technical approach
   3. `save-manager-test-plan.md` - See TDD patterns
   4. `save-manager-tasks.md` - Follow implementation checklist

2. **Start Phase 1** (TDD):
   - Write tests first: `tests/unit/state/test_save_manager.gd`
   - Implement: `u_save_envelope.gd` and `u_save_manager.gd`
   - Run tests until green

### For Review

1. **Quick Overview**: Read `save-manager-prd.md` (152 lines)
2. **Technical Deep Dive**: Read `save-manager-plan.md` (421 lines)
3. **Quality Assurance**: See `AUDIT_FINDINGS.md` for audit results

---

## ✨ Feature Summary

Enhances the existing single-file save system to support:

- **3 Manual Save Slots** - User-initiated saves via pause menu
- **1 Autosave Slot** - Automatic periodic saves (60s interval)
- **Save Metadata** - Timestamp, location, health, completion %
- **Continue Button** - Loads most recent save automatically
- **Legacy Migration** - Auto-migrates `savegame.json` → Slot 1

### User Stories (Prioritized)

- **P1**: Manual Save to Slot
- **P1**: Load from Slot
- **P2**: View Save Metadata
- **P2**: Autosave to Dedicated Slot
- **P2**: Continue from Most Recent
- **P3**: Delete Save Slot

---

## 🏗️ Architecture Overview

### File Structure

**9 New Files**:
```
scripts/state/utils/u_save_envelope.gd          # Data structures
scripts/state/utils/u_save_manager.gd           # Slot coordination
scripts/state/actions/u_save_actions.gd         # Redux actions
scripts/state/reducers/u_save_reducer.gd        # Redux reducer
scripts/state/resources/rs_save_initial_state.gd # Initial state
scripts/state/selectors/u_save_selectors.gd     # State queries
scripts/ui/ui_save_slot_selector.gd             # UI controller
scenes/ui/ui_save_slot_selector.tscn            # UI scene
resources/ui_screens/save_slot_selector_overlay.tres # UI definition
```

**8 Modified Files**:
```
scripts/state/m_state_store.gd                  # Register save slice, modify autosave
scripts/ui/u_ui_registry.gd                     # Register overlay
scripts/ui/ui_pause_menu.gd/.tscn               # Add Save button
scripts/ui/ui_main_menu.gd/.tscn                # Add Continue/Load buttons
scripts/state/actions/u_navigation_actions.gd   # Navigation action
scripts/scene_management/u_scene_registry.gd    # Register scene
scripts/state/utils/u_state_slice_manager.gd    # Add save slice init
```

### Data Model

**Save File Paths**:
- `user://save_slot_0.json` - Autosave (protected)
- `user://save_slot_1.json` - Manual Slot 1
- `user://save_slot_2.json` - Manual Slot 2
- `user://save_slot_3.json` - Manual Slot 3

**Save Envelope Format**:
```json
{
  "metadata": {
    "slot_index": 1,
    "timestamp": 1734912345,
    "scene_display_name": "Exterior",
    "completion_percent": 40.0,
    "player_health": 75.0,
    "is_autosave": false
  },
  "state": {
    "gameplay": {...},
    "scene": {...}
  }
}
```

---

## 📅 Implementation Phases

1. **Phase 1**: Data Layer Foundation (TDD) - SaveEnvelope & SaveManager
2. **Phase 2**: Redux Integration (TDD) - Actions, Reducer, Selectors
3. **Phase 3**: Autosave Modification - Redirect to slot 0
4. **Phase 4**: Migration - Legacy save → slot 1
5. **Phase 5**: UI Layer - Save/Load overlay
6. **Phase 6**: Menu Integration - Pause & main menu buttons
7. **Phase 7**: Load Flow - Scene transition after load
8. **Phase 8**: Polish - Confirmations, errors, UX

**Estimated Tasks**: 18 major tasks across 8 phases

---

## 🧪 Test-Driven Development

All implementation follows **RED → GREEN → REFACTOR**:

1. **Write tests first** (they fail)
2. **Implement minimal code** (tests pass)
3. **Refactor** (keep tests green)

**Test Coverage**:
- Phase 1: 13 unit tests for save/load/metadata
- Phase 2: 10 unit tests for Redux reducer
- Phase 7: Integration tests for end-to-end flows

**Test Location**: `tests/unit/state/test_save_manager.gd`, `test_save_reducer.gd`

---

## ✅ Audit Status

**Audit Date**: 2025-12-22
**Auditor**: Claude Sonnet 4.5
**Result**: ✅ APPROVED FOR IMPLEMENTATION

**Grade**: A (95/100)

**Findings**:
- ✅ All naming conventions match STYLE_GUIDE.md
- ✅ All file paths verified against existing structure
- ✅ Redux patterns align with codebase conventions
- ✅ TDD approach properly structured
- ✅ Critical code examples provided

**P0 Fixes Applied**:
- ✅ Slice registration code detailed
- ✅ Autosave modification code complete

See [AUDIT_FINDINGS.md](AUDIT_FINDINGS.md) for full report.

---

## 🚀 Ready to Implement

**Prerequisites**: ✅ All met
- Redux state management in place
- U_StatePersistence working
- Overlay system functional
- Navigation actions pattern established

**No Blockers**

**Next Action**: Begin Phase 1 - Create `tests/unit/state/test_save_manager.gd`

---

## 📖 Design Decisions

1. **Continue Button**: Loads most recent save (any slot) automatically
2. **Autosave Protection**: Slot 0 cannot be deleted by player
3. **New Game Flow**: Auto-selects first empty slot
4. **File Format**: Envelope pattern (metadata + state in one JSON)
5. **Migration**: Legacy → Slot 1, renamed to `.backup`

---

## 🔗 Related Documentation

- [STYLE_GUIDE.md](../general/STYLE_GUIDE.md) - Naming conventions
- [AGENTS.md](../../AGENTS.md) - Project patterns and conventions
- [DEV_PITFALLS.md](../general/DEV_PITFALLS.md) - Common issues to avoid

---

## 📝 Document History

| Date | Event | Author |
|------|-------|--------|
| 2025-12-22 | Initial planning and documentation | Claude |
| 2025-12-22 | Comprehensive audit completed | Claude |
| 2025-12-22 | P0 fixes applied, approved for implementation | Claude |

---

**Status**: 🟢 **READY FOR IMPLEMENTATION**
