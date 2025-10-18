# Autofree Testing Pattern

## Problem Statement

Manual memory management in tests is error-prone and leads to:
- **Orphaned nodes** accumulating in memory during test runs
- **Boilerplate cleanup code** that must be maintained in every test
- **Easy to forget** to free resources, especially when tests fail early
- **Test pollution** where orphans from one test affect subsequent tests

### Current Pattern (Manual Cleanup)

```gdscript
func test_movement_system() -> void:
    var context: Dictionary = await _setup_entity()
    var movement = context["movement"]
    var system = context["system"]

    # ... test logic ...

    # Manual cleanup - easy to forget!
    await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            value.queue_free()
    await get_tree().process_frame
```

**Problems:**
- Must remember to call `_cleanup()` at end of every test
- If test fails/returns early, cleanup doesn't run
- Repetitive boilerplate in every test file
- No protection against forgetting to clean up specific nodes

## Solution: Base Test Class with Explicit Autofree

Create a base test class that provides convenience methods for registering nodes to be automatically freed after each test completes.

### Key Principles

1. **Explicit Registration**: Developers explicitly mark what should be freed using `autofree(node)`
2. **Leverage GUT's Built-in System**: Use GUT's battle-tested `autofree` system under the hood
3. **Safe Deferred Deletion**: Use `queue_free()` for safe cleanup at frame end
4. **Zero Maintenance**: GUT automatically calls cleanup after each test

## Implementation

### Base Test Class: `tests/base_test.gd`

```gdscript
extends GutTest
class_name BaseTest

## Base test class with automatic orphan cleanup utilities.
##
## This class provides convenience methods to register nodes for automatic
## cleanup after each test completes. It leverages GUT's built-in autofree
## system to ensure orphaned nodes are properly freed.
##
## Usage:
##   - Extend BaseTest instead of GutTest
##   - Call autofree(node) to register nodes for cleanup
##   - GUT automatically frees all registered nodes after each test

## Register a single node for automatic cleanup after the test.
## Uses queue_free() for safe deferred deletion.
##
## Example:
##   var node = Node3D.new()
##   add_child(node)
##   autofree(node)  # Will be automatically freed after test
func autofree(node: Node) -> Node:
    autofree.add_queue_free(node)
    return node

## Register all Node values in a dictionary for automatic cleanup.
## Useful for the common pattern of returning setup context as a dictionary.
##
## Example:
##   var context = await _setup_entity()
##   autofree_context(context)
func autofree_context(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            autofree.add_queue_free(value)

## Register all nodes in an array for automatic cleanup.
##
## Example:
##   var nodes = [node1, node2, node3]
##   autofree_all(nodes)
func autofree_all(nodes: Array) -> void:
    for node in nodes:
        if node is Node:
            autofree.add_queue_free(node)
```

### How It Works

1. **GutTest provides `autofree` object**: Every GutTest instance has access to GUT's `AutoFree` utility
2. **Register nodes with `add_queue_free()`**: Adds node to internal tracking array
3. **GUT calls `autofree.free_all()` automatically**: After each test completes (success or failure)
4. **Deferred deletion**: Uses `queue_free()` so nodes are freed at end of frame, avoiding mid-frame issues

## Usage Examples

### Pattern 1: Single Node Registration

Most direct approach for individual nodes:

```gdscript
extends BaseTest

func test_component_creation() -> void:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    autofree(manager)  # Registered for cleanup

    var component = FakeComponent.new()
    add_child(component)
    autofree(component)  # Registered for cleanup

    await get_tree().process_frame

    # Test assertions...
    assert_not_null(component)

    # No manual cleanup needed!
```

### Pattern 2: Context Dictionary (Recommended)

Best for setup methods that return multiple related objects:

```gdscript
extends BaseTest

func _setup_entity() -> Dictionary:
    var manager = ECS_MANAGER.new()
    add_child(manager)
    await get_tree().process_frame

    var movement = MovementComponentScript.new()
    add_child(movement)

    var body = FakeBody.new()
    add_child(body)

    return {
        "manager": manager,
        "movement": movement,
        "body": body,
    }

func test_movement_system() -> void:
    var context = await _setup_entity()
    autofree_context(context)  # All nodes registered!

    var movement = context["movement"]
    var body = context["body"]

    # Test logic...
    body.velocity = Vector3.ZERO

    # No manual cleanup needed!
```

### Pattern 3: Array Registration

Useful when creating multiple similar objects:

```gdscript
extends BaseTest

func test_multiple_entities() -> void:
    var entities = []

    for i in range(10):
        var entity = Entity.new()
        add_child(entity)
        entities.append(entity)

    autofree_all(entities)  # All 10 entities registered!

    # Test logic...
    assert_eq(entities.size(), 10)

    # No manual cleanup needed!
```

### Pattern 4: Inline Registration

Chain `autofree()` directly with `add_child()`:

```gdscript
extends BaseTest

func test_inline_registration() -> void:
    var manager = autofree(ECS_MANAGER.new())
    add_child(manager)

    var component = autofree(FakeComponent.new())
    add_child(component)

    # Test logic...

    # No manual cleanup needed!
```

## Migration Guide

### Converting Existing Tests

**Before (Manual Cleanup):**
```gdscript
extends GutTest

func test_something() -> void:
    var context = await _setup_entity()

    # Test logic...

    await _cleanup(context)  # Manual cleanup

func _cleanup(context: Dictionary) -> void:
    for value in context.values():
        if value is Node:
            value.queue_free()
    await get_tree().process_frame
```

**After (Autofree Pattern):**
```gdscript
extends BaseTest  # Changed from GutTest

func test_something() -> void:
    var context = await _setup_entity()
    autofree_context(context)  # One line replaces _cleanup()

    # Test logic...

    # No manual cleanup!

# Remove _cleanup() method entirely
```

### Step-by-Step Migration

1. **Change base class**: `extends GutTest` → `extends BaseTest`
2. **Add autofree registration**: Add `autofree()`, `autofree_context()`, or `autofree_all()` after setup
3. **Remove manual cleanup**: Delete `await _cleanup(context)` calls
4. **Remove cleanup methods**: Delete custom `_cleanup()` methods
5. **Test**: Run tests to verify no orphans are reported

## Best Practices

### When to Use Each Pattern

| Pattern | Use When | Example |
|---------|----------|---------|
| `autofree(node)` | Single nodes, simple tests | Creating one-off test objects |
| `autofree_context(dict)` | Setup returns dictionary | ECS entity setup with multiple components |
| `autofree_all(array)` | Creating multiple similar objects | Batch entity creation |

### Tips

1. **Register early**: Call `autofree()` right after creating/adding nodes
2. **Still use `await get_tree().process_frame`**: For ensuring nodes are ready, not cleanup
3. **RefCounted objects**: Don't need autofree (GDScript handles these automatically)
4. **Scene instances**: Need autofree if you instantiate them in tests
5. **Fail-safe**: Autofree runs even if test fails or returns early

### What About `free()` vs `queue_free()`?

We use `queue_free()` because:
- **Safer**: Deferred deletion at end of frame
- **Avoids crashes**: Won't free nodes mid-operation
- **Consistent**: Matches Godot best practices
- **Test-friendly**: Prevents order-dependent failures

GUT's autofree system handles the complexity of choosing `free()` for non-Node objects and `queue_free()` for Nodes.

## Advanced Usage

### Mixing Autofree with Manual Cleanup

You can mix both approaches when needed:

```gdscript
func test_mixed_cleanup() -> void:
    var keep_alive = Node.new()
    add_child(keep_alive)
    # Don't register - we'll free manually

    var auto_cleanup = Node.new()
    add_child(auto_cleanup)
    autofree(auto_cleanup)  # Will be freed automatically

    # Test logic...

    # Manual cleanup for special cases
    keep_alive.queue_free()
```

### Verifying No Orphans

GUT automatically reports orphans after each test. You can also check manually:

```gdscript
func test_no_orphans() -> void:
    var initial_orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

    var context = await _setup_entity()
    autofree_context(context)

    # Test logic...

    await get_tree().process_frame

    # After autofree runs, should match initial count
    # (This assertion would run AFTER the test completes in practice)
```

## Technical Details

### GUT's AutoFree System

Under the hood, GUT provides an `AutoFree` utility class (`addons/gut/autofree.gd`) that:
- Maintains separate arrays for `free()` and `queue_free()` candidates
- Handles RefCounted doubles specially
- Validates instances before freeing
- Automatically called by GUT after each test

### BaseTest Integration

`BaseTest` simply provides ergonomic wrappers around GUT's existing system:
- `autofree(node)` → `autofree.add_queue_free(node)`
- `autofree_context(dict)` → loops and calls `autofree.add_queue_free()`
- `autofree_all(array)` → loops and calls `autofree.add_queue_free()`

No custom cleanup logic needed - we leverage GUT's battle-tested implementation.

## Benefits Summary

✅ **No orphan leaks**: Guaranteed cleanup after every test
✅ **Less boilerplate**: One-line registration vs multi-line cleanup methods
✅ **Fail-safe**: Works even when tests fail or return early
✅ **Explicit**: Clear intent - you see what will be cleaned up
✅ **Flexible**: Multiple patterns for different use cases
✅ **Battle-tested**: Uses GUT's proven autofree system

## See Also

- [GUT Documentation](https://github.com/bitwes/Gut)
- `addons/gut/autofree.gd` - GUT's AutoFree implementation
- `addons/gut/orphan_counter.gd` - How GUT tracks orphans
