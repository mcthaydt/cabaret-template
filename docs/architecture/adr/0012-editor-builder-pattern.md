# ADR-0012: Editor Prefab/Blockout Builder Pattern

**Status**: Accepted

## Context

During Cleanup V8 Phase 7, we needed a way to replace hand-authored `.tscn` files with programmatic builder scripts. The goals were:
1. **LLM-friendly**: Builder scripts are easier for AI assistants to read, modify, and generate than `.tscn` text.
2. **Version-control friendly**: `.gd` diffs are human-readable; `.tscn` diffs with `unique_id` noise are not.
3. **Headless-testable**: Builder logic must be testable in GUT without a running editor.
4. **Reversible**: Each `.tscn` regeneration must be atomic and recoverable.

## Decision

Two `RefCounted` (not `EditorScript`) builder classes provide the core API:
- `U_EditorPrefabBuilder` — for character and static prefabs
- `U_EditorBlockoutBuilder` — for CSG level blockouts

Thin `@tool extends EditorScript` wrappers in `scripts/demo/editors/` invoke the builders and call `save()`.

### Why RefCounted, not EditorScript?

`EditorScript` cannot be instantiated in headless GUT runs. `RefCounted` builders can be unit-tested. The `EditorScript` wrapper is just 5 lines: instantiate, configure, save, print.

### Why not scene files directly?

- `.tscn` is lossy for version control (unique IDs, parent_id_path arrays).
- `.gd` builders are self-documenting and merge-friendly.
- Builders can be parameterized at runtime (e.g., different colors per variant).

## Alternatives

| Alternative | Why Rejected |
|---|---|
| Keep `.tscn` files | Noise in diffs, harder for LLMs to reason about, manual edits only |
| Use `EditorScript` directly as builders | Cannot be headless-tested; GUT cannot instantiate `EditorScript` subclasses |
| Use `PackedScene` script editing API directly | Too verbose; builder DSL is more ergonomic |
| Use `SceneState` to modify scenes | Overly complex for our use case; builder pattern is simpler |

## Consequences

- **Positive**: All static prefabs migrated with 100% parity. Tree, construction site, stone, water, stockpile all verified.
- **Positive**: Builder API tested at 28/28 passing.
- **Negative**: Character prefabs (wolf, rabbit, builder, demo_npc) require `override_child_property` and inherited component override — not yet implemented.
- **Negative**: `U_EditorPrefabBuilder` grew to 231 lines before extraction; we'll need to split shape factories into `U_EditorShapeFactory` if it keeps growing.
- **Tradeoff**: Builders create new `unique_id` values on each regeneration — acceptable since IDs are ephemeral.

## References

- `scripts/core/utils/editors/u_editor_prefab_builder.gd`
- `scripts/core/utils/editors/u_editor_blockout_builder.gd`
- `scripts/demo/editors/build_prefab_woods_*.gd`
- `tests/unit/editors/test_u_editor_prefab_builder.gd`
- `tests/unit/editors/test_u_editor_blockout_builder.gd`
