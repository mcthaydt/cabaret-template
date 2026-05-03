# LLM-First Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Patch documentation and enforcement gaps that reduce LLM effectiveness when working with this template.

**Architecture:** Three focus areas: (1) documentation consistency for reliable retrieval, (2) explicit decision rules for LLM routing, (3) automated enforcement to catch mistakes before commit.

**Tech Stack:** Godot 4.7, GDScript, GUT testing, git hooks, Markdown documentation.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `docs/architecture/adr/0001-channel-taxonomy.md` | Modify | Add decision rules flowchart for communication layer choices |
| `docs/guides/STYLE_GUIDE.md` | Modify | Fix version references (4.6.1 → 4.7) |
| `docs/architecture/adr/README.md` | Modify | Complete ADR table with missing links |
| `project.godot` | Verify | Confirm version consistency |
| `AGENTS.md` | Modify | Update environment section with correct Godot version |
| `scripts/tests/style/test_core_imports.gd` | Modify | Strengthen core/demo firewall with better error messages |
| `docs/systems/ecs/ecs_architecture.md` | Modify | Add Jolt Physics dependency note |
| `docs/guides/pitfalls/GODOT_ENGINE.md` | Modify | Add Jolt Physics export checklist |
| `docs/_templates/redux-slice-template.md` | Create | Redux boilerplate templates for LLMs |
| `tools/pre-commit-hooks/validate-imports.sh` | Create | Pre-commit hook for core/demo import validation |
| `docs/superpowers/llm-decision-trees.md` | Create | Central decision tree reference for LLMs |

---

### Task 1: Fix Version Consistency

**Files:**
- Modify: `docs/guides/STYLE_GUIDE.md`
- Modify: `AGENTS.md`
- Verify: `project.godot`

- [ ] **Step 1: Read current version references**

```bash
grep -r "4\.6" docs/guides/STYLE_GUIDE.md AGENTS.md project.godot
```

- [x] **Step 2: Update STYLE_GUIDE.md**

Completed in Task 1.

- [ ] **Step 3: Update AGENTS.md**

Read `AGENTS.md` ENVIRONMENT section, update:
```markdown
- Engine: Godot 4.7 stable.
+ Engine: Godot 4.7 stable.
```

- [ ] **Step 4: Verify project.godot**

Confirm `project.godot` line 15 reads:
```
config/features=PackedStringArray("4.7", "Forward Plus")
```

- [ ] **Step 5: Commit**

```bash
git add docs/guides/STYLE_GUIDE.md AGENTS.md
git commit -m "docs: fix version consistency (4.6 → 4.7)"
```

---

### Task 2: Complete ADR Table

**Files:**
- Modify: `docs/architecture/adr/README.md`

- [ ] **Step 1: Read current ADR table**

Read `docs/architecture/adr/README.md` lines 1-20.

- [ ] **Step 2: Verify missing ADR files exist**

```bash
ls docs/architecture/adr/0003-ecs-node-based.md
ls docs/architecture/adr/0005-service-locator.md
ls docs/architecture/adr/0011-builder-pattern-taxonomy.md
```

- [ ] **Step 3: Update table with missing entries**

Add to table (after line 11, before line 12):
```markdown
| [0003-ecs-node-based.md](0003-ecs-node-based.md) | Accepted | ECS is implemented with Godot nodes for authoring and scene-tree integration. |
| [0005-service-locator.md](0005-service-locator.md) | Accepted, amended | Managers register explicitly through ServiceLocator; tests isolate scopes; no manager autoloads. |
| [0011-builder-pattern-taxonomy.md](0011-builder-pattern-taxonomy.md) | Accepted | Three builder patterns: static (pure factory), declarative/fluent (optional-field accumulation + `.build()`), helper (procedural orchestrator, not a builder). |
```

- [ ] **Step 4: Verify all ADR links resolve**

```bash
cd docs/architecture/adr && for f in *.md; do grep -q "$f" README.md || echo "Missing: $f"; done
```

- [ ] **Step 5: Commit**

```bash
git add docs/architecture/adr/README.md
git commit -m "docs: complete ADR table with missing entries"
```

---

### Task 3: Add Communication Decision Rules

**Files:**
- Modify: `docs/architecture/adr/0001-channel-taxonomy.md`
- Create: `docs/superpowers/llm-decision-trees.md`

- [ ] **Step 1: Read current channel taxonomy doc**

Read `docs/architecture/adr/0001-channel-taxonomy.md` in full.

- [ ] **Step 2: Add decision rules section**

Append to `docs/architecture/adr/0001-channel-taxonomy.md`:

```markdown
## Decision Rules (for LLMs)

When writing code that communicates across boundaries, use this decision tree:

```
Need to communicate X?
├─ ECS component → ECS system?
│  └─ Use component data directly via query. NO event, NO signal.
│
├─ ECS component → Another ECS component?
│  └─ Publish event via `U_ECSEventBus`.
│     Example: `U_ECSEventBus.publish("health_changed", {"entity": id, "new_value": hp})`
│
├─ ECS component/system → Manager?
│  └─ Dispatch Redux action. NEVER direct call.
│     Example: `store.dispatch(U_GameplayActions.player_damaged(amount))`
│
├─ Manager → Manager?
│  └─ Direct method call via ServiceLocator.
│     Example: `var cam = U_ServiceLocator.get("M_CameraManager")`
│
├─ Manager → UI?
│  └─ Allow-listed signal ONLY. See appendix for allowed signals.
│     Example: `M_SceneManager.scene_loaded.connect(UI_PauseMenu.on_scene_ready)`
│
├─ UI → Manager?
│  └─ Dispatch Redux action. NEVER direct call.
│     Example: `store.dispatch(U_MenuActions.request_scene_transition("gameplay_base"))`
│
├─ UI → UI (same screen)?
│  └─ Direct method call or signals within same screen.
│
├─ UI → UI (different screen)?
│  └─ Redux action → Manager → Signal → Target UI. NEVER direct call.
│
└─ Everything else?
   └─ Direct method call.
```

## Quick Reference Table

| Source | Target | Mechanism | Example |
|--------|--------|-----------|---------|
| ECS Component | ECS System | Direct query | `get_components("C_MovementComponent")` |
| ECS Component | ECS Component | Event bus | `U_ECSEventBus.publish("damage_taken", payload)` |
| ECS System | Manager | Redux action | `store.dispatch(U_GameplayActions.spawn_entity(id))` |
| Manager | Manager | ServiceLocator + method call | `locator.get("M_CameraManager").blend_to(target)` |
| Manager | UI | Allow-listed signal | `scene_loaded.connect(on_scene_ready)` |
| UI | Manager | Redux action | `store.dispatch(U_MenuActions.open_overlay("pause"))` |
| UI | UI (same) | Direct call / signal | `pause_menu.hide()` |
| UI | UI (different) | Redux → Manager → Signal | `store.dispatch(...)` → manager emits → target listens |

**Forbidden Patterns:**
- ❌ ECS component calling manager method directly
- ❌ UI screen calling manager method directly
- ❌ Manager publishing ECS events (only `M_ECSManager` may publish lifecycle events)
- ❌ Cross-screen UI direct calls

```

- [ ] **Step 3: Create central decision tree doc**

Create `docs/superpowers/llm-decision-trees.md`:

```markdown
# LLM Decision Trees

Quick reference for common "which pattern do I use?" questions.

## Communication Channel Selection

See `docs/architecture/adr/0001-channel-taxonomy.md#decision-rules-for-llms`

## When to Use Redux vs Local State

```
Need to store state X?
├─ Accessed by multiple scenes?
│  └─ Redux (M_StateStore)
│
├─ Persists across scene transitions?
│  └─ Redux (M_StateStore)
│
├─ Debug overlay / dev tools need to inspect it?
│  └─ Redux (M_StateStore)
│
├─ UI needs to react to changes?
│  └─ Redux (M_StateStore)
│
└─ Scene-local, temporary, or performance-critical?
   └─ Local state (component variable)
```

## When to Use ECS vs Scene Nodes

```
Need gameplay logic X?
├─ Runs every frame on many entities?
│  └─ ECS System
│
├─ Data queried/modified by multiple systems?
│  └─ ECS Component
│
├─ Single-entity, scene-specific behavior?
│  └─ Scene node script (not ECS)
│
└─ Visual/audio/particle effect?
   └─ Scene node + Feedback System
```

## Builder Pattern Selection

```
Need to create X programmatically?
├─ Pure data transformation, no state?
│  └─ Static builder (U_FooBuilder.create())
│
├─ Fluent API with optional fields?
│  └─ Declarative builder (.with_x().with_y().build())
│
└─ Procedural orchestration, multiple steps?
   └─ Helper (U_FooHelper.generate()) - NOT a builder
```

```

- [ ] **Step 4: Commit**

```bash
git add docs/architecture/adr/0001-channel-taxonomy.md docs/superpowers/llm-decision-trees.md
git commit -m "docs: add LLM decision trees for communication patterns"
```

---

### Task 4: Strengthen Core/Demo Firewall

**Files:**
- Modify: `tests/unit/style/test_core_imports.gd`
- Create: `tools/pre-commit-hooks/validate-imports.sh`

- [ ] **Step 1: Read current import tests**

Read `tests/unit/style/test_core_imports.gd` in full.

- [ ] **Step 2: Enhance error messages**

Modify test functions to include explicit forbidden path lists:

```gdscript
func test_core_scripts_never_import_from_demo() -> void:
    var core_scripts = _get_scripts_in_directory("res://scripts/core")
    var forbidden_patterns = [
        "res://scripts/demo/",
        "res://scenes/demo/",
        "res://resources/demo/"
    ]
    
    for script_path in core_scripts:
        var content = _read_script_content(script_path)
        for pattern in forbidden_patterns:
            if pattern in content:
                push_error("CORE_IMPORT_VIOLATION: %s imports from %s. Core must not depend on demo." % [script_path, pattern])
                assert(false, "Core script imports demo: %s" % script_path)
```

- [ ] **Step 3: Create pre-commit hook script**

Create `tools/pre-commit-hooks/validate-imports.sh`:

```bash
#!/bin/bash
# Pre-commit hook: Validate core/demo separation
# Usage: tools/pre-commit-hooks/validate-imports.sh

set -e

echo "🔍 Validating core/demo import separation..."

# Find all modified .gd files
MODIFIED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$' || true)

if [ -z "$MODIFIED_FILES" ]; then
    echo "✅ No GDScript files staged for commit"
    exit 0
fi

VIOLATIONS=0

for file in $MODIFIED_FILES; do
    # Check if file is in core directory
    if [[ "$file" == scripts/core/* ]]; then
        # Check for demo imports
        if grep -q "res://scripts/demo/" "$file" || \
           grep -q "res://scenes/demo/" "$file" || \
           grep -q "res://resources/demo/" "$file"; then
            echo "❌ CORE_IMPORT_VIOLATION: $file imports from demo/"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi
done

if [ $VIOLATIONS -gt 0 ]; then
    echo ""
    echo "🚫 Found $VIOLATION(S) core/demo import violations."
    echo "   Core scripts (scripts/core/) must not import from demo/ paths."
    echo ""
    echo "   Fix the violations and try again, or use --no-verify to bypass (not recommended)."
    exit 1
fi

echo "✅ Core/demo import validation passed"
exit 0
```

- [ ] **Step 4: Make hook executable**

```bash
chmod +x tools/pre-commit-hooks/validate-imports.sh
```

- [ ] **Step 5: Document hook installation**

Add to `README.md` Testing section:

```markdown
### Pre-commit Hooks (Optional)

Install the pre-commit hook for import validation:

```bash
ln -s ../../tools/pre-commit-hooks/validate-imports.sh .git/hooks/pre-commit
```

This blocks commits with core/demo import violations before they reach CI.
```

- [ ] **Step 6: Run tests to verify**

```bash
tools/run_gut_suite.sh -gdir=res://tests/unit/style
```

- [ ] **Step 7: Commit**

```bash
git add tests/unit/style/test_core_imports.gd tools/pre-commit-hooks/validate-imports.sh README.md
git commit -m "test: strengthen core/demo firewall with pre-commit hook"
```

---

### Task 5: Add Jolt Physics Documentation

**Files:**
- Modify: `docs/systems/ecs/ecs_architecture.md`
- Modify: `docs/guides/pitfalls/GODOT_ENGINE.md`

- [ ] **Step 1: Read current ECS architecture doc**

Read `docs/systems/ecs/ecs_architecture.md` to find physics references.

- [ ] **Step 2: Add Jolt note to ECS doc**

Append to `docs/systems/ecs/ecs_architecture.md` (Dependencies section):

```markdown
## Physics Engine Dependency

This template uses **Jolt Physics** via the Godot Jolt addon (`addons/godot-jolt`).

**Configuration:** `project.godot` line 235:
```ini
[physics]
3d/physics_engine="Jolt Physics"
```

**For LLMs:** If generating physics-related code, assume Jolt Physics is active. Do not suggest Godot Physics-specific features unless marked as optional.

**Export Checklist:**
- ✅ `addons/godot-jolt/` must be included in export presets
- ✅ Jolt shared libraries must be packaged for target platform
- ✅ Fallback to Godot Physics requires `project.godot` change + testing
```

- [ ] **Step 3: Read GODOT_ENGINE.md pitfalls**

Read `docs/guides/pitfalls/GODOT_ENGINE.md` in full.

- [ ] **Step 4: Add Jolt export section**

Append to `docs/guides/pitfalls/GODOT_ENGINE.md`:

```markdown
## Jolt Physics Export Checklist

When preparing builds for release:

1. **Verify addon inclusion:**
   - Export → Resources → Include Filters: `*godot-jolt*`
   - Or manually copy `addons/godot-jolt/` to export directory

2. **Platform-specific libraries:**
   - Windows: `godot-jolt_64.dll`
   - macOS: `libgodot-jolt.macos.dylib`
   - Linux: `libgodot-jolt.linux.so`
   - Web: `godot-jolt.wasm` (if using web export)

3. **Test physics after export:**
   - Run exported build
   - Verify collision detection works
   - Check ragdoll/constraint behavior

4. **Fallback option:**
   If Jolt causes issues, temporarily switch to Godot Physics:
   ```ini
   [physics]
   3d/physics_engine="Godot Physics"
   ```
   **Warning:** Requires retesting all physics interactions.
```

- [ ] **Step 5: Commit**

```bash
git add docs/systems/ecs/ecs_architecture.md docs/guides/pitfalls/GODOT_ENGINE.md
git commit -m "docs: add Jolt Physics dependency and export notes"
```

---

### Task 6: Create Redux Boilerplate Templates

**Files:**
- Create: `docs/_templates/redux-slice-template.md`

- [ ] **Step 1: Study existing Redux patterns**

Read these files to understand current patterns:
- `scripts/state/actions/u_gameplay_actions.gd`
- `scripts/state/reducers/u_gameplay_reducer.gd`
- `scripts/state/selectors/u_gameplay_selectors.gd`

- [ ] **Step 2: Create template document**

Create `docs/_templates/redux-slice-template.md`:

```markdown
# Redux Slice Template

Use this template when adding a new state slice (e.g., inventory, quests, dialogue).

## File Structure

```
scripts/
├── state/
│   ├── actions/
│   │   └── u_<slice>_actions.gd
│   ├── reducers/
│   │   └── u_<slice>_reducer.gd
│   └── selectors/
│       └── u_<slice>_selectors.gd
resources/
└── core/
    └── state/
        └── cfg_<slice>_initial_state.tres
```

---

## Step 1: Define Initial State

**File:** `resources/core/state/cfg_<slice>_initial_state.tres`

```gdscript
# cfg_inventory_initial_state.tres
{
  "items": [],
  "gold": 0,
  "inventory_open": false
}
```

---

## Step 2: Create Actions

**File:** `scripts/state/actions/u_<slice>_actions.gd`

```gdscript
# u_inventory_actions.gd
class_name U_InventoryActions

static func add_item(item_id: String, quantity: int = 1) -> Dictionary:
    return {
        "type": "inventory/add_item",
        "payload": {"item_id": item_id, "quantity": quantity}
    }

static func remove_item(item_id: String, quantity: int = 1) -> Dictionary:
    return {
        "type": "inventory/remove_item",
        "payload": {"item_id": item_id, "quantity": quantity}
    }

static func set_gold(amount: int) -> Dictionary:
    return {
        "type": "inventory/set_gold",
        "payload": {"amount": amount}
    }

static func toggle_inventory() -> Dictionary:
    return {
        "type": "inventory/toggle_inventory",
        "payload": null
    }
```

---

## Step 3: Create Reducer

**File:** `scripts/state/reducers/u_<slice>_reducer.gd`

```gdscript
# u_inventory_reducer.gd
class_name U_InventoryReducer

static func handle(state: Dictionary, action: Dictionary) -> Dictionary:
    match action.get("type"):
        "inventory/add_item":
            return _add_item(state, action.payload)
        "inventory/remove_item":
            return _remove_item(state, action.payload)
        "inventory/set_gold":
            return _set_gold(state, action.payload)
        "inventory/toggle_inventory":
            return _toggle_inventory(state)
        _:
            return state

static func _add_item(state: Dictionary, payload: Dictionary) -> Dictionary:
    var new_state = state.duplicate(true)
    var item_id = payload.item_id
    var quantity = payload.quantity
    
    # Find existing item or add new
    var found = false
    for i in range(new_state.items.size()):
        if new_state.items[i].item_id == item_id:
            new_state.items[i].quantity += quantity
            found = true
            break
    
    if not found:
        new_state.items.append({"item_id": item_id, "quantity": quantity})
    
    return new_state

static func _remove_item(state: Dictionary, payload: Dictionary) -> Dictionary:
    var new_state = state.duplicate(true)
    var item_id = payload.item_id
    var quantity = payload.quantity
    
    for i in range(new_state.items.size()):
        if new_state.items[i].item_id == item_id:
            new_state.items[i].quantity -= quantity
            if new_state.items[i].quantity <= 0:
                new_state.items.remove_at(i)
            break
    
    return new_state

static func _set_gold(state: Dictionary, payload: Dictionary) -> Dictionary:
    var new_state = state.duplicate(true)
    new_state.gold = payload.amount
    return new_state

static func _toggle_inventory(state: Dictionary) -> Dictionary:
    var new_state = state.duplicate(true)
    new_state.inventory_open = not new_state.inventory_open
    return new_state
```

---

## Step 4: Create Selectors

**File:** `scripts/state/selectors/u_<slice>_selectors.gd`

```gdscript
# u_inventory_selectors.gd
class_name U_InventorySelectors

static func get_inventory(state: Dictionary) -> Array:
    return state.get("items", [])

static func get_item_quantity(state: Dictionary, item_id: String) -> int:
    var items = state.get("items", [])
    for item in items:
        if item.item_id == item_id:
            return item.quantity
    return 0

static func get_gold(state: Dictionary) -> int:
    return state.get("gold", 0)

static func is_inventory_open(state: Dictionary) -> bool:
    return state.get("inventory_open", false)

static func has_item(state: Dictionary, item_id: String, min_quantity: int = 1) -> bool:
    return get_item_quantity(state, item_id) >= min_quantity
```

---

## Step 5: Register Slice

**File:** `scripts/state/m_state_store.gd`

Add to `_ready()`:

```gdscript
# In M_StateStore._ready():
register_slice("inventory", cfg_inventory_initial_state, U_InventoryReducer.handle)
```

---

## Step 6: Write Tests

**File:** `tests/unit/state/test_u_inventory_reducer.gd`

```gdscript
class_name TestUInventoryReducer
extends GutTest

func test_add_item_to_empty_inventory() -> void:
    var initial_state = {"items": [], "gold": 0, "inventory_open": false}
    var action = U_InventoryActions.add_item("sword", 1)
    var result = U_InventoryReducer.handle(initial_state, action)
    
    assert_eq(result.items.size(), 1)
    assert_eq(result.items[0].item_id, "sword")
    assert_eq(result.items[0].quantity, 1)

func test_add_item_stacks_quantity() -> void:
    var initial_state = {
        "items": [{"item_id": "sword", "quantity": 1}],
        "gold": 0,
        "inventory_open": false
    }
    var action = U_InventoryActions.add_item("sword", 2)
    var result = U_InventoryReducer.handle(initial_state, action)
    
    assert_eq(result.items[0].quantity, 3)

func test_remove_item() -> void:
    var initial_state = {
        "items": [{"item_id": "sword", "quantity": 3}],
        "gold": 0,
        "inventory_open": false
    }
    var action = U_InventoryActions.remove_item("sword", 1)
    var result = U_InventoryReducer.handle(initial_state, action)
    
    assert_eq(result.items[0].quantity, 2)

func test_remove_item_exhausts_stack() -> void:
    var initial_state = {
        "items": [{"item_id": "sword", "quantity": 1}],
        "gold": 0,
        "inventory_open": false
    }
    var action = U_InventoryActions.remove_item("sword", 1)
    var result = U_InventoryReducer.handle(initial_state, action)
    
    assert_eq(result.items.size(), 0)
```

---

## Usage Example

```gdscript
# In a system or manager:
var store = U_ServiceLocator.get("M_StateStore")
await U_StateUtils.await_store_ready(self)

# Dispatch actions
store.dispatch(U_InventoryActions.add_item("health_potion", 5))
store.dispatch(U_InventoryActions.set_gold(100))

# Read state via selectors
var has_potion = U_InventorySelectors.has_item(store.get_state(), "health_potion")
var gold = U_InventorySelectors.get_gold(store.get_state())
```
```

- [ ] **Step 3: Commit**

```bash
git add docs/_templates/redux-slice-template.md
git commit -m "docs: add Redux slice template for LLM boilerplate generation"
```

---

### Task 7: Run Full Test Suite & Verify

**Files:**
- All modified files from Tasks 1-6

- [ ] **Step 1: Run style enforcement tests**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: All tests pass.

- [ ] **Step 2: Run full GUT suite**

```bash
tools/run_gut_suite.sh
```

Expected: All tests pass.

- [ ] **Step 3: Verify pre-commit hook works**

```bash
tools/pre-commit-hooks/validate-imports.sh
```

Expected: `✅ Core/demo import validation passed`

- [ ] **Step 4: Verify all new docs are linked**

Check that new docs are referenced from main index files:
- `docs/superpowers/llm-decision-trees.md` linked from `docs/guides/ARCHITECTURE.md`
- `docs/_templates/redux-slice-template.md` linked from `docs/_templates/README.md` (if exists) or `docs/guides/STYLE_GUIDE.md`

- [ ] **Step 5: Final commit**

```bash
git add .
git commit -m "chore: complete LLM-first gaps implementation"
```

---

## Self-Review Checklist

**Spec Coverage:**
- [x] Version consistency → Task 1
- [x] ADR table completion → Task 2
- [x] Communication decision rules → Task 3
- [x] Core/demo firewall → Task 4
- [x] Jolt Physics docs → Task 5
- [x] Redux boilerplate templates → Task 6
- [x] Test verification → Task 7

**Placeholder Scan:**
- No "TBD", "TODO", or "fill in" patterns found
- All code blocks contain actual implementation examples
- All file paths are explicit

**Type Consistency:**
- Action creators use `Dictionary` return type consistently
- Reducers use `Dictionary` state parameter consistently
- Selectors match state structure from initial state templates

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-03-llm-first-gaps.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
