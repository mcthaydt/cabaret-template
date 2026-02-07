# ECS Overlay Testing Guide

**Created**: 2025-12-28
**Purpose**: Comprehensive testing checklist for Debug Manager ECS Overlay (F2)

## Quick Test (2 minutes)

**Scene**: `gameplay_base.tscn`

1. ✅ **Launch game** → Press Play
2. ✅ **Open overlay** → Press `F2`
3. ✅ **Verify entity list** → Should show "E_Player" and other entities
4. ✅ **Click entity** → Select "E_Player" from list
5. ✅ **Verify components** → Should show C_MovementComponent, C_JumpComponent, etc.
6. ✅ **Check systems** → Should show S_InputSystem, S_MovementSystem, etc.
7. ✅ **Close overlay** → Press `F2` again or click X button

**Expected**: No errors in console, all panels populate correctly

---

## Full Test Suite (10 minutes)

### Test 1: Entity Browser

**Setup**: Load `gameplay_base.tscn`, press F2

| Test | Action | Expected Result | Status |
|------|--------|----------------|--------|
| 1.1 | Overlay opens | 3-panel layout visible, no errors | ⬜ |
| 1.2 | Entity list populates | Shows E_Player and other entities | ⬜ |
| 1.3 | Pagination (if >50 entities) | Page 1 of N displayed, prev disabled | ⬜ |
| 1.4 | Next page button (if applicable) | Advances to page 2, shows next 50 | ⬜ |
| 1.5 | Prev page button | Returns to page 1, prev disabled | ⬜ |

**Bugs to watch for**:
- ❌ "Nonexistent function" errors
- ❌ "Cannot infer type" errors
- ❌ Empty entity list when entities exist

---

### Test 2: Entity Filtering

**Setup**: F2 open, entity list visible

| Test | Action | Expected Result | Status |
|------|--------|----------------|--------|
| 2.1 | Tag filter: type "player" | Only entities with "player" tag shown | ⬜ |
| 2.2 | Clear tag filter | All entities shown again | ⬜ |
| 2.3 | Component filter: select C_MovementComponent | Only entities with movement component | ⬜ |
| 2.4 | Component filter: select (All Components) | All entities shown again | ⬜ |
| 2.5 | Clear Filters button | Resets both filters | ⬜ |
| 2.6 | Tag + Component combined | Shows intersection (both conditions) | ⬜ |

**Bugs to watch for**:
- ❌ Filter crashes with "get_components_for_entity" error
- ❌ Component dropdown empty
- ❌ Filter doesn't reset properly

---

### Test 3: Component Inspector

**Setup**: F2 open, click on E_Player entity

| Test | Action | Expected Result | Status |
|------|--------|----------------|--------|
| 3.1 | Select entity | "Entity: E_Player" label updates | ⬜ |
| 3.2 | Components list | Shows all components (Movement, Jump, etc.) | ⬜ |
| 3.3 | Component properties | Shows exported properties only | ⬜ |
| 3.4 | Property values | Shows current values (not "null" or errors) | ⬜ |
| 3.5 | Live updates | Values change when player moves (throttled 100ms) | ⬜ |
| 3.6 | Select different entity | Inspector updates to new entity | ⬜ |

**Bugs to watch for**:
- ❌ "Trying to assign Object to Array" error
- ❌ Shows private properties (starts with `_`)
- ❌ Shows "script" or internal properties
- ❌ Crashes on entity with no components

---

### Test 4: System Execution View

**Setup**: F2 open, system list visible on right

| Test | Action | Expected Result | Status |
|------|--------|----------------|--------|
| 4.1 | System list populates | Shows all systems (Input, Movement, etc.) | ⬜ |
| 4.2 | Priority display | Shows "(Priority: N)" for each system | ⬜ |
| 4.3 | Enabled state icons | Shows ✓ for enabled, ✗ for disabled | ⬜ |
| 4.4 | Systems sorted by priority | Lower priority first (0, 10, 20...) | ⬜ |
| 4.5 | Select system | "Selected System" label updates | ⬜ |
| 4.6 | Enable/disable checkbox | Checkbox state matches system state | ⬜ |
| 4.7 | Toggle system off | Checkbox works, icon changes to ✗ | ⬜ |
| 4.8 | Toggle system on | Checkbox works, icon changes to ✓ | ⬜ |

**Bugs to watch for**:
- ❌ "Nonexistent function 'get_priority'" error
- ❌ Systems not sorted correctly
- ❌ Checkbox doesn't affect system execution
- ❌ Icons don't match actual state

---

### Test 5: Performance & Edge Cases

**Setup**: F2 open

| Test | Action | Expected Result | Status |
|------|--------|----------------|--------|
| 5.1 | Rapid entity selection | No lag, throttled updates work | ⬜ |
| 5.2 | Scene transition (Ctrl+R) | No errors, overlay closes | ⬜ |
| 5.3 | Reopen after transition | Overlay rebuilds list, no crashes | ⬜ |
| 5.4 | Pause game (Esc) | Overlay continues updating (PROCESS_MODE_ALWAYS) | ⬜ |
| 5.5 | Toggle F2 rapidly (5x fast) | No errors, debouncing works | ⬜ |
| 5.6 | Scene with 100+ entities | Pagination works, no freeze | ⬜ |

**Bugs to watch for**:
- ❌ UI freeze during scene load
- ❌ "Instance invalid" errors after transition
- ❌ Event subscriptions not cleaned up
- ❌ Memory leaks from orphaned labels

---

## Known Issues (Fixed)

### Issue History
| Bug | Symptom | Fix | Commit |
|-----|---------|-----|--------|
| get_all_components() | Crash on overlay open | Iterate entities instead | 425bbbf |
| get_components_for_entity(entity_id) | Wrong parameter type | Use entity node, not ID | 425bbbf |
| Type inference | Parse errors | Add explicit type hints | 031494c |
| get_priority() | Runtime crash | Use execution_priority property | e54ef5f |
| Array type assignment | Component inspector crash | Remove type annotation | (pending) |

---

## Regression Test Checklist

**Run after any changes to**:
- `debug_ecs_overlay.gd` (controller)
- `debug_ecs_overlay.tscn` (scene)
- `base_ecs_system.gd` (system base class)
- `m_ecs_manager.gd` (ECS manager)

**Quick Regression** (1 minute):
1. ✅ Press F2 → Overlay opens
2. ✅ Click entity → Inspector shows components
3. ✅ Click system → Checkbox enables
4. ✅ Press F2 → Overlay closes

**Full Regression** (10 minutes):
Run all tests in Full Test Suite above.

---

## Automated Testing (Future)

**Recommended additions**:

1. **Unit tests** (`tests/unit/debug/test_debug_ecs_overlay.gd`):
   ```gdscript
   # Test entity filtering logic
   func test_apply_filters_by_tag():
       var overlay = SC_DebugECSOverlay.new()
       overlay._active_tag_filter = "player"
       # Assert only player entities returned
   ```

2. **Integration tests** (`tests/integration/debug/test_ecs_overlay_integration.gd`):
   ```gdscript
   # Test full overlay lifecycle
   func test_overlay_open_close():
       var scene = load("res://gameplay_base.tscn").instantiate()
       add_child(scene)
       # Simulate F2 press
       # Verify overlay opens without errors
   ```

3. **Visual regression tests**:
   - Take screenshots of overlay in known states
   - Compare after changes to detect UI breakage

---

## Common Error Patterns

### GDScript Strict Typing Issues

**Problem**: `Cannot infer type of variable`
```gdscript
# ❌ FAILS - Godot can't infer type
var property_list := component.get_property_list()

# ✅ WORKS - Explicit type
var property_list: Array = component.get_property_list()
```

**Problem**: `Trying to assign Object to Array`
```gdscript
# ❌ FAILS - Dictionary lookup returns Variant
var components_array: Array = components_dict[key]

# ✅ WORKS - No type annotation
var components_array = components_dict[key]
if components_array is Array:
    # Use it safely
```

### API Misuse

**Problem**: `Nonexistent function 'get_priority'`
```gdscript
# ❌ FAILS - Method doesn't exist
system.get_priority()

# ✅ WORKS - It's a property
system.execution_priority
```

**Problem**: `get_components_for_entity expects Node`
```gdscript
# ❌ FAILS - StringName parameter
var components = manager.get_components_for_entity(entity_id)

# ✅ WORKS - Node parameter
var entity = manager.get_entity_by_id(entity_id)
var components = manager.get_components_for_entity(entity)
```

---

## Test Data Requirements

**Minimum viable scene**:
- ✅ At least 1 entity (E_Player)
- ✅ At least 3 components on player
- ✅ At least 5 systems registered
- ✅ M_ECSManager present

**Ideal test scene**:
- ✅ 10-20 entities with various component combinations
- ✅ Entities with tags ("player", "enemy", "prop")
- ✅ Entities with 0 components (edge case)
- ✅ Entities with 10+ components (stress test)
- ✅ 15+ systems with varying priorities

**Use**: `gameplay_base.tscn` meets minimum requirements ✅

---

## Manual Testing Workflow

1. **Before committing changes**:
   - ✅ Run Quick Test (2 min)
   - ✅ Check console for errors
   - ✅ Test your specific change

2. **Before pushing to main**:
   - ✅ Run Full Test Suite (10 min)
   - ✅ Test on clean scene load
   - ✅ Test after scene transition

3. **After merging**:
   - ✅ Regression test on multiple scenes
   - ✅ Verify no performance degradation

---

## Success Criteria

**Phase 4 is complete when**:
- ✅ All Quick Test items pass
- ✅ All Full Test Suite items pass
- ✅ No console errors during normal use
- ✅ Overlay works after scene transitions
- ✅ Performance acceptable (no UI freezes)

**Current Status**: 🚧 In Progress (fixing Array type assignment bug)
