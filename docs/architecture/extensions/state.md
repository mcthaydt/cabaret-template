# Add State Slice / Action / Reducer

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new Redux state slice (domain of state with its own reducer)
- A new action type to an existing slice
- A new selector for reading state

This recipe does **not** cover:

- ECS component state (see `ecs.md`)
- Manager implementation (see `managers.md`)
- UI reactivity patterns (see `ui.md`)

## Governing ADR(s)

- [ADR 0002: Redux State Management](../adr/0002-redux-state-management.md)

## Canonical Example

- Audio slice: `scripts/state/actions/u_audio_actions.gd`, `scripts/state/reducers/u_audio_reducer.gd`, `scripts/state/selectors/u_audio_selectors.gd`, `scripts/resources/state/rs_audio_initial_state.gd`
- Store wiring: `scripts/state/m_state_store.gd` and `scripts/state/utils/u_state_slice_manager.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `M_StateStore` | Singleton store node. Dispatches actions, holds state, emits `slice_updated`. |
| `U_ActionRegistry` | Static validator. All action types must be registered or dispatch rejects. |
| `U_<Slice>Actions` | Static action creators. Constants like `const ACTION_SET_X := StringName("slice/set_x")`. |
| `U_<Slice>Reducer` | Pure function: `static func reduce(state, action) -> Variant`. Returns new Dictionary or `state`. |
| `U_<Slice>Selectors` | Static read functions: `static func get_x(state) -> float`. |
| `RS_<Slice>InitialState` | Resource with `@export` fields and `to_dictionary()`. |
| `RS_StateSliceConfig` | Slice metadata: `slice_name`, `dependencies`, `is_transient`, `transient_fields`. |
| `immediate: true` | Action flag causing synchronous `slice_updated` signal (before next physics frame). |

Action type format: `"<slice>/<verb>"` (e.g., `"audio/set_master_volume"`).

## Recipe

### Adding a new state slice

1. Create `scripts/resources/state/rs_<slice>_initial_state.gd`: extend `Resource`, `class_name RS_<Slice>InitialState`, `@export` all fields with defaults, implement `to_dictionary() -> Dictionary`.
2. Create `scripts/state/actions/u_<slice>_actions.gd`: extend `RefCounted`, define `const ACTION_<VERB> := StringName("<slice>/<verb>")`, register each in `_static_init()` via `U_ActionRegistry.register_action()`, implement static factory methods returning `{"type": ACTION_X, "payload": {...}}`. Mark UI-critical actions with `"immediate": true`.
3. Create `scripts/state/reducers/u_<slice>_reducer.gd`: extend `RefCounted`, define `const DEFAULT_<SLICE>_STATE := {...}`, implement `static func reduce(state, action) -> Variant`. Use `match action_type:`, `duplicate(true)` before mutation, return `state` for unrecognized, return `null` for unhandled cross-slice.
4. Create `scripts/state/selectors/u_<slice>_selectors.gd`: extend `RefCounted`, all `static func` taking `state: Dictionary`, private `_get_<slice>_slice(state)` extractor, public selectors with defaults.
5. Wire into `M_StateStore`: add `@export var <slice>_initial_state: Resource` and pass to `_initialize_slices()`.
6. Wire into `U_StateSliceManager.initialize_slices()`: create `RS_StateSliceConfig.new(StringName("<slice>"))`, set `reducer`, `initial_state`, `dependencies`, `transient_fields`, `is_transient`, call `register_slice()`.

### Adding a new action to an existing slice

1. Add `const ACTION_<VERB> := StringName("<slice>/<verb>")` to `U_<Slice>Actions`.
2. Register in `_static_init()`.
3. Add factory method.
4. Add match case in `U_<Slice>Reducer.reduce()`.
5. Add selector if needed.

## Anti-patterns

- **Direct `_state` mutation**: Always go through `dispatch()`. Only `load_state()`/`apply_loaded_state()` bypass dispatch, restricted to `M_SaveManager`.
- **Cross-slice reads without declaring dependencies**: `get_slice()` validates caller dependencies; undeclared reads return empty if strict mode is on.
- **Forgetting to register actions**: Unregistered types trigger `validation_failed`.
- **Persisting transient state**: Slices with `is_transient = true` are excluded from save/load. Use `transient_fields` for per-field control within persistent slices.
- **Skipping `immediate: true` for UI-critical actions**: These must flush `slice_updated` synchronously.

## Out Of Scope

- ECS component/system authoring: see `ecs.md`
- Manager registration: see `managers.md`
- Save/load: see `save.md`

## References

- [ADR 0002: Redux State Management](../adr/0002-redux-state-management.md)
- [State Store System Docs](../../systems/state_store/)