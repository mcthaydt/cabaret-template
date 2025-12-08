# Exception Elimination Progress - Phase 4B

**Goal:** Rename all 30 files lacking proper prefixes to eliminate exception lists from style enforcement tests.

**Started:** 2025-12-08
**Status:** Batch 1/5 Complete

---

## Complete File Inventory (30 files total)

### ✅ Batch 1: ECS Base Classes (3 files) - COMPLETE

| Old Filename | New Filename | Class Name Change | Commit |
|--------------|--------------|-------------------|--------|
| `ecs_component.gd` | `base_ecs_component.gd` | Already `BaseECSComponent` | eb0fadc |
| `ecs_system.gd` | `base_ecs_system.gd` | Already `BaseECSSystem` | eb0fadc |
| `ecs_entity.gd` | `base_ecs_entity.gd` | `ECSEntity` → `BaseECSEntity` | eb0fadc |

**References Updated:**
- Production: `base_volume_controller.gd`, `u_ecs_utils.gd`
- Templates: `player_template.tscn`, `camera_template.tscn`
- Tests: 10 files
- Docs: 14 files
- **Total:** 31 files changed

---

### ⏳ Batch 2: Utilities & Event Bus (3 files) - PENDING

| Old Filename | New Filename | Class Name Change | Impact |
|--------------|--------------|-------------------|--------|
| `base_event_bus.gd` | `base_event_bus.gd` | `BaseEventBus` → `BaseEventBus` | 2 extends |
| `u_entity_query.gd` | `u_u_entity_query.gd` | `U_EntityQuery` → `U_U_EntityQuery` | 3+ uses |
| `u_analog_stick_repeater.gd` | `u_u_analog_stick_repeater.gd` | `U_AnalogStickRepeater` → `U_U_AnalogStickRepeater` | 4 uses |

**Estimated References:** ~10-15 files

---

### ⏳ Batch 3: Transitions (3 files) - PENDING

| Old Filename | New Filename | Class Name Change | Impact |
|--------------|--------------|-------------------|--------|
| `fade_transition.gd` | `trans_fade.gd` | `FadeTransition` → `Trans_Fade` | 2 uses |
| `loading_screen_transition.gd` | `trans_loading_screen.gd` | `LoadingScreenTransition` → `Trans_LoadingScreen` | 2 uses |
| `instant_transition.gd` | `trans_instant.gd` | `InstantTransition` → `Trans_Instant` | 2 uses |

**Primary file to update:** `m_scene_manager.gd`
**Estimated References:** ~6-8 files

---

### ⏳ Batch 4: Newly Discovered Files (2 files) - PENDING

| Old Filename | New Filename | Class Name Change | Location | Impact |
|--------------|--------------|-------------------|----------|--------|
| `endgame_goal_zone.gd` | `e_endgame_goal_zone.gd` | Add `E_EndgameGoalZone` | `scripts/gameplay/` | Scene-attached |
| `test_root_loader.gd` | **DECISION NEEDED** | TBD | `scripts/` (root) | Check purpose first |

**Options for test_root_loader.gd:**
- Option A: Move to `tests/helpers/test_root_loader.gd` (if test utility)
- Option B: Rename to `scripts/utils/u_test_root_loader.gd` with class `U_TestRootLoader` (if production)

**Estimated References:** ~5-10 files

---

### ⏳ Batch 5: Marker Scripts (16 files) - PENDING

All in `scripts/scene_structure/` - Add `marker_` prefix:

| Old Filename | New Filename | Scene Attachments |
|--------------|--------------|-------------------|
| `main_root_node.gd` | `marker_main_root_node.gd` | 4 scenes |
| `entities_group.gd` | `marker_entities_group.gd` | 4 scenes |
| `systems_core_group.gd` | `marker_systems_core_group.gd` | 4 scenes |
| `systems_physics_group.gd` | `marker_systems_physics_group.gd` | 4 scenes |
| `systems_movement_group.gd` | `marker_systems_movement_group.gd` | 4 scenes |
| `systems_feedback_group.gd` | `marker_systems_feedback_group.gd` | 4 scenes |
| `systems_group.gd` | `marker_systems_group.gd` | 4 scenes |
| `managers_group.gd` | `marker_managers_group.gd` | 4 scenes |
| `components_group.gd` | `marker_components_group.gd` | 4 scenes |
| `scene_objects_group.gd` | `marker_scene_objects_group.gd` | 4 scenes |
| `environment_group.gd` | `marker_environment_group.gd` | 4 scenes |
| `active_scene_container.gd` | `marker_active_scene_container.gd` | 1 scene |
| `ui_overlay_stack.gd` | `marker_ui_overlay_stack.gd` | 1 scene |
| `transition_overlay.gd` | `marker_transition_overlay.gd` | 1 scene |
| `spawn_points_group.gd` | `marker_spawn_points_group.gd` | 3 scenes |
| `sp_spawn_points.gd` | `marker_sp_spawn_points.gd` | 0 scenes |

**No class_name declarations** - only scene attachments to update.

**Scenes to update:**
- `root.tscn` (3 marker attachments)
- `gameplay_base.tscn` (4 marker attachments)
- `gameplay_exterior.tscn` (4 marker attachments)
- `gameplay_interior_house.tscn` (4 marker attachments)

**Estimated References:** ~15-20 scene files only

---

## Already Correct Files (6 files)

These files already follow the `base_` prefix pattern and should be **removed from exception lists**:

| Filename | Class Name | Location | Notes |
|----------|------------|----------|-------|
| `base_panel.gd` | `BasePanel` | `scripts/ui/base/` | ✅ Already correct |
| `base_menu_screen.gd` | `BaseMenuScreen` | `scripts/ui/base/` | ✅ Already correct |
| `base_overlay.gd` | `BaseOverlay` | `scripts/ui/base/` | ✅ Already correct |
| `base_volume_controller.gd` | `BaseVolumeController` | `scripts/gameplay/` | ✅ Already correct |
| `base_interactable_controller.gd` | `BaseInteractableController` | `scripts/gameplay/` | ✅ Already correct |
| `base_transition_effect.gd` | `BaseTransitionEffect` | `scripts/scene_management/transitions/` | ✅ Already correct |

---

## Permanent Exceptions (1 file)

This file should **remain** in exception list (documented interface pattern):

| Filename | Class Name | Pattern | Notes |
|----------|------------|---------|-------|
| `i_scene_contract.gd` | `I_SCENE_CONTRACT` | Interface (`i_`) | ✅ Documented in STYLE_GUIDE.md line 200 |

---

## Final Documentation Updates (After All Batches)

### 1. STYLE_GUIDE.md Updates

**Add new prefix patterns to matrix:**
```markdown
| **Marker Scripts** | `marker_*.gd` | No class_name | `marker_entities_group.gd`, `marker_main_root_node.gd` |
| **Transition Effects** | `trans_*.gd` | `Trans_*` | `trans_fade.gd` → `Trans_Fade` |
| **Base Classes** | `base_*.gd` | `Base*` | `base_panel.gd`, `base_ecs_component.gd` |
```

**Update "Documented Exceptions" table:**
- Remove: All base class exceptions (now following `base_` pattern)
- Remove: All marker script exceptions (now following `marker_` pattern)
- Remove: All transition exceptions (now following `trans_` pattern)
- Remove: All utility exceptions (now following `u_` pattern)
- Keep: `i_scene_contract.gd` (interface pattern)

### 2. test_style_enforcement.gd Updates

**Delete these exception constants:**
```gdscript
const BASE_CLASS_EXCEPTIONS := [...]        # DELETE
const MARKER_SCRIPT_EXCEPTIONS := [...]     # DELETE
const EVENT_BUS_EXCEPTIONS := [...]         # DELETE
const UTILITY_EXCEPTIONS := [...]           # DELETE
const TRANSITION_EXCEPTIONS := [...]        # DELETE
```

**Keep only:**
```gdscript
const INTERFACE_EXCEPTIONS := [
    "i_scene_contract.gd"  # Documented interface pattern
]
```

**Update SCRIPT_PREFIX_RULES:**
```gdscript
const SCRIPT_PREFIX_RULES := {
    "res://scripts/managers": ["m_"],
    "res://scripts/ecs/systems": ["s_", "m_"],
    "res://scripts/ecs/components": ["c_"],
    "res://scripts/ecs/resources": ["rs_"],
    "res://scripts/ecs": ["base_"],  # NEW: base_ecs_*.gd
    "res://scripts/state/actions": ["u_"],
    "res://scripts/state/reducers": ["u_"],
    "res://scripts/state/selectors": ["u_"],
    "res://scripts/state/resources": ["rs_"],
    "res://scripts/state": ["u_", "m_"],
    "res://scripts/ui/resources": ["rs_"],
    "res://scripts/ui/base": ["base_"],  # NEW
    "res://scripts/ui/utils": ["u_"],  # NEW
    "res://scripts/ui": ["ui_", "u_"],
    "res://scripts/gameplay": ["e_", "endgame_", "base_"],  # NEW: base_
    "res://scripts/scene_structure": ["marker_"],  # CHANGED: from []
    "res://scripts/scene_management/transitions": ["trans_", "base_"],  # NEW
    "res://scripts/events": ["base_"],  # NEW
}
```

**Simplify _is_exception():**
```gdscript
func _is_exception(filename: String) -> bool:
    return (
        filename in INTERFACE_EXCEPTIONS or
        filename.begins_with("test_")
    )
```

### 3. AGENTS.md Updates

Update "Naming Conventions Quick Reference" (lines 89-103):
- Add `marker_` prefix for marker scripts
- Add `trans_` prefix for transition effects
- Update references from `ecs_component.gd` → `base_ecs_component.gd`

### 4. Task Tracking Updates

**style-scene-cleanup-tasks.md:**
- Add Phase 4B section: "Exception Elimination"
- Mark T040-T043 as complete
- Add T044-T048 for exception elimination batches

**style-scene-cleanup-continuation-prompt.md:**
- Update status to "Phase 4B - Exception Elimination Complete"
- Note: 100% prefix compliance achieved

---

## Summary Statistics

**Total Files to Rename:** 30
- ✅ Batch 1 Complete: 3 files (ECS base classes)
- ⏳ Batch 2 Pending: 3 files (utilities & event bus)
- ⏳ Batch 3 Pending: 3 files (transitions)
- ⏳ Batch 4 Pending: 2 files (newly discovered)
- ⏳ Batch 5 Pending: 16 files (marker scripts)
- ℹ️ Already Correct: 6 files (remove from exceptions)
- ℹ️ Permanent Exception: 1 file (interface pattern)

**References to Update:** ~100-120 total
- ✅ Batch 1: 31 files updated
- ⏳ Remaining: ~70-90 files

**Final Outcome:**
- 🎯 100% prefix compliance (excluding documented interface pattern)
- 🗑️ Exception lists reduced to 1 entry (interface pattern)
- ✨ All production code follows documented naming conventions
