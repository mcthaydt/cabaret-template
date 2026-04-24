# Add Save Field / Migration

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new persisted field to an existing state slice
- A new header metadata field to save files
- A new save format migration (version bump)

This recipe does **not** cover:

- State slice creation (see `state.md`)
- Manager authoring (see `managers.md`)

## Governing ADR(s)

- [ADR 0002: Redux State Management](../adr/0002-redux-state-management.md)

## Canonical Example

- Save manager: `scripts/managers/m_save_manager.gd`
- Migration engine: `scripts/managers/helpers/u_save_migration_engine.gd`
- Validator: `scripts/utils/u_save_validator.gd`
- Atomic write: `scripts/managers/helpers/u_save_file_io.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `M_SaveManager` | Singleton. `save_to_slot()`, `load_from_slot()`, `request_autosave()`. |
| `U_SaveMigrationEngine` | Static chain: `detect_version()` → `migrate()` → current. Pure functions. |
| `U_SaveFileIO` | Atomic write: `.tmp` → `.bak` → `.json`. |
| `U_SaveValidator` | Validates header and state on load. |
| `SAVE_VERSION` | Current version constant in both `M_SaveManager` and `U_SaveMigrationEngine`. |
| `SLOT_AUTOSAVE` | Cannot be deleted. Slots: `autosave`, `slot_01`, `slot_02`, `slot_03`. |

Save format: JSON with `"header"` and `"state"` keys. `audio` and `display` slices erased before save. `navigation` slice is transient and never persisted.

## Recipe

### Adding a new persisted field

1. Add `@export` field to the relevant `RS_<Slice>InitialState` and `to_dictionary()`.
2. Add action + reducer case + selector for the field (see `state.md`).
3. The field is automatically persisted because `save_to_slot()` calls `get_persistable_state()`.
4. If the field should NOT persist: add it to the slice's `transient_fields` array.

### Adding a new header metadata field

1. Add field to `_build_metadata()` in `m_save_manager.gd`.
2. Add to header validation in `u_save_validator.gd` if required.
3. If the field replaces an older format: add migration step.

### Adding a new save migration

1. Increment `SAVE_VERSION` in both `m_save_manager.gd` and `u_save_migration_engine.gd`.
2. Write `static func _migrate_v{N}_to_v{N+1}(v{N}_save: Dictionary) -> Dictionary` — pure, no side effects, defensive `.get()` with defaults, `.duplicate(true)` before mutation.
3. Add `elif current_version == N:` branch in `migrate()`.
4. Write unit tests as `Dictionary -> Dictionary` transforms.

## Anti-patterns

- **Bypassing `M_SaveManager.save_to_slot()`**: Never call `M_StateStore.save_state()` directly.
- **Autosaving during death/transition/locked states**: Blocked by autosave scheduler.
- **Persisting `audio`/`display`/`navigation` slices**: Explicitly erased or transient.
- **Impure migrations**: Migrations must be pure functions, deterministic, no filesystem access.
- **Async/threaded saves**: All writes are synchronous.
- **Deleting the autosave slot**: Returns `ERR_UNAUTHORIZED`.

## Out Of Scope

- State slice creation: see `state.md`
- Manager registration: see `managers.md`
- UI save/load screen: see `ui.md`

## References

- [Save Manager Overview](../../systems/save_manager/save-manager-overview.md)