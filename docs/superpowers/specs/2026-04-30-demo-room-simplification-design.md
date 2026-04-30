# Demo Room Simplification Design

**Date:** 2026-04-30
**Context:** The `gameplay_demo_room.tscn` is meant to be an instantiation of `tmpl_base_scene.tscn` plus a spawn point marker. The current build script duplicates room geometry instead of reusing the template.

## Scope

Rewrite `scripts/demo/editors/build_gameplay_demo_room.gd` to simplify it. No changes to the output scene (`gameplay_demo_room.tscn`) or template (`tmpl_base_scene.tscn`).

## Design

### Current state

`build_gameplay_demo_room.gd` (121 lines) instantiates the template, deletes all its geometry, builds new 10x10x3m solid-color room from scratch, adds a spawn point, and saves. This duplicates the template's room geometry and doesn't inherit any template defaults.

### Proposed state

The build script instantiates `tmpl_base_scene.tscn` directly, adds a `sp_default` spawn marker under `Entities/SpawnPoints`, and saves. The template's 5x5x5m grid-textured room, camera defaults, and wall fading components carry through automatically.

### Pseudo-code

```gdscript
func _run() -> void:
    var template = load(TEMPLATE_PATH).instantiate()
    var spawn = Marker3D.new()
    spawn.name = "sp_default"
    spawn.position = Vector3(0, 1.0, 0)
    template.get_node("Entities/SpawnPoints").add_child(spawn)
    _set_owner_recursive(spawn, template)

    var packed = PackedScene.new()
    packed.pack(template)
    ResourceSaver.save(packed, OUTPUT_PATH)
    template.queue_free()
```

### Removals

- All geometry creation (60 lines of CSGBox3D + material code)
- All geometry deletion (5 lines of remove_child/queue_free)
- All solid color material variables and constants

### Result

Build script goes from 121 lines to ~20 lines. Demo room output identical in structure (template + spawn marker), updated geometry inherited from the newly regenerated template.

## Files Changed

| File | Change |
|------|--------|
| `scripts/demo/editors/build_gameplay_demo_room.gd` | Rewrite to template-only instantiation |

## Constraints

- Demo scripts can reference core — this is a build script, not runtime
- No test changes needed (no existing tests for this build script)
- Style enforcement passes after rewrite
