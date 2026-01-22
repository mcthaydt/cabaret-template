# Duck Typing Cleanup Continuation Prompt

Use this prompt to resume the duck typing cleanup effort (cleanup_v4).

---

## Context

- Goal: Remove `has_method()` duck typing patterns in favor of explicit interface-based type checking.
- The project already has `I_ECSManager` and `I_StateStore` interfaces - this cleanup extends that pattern to other managers and entities.
- Scope: ~65 production `has_method()` calls to fix (out of 186 total - rest are tests/Godot engine types).

**Out of scope** (acceptable patterns):
- Godot engine type checks (CharacterBody3D, RayCast3D) - keep as-is
- Test framework code - keep as-is
- `get_node()` patterns - already using `%UniqueName` and `@export NodePath`
- `call_deferred()` - all 19 usages are legitimate

---

## Read First

- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/general/cleanup_v4/duck-typing-cleanup-tasks.md`

---

## Current Progress

- Plan created and documented
- Phase 0 (preparation): Not started
- Phase 1 (I_ECSManager expansion): ✅ COMPLETE (2026-01-22)
  - Added 4 methods to I_ECSManager interface
  - Updated MockECSManager with implementations
  - Removed 6 `has_method()` checks from consumer files
  - All 111 ECS tests passing
- Phase 2 (I_ECSEntity interface): Not started
- Phase 3 (I_SceneManager interface): Not started
- Phase 4 (I_SaveManager interface): Not started
- Phase 5 (I_CameraManager interface): Not started
- Phase 6 (I_AudioManager interface): Not started
- Phase 7 (I_InputProfileManager/I_InputDeviceManager): Not started
- Phase 8 (I_VFXManager interface): Not started
- Phase 9 (I_RebindOverlay interface): Not started

---

## Execution Rules

- Run the targeted tests listed per phase in `duck-typing-cleanup-tasks.md` **before** advancing.
- After every phase, update:
  - `docs/general/cleanup_v4/duck-typing-cleanup-tasks.md` (checkboxes/notes)
  - This continuation prompt (progress + next steps)
- Commit documentation updates separately from implementation commits.

---

## Interface Pattern Reference

Follow existing pattern from `i_ecs_manager.gd`:

```gdscript
extends Node  # or Node3D for entities
class_name I_InterfaceName

## Docstring describing the interface
## Phase X: Created for [purpose]
## Implementations: [list concrete classes]

func method_name(_param: Type) -> ReturnType:
    push_error("I_InterfaceName.method_name not implemented")
    return default_value
```

## Replacement Pattern

```gdscript
# Before
if mgr != null and mgr.has_method("some_method"):
    mgr.some_method()

# After
var typed_mgr := mgr as I_ManagerInterface
if typed_mgr != null:
    typed_mgr.some_method()
```

---

## Next Step

- Begin Phase 2: Create I_ECSEntity interface
  - Create new `scripts/interfaces/i_ecs_entity.gd` file
  - Add interface methods: `get_entity_id()`, `set_entity_id()`, `get_tags()`, `has_tag()`, `add_tag()`, `remove_tag()`
  - Update `scripts/ecs/base_ecs_entity.gd` to extend I_ECSEntity
  - Create `tests/mocks/mock_ecs_entity.gd` with all interface methods
  - Update consumer files to replace `has_method()` with `is I_ECSEntity`
  - Run ECS tests to verify
